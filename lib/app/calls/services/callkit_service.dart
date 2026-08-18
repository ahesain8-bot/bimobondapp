import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class CallkitService {
  CallkitService._();
  static final CallkitService instance = CallkitService._();

  StreamSubscription? _eventSub;
  Function(Map<String, dynamic> extra)? _onAcceptHandler;
  Function(Map<String, dynamic> extra)? _onDeclineHandler;
  Map<String, dynamic>? _pendingAcceptExtra;
  Map<String, dynamic>? _pendingDeclineExtra;
  final Set<String> _handledActionKeys = {};

  void initialize({
    Function(Map<String, dynamic> extra)? onAccept,
    Function(Map<String, dynamic> extra)? onDecline,
  }) {
    _onAcceptHandler = onAccept;
    _onDeclineHandler = onDecline;

    // Process any cached accept/decline events received before handler registration
    if (_pendingAcceptExtra != null) {
      debugPrint('CallkitService: Processing pending cached accept event');
      final extra = _pendingAcceptExtra!;
      _pendingAcceptExtra = null;
      _onAcceptHandler?.call(extra);
    }
    if (_pendingDeclineExtra != null) {
      debugPrint('CallkitService: Processing pending cached decline event');
      final extra = _pendingDeclineExtra!;
      _pendingDeclineExtra = null;
      _onDeclineHandler?.call(extra);
    }

    _eventSub?.cancel();
    _eventSub = FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      if (kDebugMode) {
        debugPrint('CallkitService: event received -> ${event.event} body: ${event.body}');
      }

      final body = event.body;
      Map<String, dynamic> extra = {};
      if (body is Map) {
        if (body['extra'] is Map) {
          extra = Map<String, dynamic>.from(body['extra'] as Map);
        } else {
          extra = Map<String, dynamic>.from(body);
        }
      }

      final callId = extra['callId']?.toString() ?? extra['id']?.toString() ?? body['id']?.toString();

      switch (event.event) {
        case Event.actionCallAccept:
        case Event.actionCallCallback:
          if (callId != null && callId.isNotEmpty) {
            final key = 'accept_$callId';
            if (_handledActionKeys.contains(key)) {
              debugPrint('CallkitService: Duplicate accept event ignored for $callId');
              return;
            }
            _handledActionKeys.add(key);
          }
          debugPrint('CallkitService: Call Accepted/Tapped for callId=$callId');
          if (_onAcceptHandler != null) {
            _onAcceptHandler?.call(extra);
          } else {
            _pendingAcceptExtra = extra;
          }
          break;
        case Event.actionCallDecline:
        case Event.actionCallTimeout:
          if (callId != null && callId.isNotEmpty) {
            final key = 'decline_$callId';
            if (_handledActionKeys.contains(key)) {
              debugPrint('CallkitService: Duplicate decline event ignored for $callId');
              return;
            }
            _handledActionKeys.add(key);
            unawaited(FlutterCallkitIncoming.endCall(callId));
          } else {
            unawaited(FlutterCallkitIncoming.endAllCalls());
          }
          debugPrint('CallkitService: Call Declined/Timed out for callId=$callId');
          if (_onDeclineHandler != null) {
            _onDeclineHandler?.call(extra);
          } else {
            _pendingDeclineExtra = extra;
          }
          break;
        case Event.actionCallEnded:
          if (callId != null) {
            _handledActionKeys.remove('accept_$callId');
            _handledActionKeys.remove('decline_$callId');
          }
          break;
        default:
          break;
      }
    });

    checkActiveCalls();
  }

  Future<void> checkActiveCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (kDebugMode) {
        debugPrint('CallkitService: checkActiveCalls returned ${calls is List ? calls.length : 0} calls');
      }
      if (calls is List && calls.isNotEmpty) {
        for (final call in calls) {
          if (call is Map) {
            final isAcceptedRaw = call['isAccepted'] ?? call['accepted'];
            final isAccepted = isAcceptedRaw == true ||
                isAcceptedRaw == 1 ||
                isAcceptedRaw == '1' ||
                isAcceptedRaw == 'true' ||
                isAcceptedRaw == null;

            Map<String, dynamic> extra = {};
            if (call['extra'] is Map) {
              extra = Map<String, dynamic>.from(call['extra'] as Map);
            } else {
              extra = Map<String, dynamic>.from(call);
            }

            final callId = extra['callId']?.toString() ??
                extra['id']?.toString() ??
                call['id']?.toString() ??
                call['callId']?.toString();

            if (callId != null && callId.isNotEmpty) {
              extra['callId'] = callId;
              if (isAccepted) {
                debugPrint('CallkitService: activeCalls found accepted call: $callId');
                if (_onAcceptHandler != null) {
                  _onAcceptHandler?.call(extra);
                } else {
                  _pendingAcceptExtra = extra;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('CallkitService: checkActiveCalls error: $e');
    }
  }

  Map<String, String?> _extractCallerDetails(Map<String, dynamic> rawData) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

    for (final key in ['user', 'caller', 'actor', 'sender', 'data', 'payload', 'call']) {
      final val = data[key];
      if (val is String && val.trim().startsWith('{') && val.trim().endsWith('}')) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is Map) {
            data.addAll(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      } else if (val is Map) {
        data.addAll(Map<String, dynamic>.from(val));
      }
    }

    if (data['user'] is Map) {
      final userMap = Map<String, dynamic>.from(data['user'] as Map);
      data.putIfAbsent('callerName', () => userMap['name'] ?? userMap['displayName'] ?? userMap['username'] ?? userMap['fullName']);
      data.putIfAbsent('callerAvatar', () => userMap['avatar'] ?? userMap['avatarUrl'] ?? userMap['imageUrl']);
    }

    if (data['initiator'] is Map) {
      final initMap = Map<String, dynamic>.from(data['initiator'] as Map);
      data.putIfAbsent('callerName', () => initMap['fullName'] ?? initMap['username'] ?? initMap['name']);
      data.putIfAbsent('callerAvatar', () => initMap['avatarUrl'] ?? initMap['avatar'] ?? initMap['imageUrl']);
    }

    final nameCandidates = [
      data['callerName'],
      data['caller_name'],
      data['actorName'],
      data['actor_name'],
      data['senderName'],
      data['sender_name'],
      data['displayName'],
      data['display_name'],
      data['userName'],
      data['user_name'],
      data['username'],
      data['fullName'],
      data['full_name'],
      data['first_name'],
      data['firstName'],
      data['name'],
      data['title'],
      data['notificationTitle'],
      data['from'],
      data['caller'],
      data['sender'],
      data['actor'],
    ];

    String? callerName;
    for (final candidate in nameCandidates) {
      if (candidate != null && candidate is String && candidate.trim().isNotEmpty && candidate.trim() != 'null') {
        final lower = candidate.trim().toLowerCase();
        if (lower != 'incoming call' &&
            lower != 'incoming audio call' &&
            lower != 'incoming video call' &&
            lower != 'bimo bond' &&
            lower != 'مكالمة واردة' &&
            lower != 'مكالمة') {
          callerName = candidate.trim();
          break;
        }
      }
    }

    if (callerName == null || callerName.isEmpty || callerName == 'Incoming Call') {
      final bodyStr = (data['body'] ?? data['notificationBody'] ?? data['message'] ?? '').toString();
      if (bodyStr.isNotEmpty) {
        if (bodyStr.contains(' is calling')) {
          callerName = bodyStr.split(' is calling').first.trim();
        } else if (bodyStr.contains('calling you')) {
          callerName = bodyStr.split('calling you').first.replaceAll('is', '').trim();
        } else if (bodyStr.toLowerCase().contains('call from ')) {
          callerName = bodyStr.substring(bodyStr.toLowerCase().indexOf('from ') + 5).trim();
        } else if (bodyStr.contains('يقوم بالاتصال')) {
          callerName = bodyStr.split('يقوم بالاتصال').first.trim();
        } else if (bodyStr.contains('مكالمة من ')) {
          callerName = bodyStr.split('مكالمة من ').last.trim();
        } else if (!bodyStr.toLowerCase().contains('call') && !bodyStr.contains('مكالمة')) {
          callerName = bodyStr.trim();
        }
      }
    }

    callerName ??= 'Incoming Call';

    final avatarCandidates = [
      data['callerAvatar'],
      data['caller_avatar'],
      data['avatar'],
      data['avatarUrl'],
      data['avatar_url'],
      data['userAvatar'],
      data['user_avatar'],
      data['imageUrl'],
      data['image_url'],
      data['image'],
      data['icon'],
      data['actorAvatar'],
      data['actor_avatar'],
      data['picture'],
      data['profile_pic'],
    ];

    String? callerAvatar;
    for (final candidate in avatarCandidates) {
      if (candidate != null && candidate is String && candidate.trim().isNotEmpty && candidate.trim() != 'null') {
        callerAvatar = candidate.trim();
        break;
      }
    }

    final handleCandidates = [
      data['callerPhone'],
      data['caller_phone'],
      data['phone'],
      data['callerHandle'],
      data['caller_handle'],
      data['handle'],
    ];

    String? callerHandle;
    for (final candidate in handleCandidates) {
      if (candidate != null && candidate is String && candidate.trim().isNotEmpty && candidate.trim() != 'null') {
        callerHandle = candidate.trim();
        break;
      }
    }

    final typeStr = (data['type'] ?? data['callType'] ?? '').toString().toUpperCase();
    final isVideo = typeStr == 'VIDEO' || data['isVideo'] == true || data['isVideo'] == 'true';
    callerHandle ??= isVideo ? 'Video Call' : 'Voice Call';

    return {
      'name': callerName,
      'avatar': callerAvatar,
      'handle': callerHandle,
    };
  }

  Future<void> showIncomingCall(Map<String, dynamic> data) async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}

    final callId = data['callId']?.toString() ?? data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final details = _extractCallerDetails(data);
    final callerName = details['name'] ?? 'Incoming Call';
    final callerAvatar = details['avatar'];
    final callerHandle = details['handle'] ?? 'Voice Call';

    final typeStr = data['type']?.toString().toUpperCase() ?? '';
    final callType = data['callType']?.toString().toUpperCase() ?? '';
    final isVideo = typeStr == 'VIDEO' || callType == 'VIDEO' || data['isVideo'] == true || data['isVideo'] == 'true';
    final callKindText = isVideo ? 'Bimo-Bond Video Call' : 'Bimo-Bond Audio Call';

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: callKindText,
      avatar: callerAvatar,
      handle: (callerHandle != 'Voice Call' && callerHandle != 'Video Call' && callerHandle.isNotEmpty)
          ? '$callerHandle • $callKindText'
          : callKindText,
      type: isVideo ? 1 : 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: Map<String, dynamic>.from(data),
      headers: <String, dynamic>{'apiKey': 'bimobond'},
      android: const AndroidParams(
        isCustomNotification: false,
        isShowLogo: true,
        logoUrl: 'logo',
        isShowFullLockedScreen: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#090D16',
        actionColor: '#10B981',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Incoming Calls',
        missedCallNotificationChannelName: 'Missed Calls',
        isShowCallID: true,
      ),
      ios: IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: isVideo,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> endCall(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('CallkitService: Error ending call $callId: $e');
    }
  }

  Future<void> endAllCalls() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('CallkitService: Error ending all calls: $e');
    }
  }

  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
  }
}
