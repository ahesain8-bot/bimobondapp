import 'dart:async';
import 'dart:convert';
import 'package:bimobondapp/app/calls/services/keyguard_service.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallkitService {
  CallkitService._();
  static final CallkitService instance = CallkitService._();

  StreamSubscription? _eventSub;
  Function(Map<String, dynamic> extra)? _onAcceptHandler;
  Function(Map<String, dynamic> extra)? _onDeclineHandler;
  Map<String, dynamic>? _pendingAcceptExtra;
  Map<String, dynamic>? _pendingDeclineExtra;
  final Set<String> _handledActionKeys = {};
  String? _lastShownCallId;

  String? _extractCallId(dynamic body, Map<String, dynamic> extra) {
    String? id = extra['callId']?.toString() ??
        extra['id']?.toString() ??
        (body is Map ? body['callId']?.toString() : null) ??
        (body is Map ? body['id']?.toString() : null);

    if ((id == null || id.isEmpty) && body is Map && body['extra'] is Map) {
      final subExtra = Map<String, dynamic>.from(body['extra'] as Map);
      id = subExtra['callId']?.toString() ?? subExtra['id']?.toString();
    }

    if (id == null || id.isEmpty) {
      id = _lastShownCallId;
    }
    return id;
  }

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

    listenToEvents();
  }

  void listenToEvents() {
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

      final callId = _extractCallId(body, extra);

      switch (event.event) {
        case Event.actionCallAccept:
        case Event.actionCallCallback:
          KeyguardService.instance.setShowWhenLocked(true);
          KeyguardService.instance.requestDismissKeyguard();
          final targetCallId = callId ?? _lastShownCallId;
          if (targetCallId != null && targetCallId.isNotEmpty) {
            extra['callId'] = targetCallId;
            extra['id'] = targetCallId;
            final key = 'accept_$targetCallId';
            if (_handledActionKeys.contains(key)) {
              debugPrint('CallkitService: Duplicate accept event ignored for $targetCallId');
              return;
            }
            _handledActionKeys.add(key);
          }
          debugPrint('CallkitService: Call Accepted/Tapped for callId=$targetCallId');
          if (_onAcceptHandler != null) {
            _onAcceptHandler?.call(extra);
          } else {
            _pendingAcceptExtra = extra;
          }
          break;
        case Event.actionCallDecline:
        case Event.actionCallTimeout:
          final targetCallId = callId ?? _lastShownCallId;
          if (targetCallId != null && targetCallId.isNotEmpty) {
            final key = 'decline_$targetCallId';
            if (!_handledActionKeys.contains(key)) {
              _handledActionKeys.add(key);
              unawaited(FlutterCallkitIncoming.endCall(targetCallId));
              unawaited(sendRejectApiCall(targetCallId));
            }
          } else {
            unawaited(FlutterCallkitIncoming.endAllCalls());
          }
          debugPrint('CallkitService: Call Declined/Timed out for callId=$targetCallId');
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

  Future<void> sendRejectApiCall(String callId) async {
    if (callId.isEmpty) return;
    try {
      debugPrint('CallkitService: Sending direct HTTP POST to reject call $callId');
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': ApiConstants.apiKey,
          },
        ),
      );

      String? token;
      try {
        token = await FirebaseAuth.instance.currentUser?.getIdToken();
      } catch (_) {}

      if (token == null || token.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          token = prefs.getString('AUTH_TOKEN');
        } catch (_) {}
      }

      if (token != null && token.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }

      final response = await dio.post('/calls/$callId/reject');
      debugPrint('CallkitService: Background reject API response status=${response.statusCode}');
    } catch (e) {
      debugPrint('CallkitService: Background reject API call failed for $callId: $e');
    }
  }

  Future<String?> _fetchCallerNameFromApi(String callId) async {
    if (callId.isEmpty) return null;
    try {
      debugPrint('CallkitService: Fetching caller details from GET /calls/$callId');
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': ApiConstants.apiKey,
          },
        ),
      );

      String? token;
      try {
        token = await FirebaseAuth.instance.currentUser?.getIdToken();
      } catch (_) {}

      if (token == null || token.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          token = prefs.getString('AUTH_TOKEN');
        } catch (_) {}
      }

      if (token != null && token.isNotEmpty) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }

      final response = await dio.get('/calls/$callId');
      if (response.data is Map) {
        final map = Map<String, dynamic>.from(response.data);
        final initiatedBy = map['initiatedBy'];
        if (initiatedBy is Map) {
          final name = initiatedBy['fullName']?.toString() ??
              initiatedBy['displayName']?.toString() ??
              initiatedBy['username']?.toString() ??
              initiatedBy['name']?.toString();
          if (name != null && name.trim().isNotEmpty && name.trim() != 'User') {
            return name.trim();
          }
        }
        final callerName = map['callerName']?.toString() ??
            map['caller_name']?.toString() ??
            map['displayName']?.toString();
        if (callerName != null &&
            callerName.trim().isNotEmpty &&
            callerName.trim() != 'User') {
          return callerName.trim();
        }
      }
    } catch (e) {
      debugPrint('CallkitService: _fetchCallerNameFromApi error: $e');
    }
    return null;
  }

  Future<void> checkActiveCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      debugPrint('CallkitService: checkActiveCalls returned ${calls is List ? calls.length : 0} calls');
      if (calls is List && calls.isNotEmpty) {
        for (final item in calls) {
          if (item is Map) {
            final isAcceptedRaw = item['isAccepted'];
            final isAccepted = isAcceptedRaw == true ||
                isAcceptedRaw == 1 ||
                isAcceptedRaw == 'true';
            final extra = item['extra'] is Map
                ? Map<String, dynamic>.from(item['extra'] as Map)
                : Map<String, dynamic>.from(item);
            final callId = extra['callId']?.toString() ??
                extra['id']?.toString() ??
                item['id']?.toString();

            if (isAccepted && callId != null && callId.isNotEmpty) {
              debugPrint('CallkitService: activeCalls found accepted call: $callId');
              KeyguardService.instance.setShowWhenLocked(true);
              if (_onAcceptHandler != null) {
                _onAcceptHandler?.call(extra);
              } else {
                _pendingAcceptExtra = extra;
              }
              break;
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

    for (final key in [
      'initiatedBy',
      'initiator',
      'user',
      'caller',
      'actor',
      'sender',
      'data',
      'payload',
      'call',
      'callee',
      'participant',
      'creator',
    ]) {
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

    for (final subKey in ['initiatedBy', 'initiator', 'user', 'caller', 'actor', 'sender']) {
      final subVal = data[subKey];
      if (subVal is Map) {
        final subMap = Map<String, dynamic>.from(subVal);
        data.putIfAbsent(
            'callerName',
            () =>
                subMap['fullName'] ??
                subMap['displayName'] ??
                subMap['username'] ??
                subMap['name']);
        data.putIfAbsent(
            'callerAvatar',
            () =>
                subMap['avatarUrl'] ??
                subMap['avatar'] ??
                subMap['imageUrl']);
      }
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
      if (candidate != null &&
          candidate is String &&
          candidate.trim().isNotEmpty &&
          candidate.trim() != 'null') {
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

    if (callerName == null) {
      final titleCandidates = [data['title'], data['notificationTitle'], data['notificationBody'], data['body']];
      for (final candidate in titleCandidates) {
        if (candidate != null && candidate is String && candidate.trim().isNotEmpty) {
          final str = candidate.trim();
          if (str.contains(' is calling')) {
            callerName = str.split(' is calling')[0].trim();
            break;
          } else if (str.contains(' invited you')) {
            callerName = str.split(' invited you')[0].trim();
            break;
          } else if (str.contains('يقوم بالاتصال')) {
            callerName = str.split('يقوم بالاتصال')[0].trim();
            break;
          } else if (str.contains('مكالمة من ')) {
            callerName = str.split('مكالمة من ').last.trim();
            break;
          } else if (str.contains(':')) {
            final parts = str.split(':');
            if (parts.isNotEmpty && parts[0].trim().isNotEmpty && !parts[0].trim().toLowerCase().startsWith('incoming')) {
              callerName = parts[0].trim();
              break;
            }
          }
        }
      }
    }

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
      if (candidate != null &&
          candidate is String &&
          candidate.trim().isNotEmpty &&
          candidate.trim() != 'null') {
        callerAvatar = candidate.trim();
        break;
      }
    }

    final handleCandidates = [
      data['callerPhone'],
      data['caller_phone'],
      data['phone'],
      data['phoneNumber'],
      data['phone_number'],
      data['handle'],
    ];

    String? callerHandle;
    for (final candidate in handleCandidates) {
      if (candidate != null &&
          candidate is String &&
          candidate.trim().isNotEmpty &&
          candidate.trim() != 'null') {
        callerHandle = candidate.trim();
        break;
      }
    }

    final typeStr =
        (data['type'] ?? data['callType'] ?? '').toString().toUpperCase();
    final isVideo =
        typeStr == 'VIDEO' || data['isVideo'] == true || data['isVideo'] == 'true';
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

    final callId = data['callId']?.toString() ??
        data['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    _lastShownCallId = callId;
    var details = _extractCallerDetails(data);
    var callerName = details['name'];

    // If caller name is missing, generic, or unresolved, try fetching from backend API GET /calls/$callId
    if (callerName == null ||
        callerName.isEmpty ||
        callerName == 'Incoming Call' ||
        callerName == 'User' ||
        callerName == 'مكالمة واردة') {
      final fetchedName = await _fetchCallerNameFromApi(callId);
      if (fetchedName != null &&
          fetchedName.isNotEmpty &&
          fetchedName != 'User' &&
          fetchedName != 'Incoming Call' &&
          fetchedName != 'مكالمة واردة') {
        callerName = fetchedName;
        data['callerName'] = fetchedName;
        details['name'] = fetchedName;
      }
    }

    // REQUIREMENT: DO NOT SHOW CALL CARD / NOTIFICATION UNTIL CALLER NAME IS RESOLVED!
    if (callerName == null ||
        callerName.isEmpty ||
        callerName == 'Incoming Call' ||
        callerName == 'User' ||
        callerName == 'مكالمة واردة') {
      debugPrint(
          'CallkitService: SUPPRESSING incoming call notification card because caller name could not be resolved from body, payload, or API for callId=$callId');
      return;
    }

    final callerAvatar = details['avatar'];
    final callerHandle = details['handle'] ?? 'Voice Call';

    final typeStr = data['type']?.toString().toUpperCase() ?? '';
    final callType = data['callType']?.toString().toUpperCase() ?? '';
    final isVideo = typeStr == 'VIDEO' ||
        callType == 'VIDEO' ||
        data['isVideo'] == true ||
        data['isVideo'] == 'true';
    final callKindText = isVideo ? 'Bimo-Bond Video Call' : 'Bimo-Bond Audio Call';

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: callKindText,
      avatar: callerAvatar,
      handle: (callerHandle != 'Voice Call' &&
              callerHandle != 'Video Call' &&
              callerHandle.isNotEmpty)
          ? '$callerHandle • $callKindText'
          : callKindText,
      type: isVideo ? 1 : 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: Map<String, dynamic>.from(data),
      headers: <String, dynamic>{'apiKey': 'Abc@123!'},
      android: const AndroidParams(
        isCustomNotification: false,
        isShowLogo: false,
        isShowFullLockedScreen: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#095544',
        actionColor: '#4CAF50',
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
}
