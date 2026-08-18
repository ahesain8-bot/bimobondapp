import 'dart:convert';
import 'dart:io';

import 'package:bimobondapp/app/calls/data/models/call_model.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_state.dart';
import 'package:bimobondapp/app/calls/services/callkit_service.dart';
import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_navigation.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/push_payload_parser.dart';
import 'package:bimobondapp/core/routes/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

typedef TokenRefreshCallback = Future<void> Function();

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const channelId = 'high_importance_channel';
  static const channelName = 'Notifications';
  static const channelDescription = 'Likes, comments, follows, and alerts';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _listenersAttached = false;

  Future<void> initializeEarly() async {
    if (kIsWeb || _initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'incoming_calls_channel',
          'Incoming Calls',
          description: 'Incoming Audio & Video Calls',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }

    _initialized = true;
  }

  Future<void> initialize({TokenRefreshCallback? onTokenRefresh}) async {
    if (kIsWeb) return;

    await initializeEarly();
    await _requestPermissions();

    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (!_listenersAttached) {
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
      _listenersAttached = true;
    }

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    if (onTokenRefresh != null) {
      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        onTokenRefresh();
      });
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint(
        'PushNotificationService: foreground message ${message.messageId}',
      );
    }
    final fullData = _extractFullMessageData(message);
    final typeUpper = (fullData['type'] ?? fullData['event'] ?? fullData['action'] ?? '')
        .toString()
        .toUpperCase();

    if (_isIncomingCallData(fullData)) {
      final isAppResumed =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!isAppResumed) {
        await CallkitService.instance.showIncomingCall(fullData);
      }
      final rootCtx = AppRouter.rootNavigatorKey.currentContext;
      if (rootCtx != null && rootCtx.mounted) {
        final callBloc = rootCtx.read<CallBloc>();
        if (callBloc.state is! CallIncomingState && callBloc.state is! CallActiveState) {
          final callEntity = CallModel.fromJson(fullData);
          callBloc.add(IncomingCallReceivedEvent(call: callEntity));
        }
      }
      return;
    } else if (typeUpper == 'CALL_CANCELLED' ||
        typeUpper == 'CALL_ENDED' ||
        typeUpper == 'CALL_REJECTED') {
      final callId = fullData['callId']?.toString() ?? fullData['id']?.toString();
      if (callId != null && callId.isNotEmpty) {
        await CallkitService.instance.endCall(callId);
      } else {
        await CallkitService.instance.endAllCalls();
      }
      return;
    }
    await showRemoteMessage(message);
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _handleNotificationOpen(message);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _openFromPayload(payload);
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    final title = pushTitle(message);
    final body = pushBody(message);
    final payload = jsonEncode(message.data);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  void _handleNotificationOpen(RemoteMessage message) {
    if (message.data.isEmpty) return;
    final notification = notificationFromRemoteMessage(message);
    _navigateToNotification(notification);
  }

  void _openFromPayload(String payload) {
    try {
      final raw = jsonDecode(payload);
      if (raw is! Map) return;
      final data = Map<String, dynamic>.from(raw);
      _navigateToNotification(
        NotificationEntity(
          id: data['notificationId']?.toString() ?? data['callId']?.toString() ?? '',
          userId: data['userId']?.toString() ?? '',
          type: data['type']?.toString() ?? (data['screen'] == 'incoming_call' ? 'CALL_INCOMING' : 'SYSTEM'),
          isRead: false,
          createdAt: DateTime.now(),
          actorId: data['actorId']?.toString(),
          postId: data['postId']?.toString(),
          commentId: data['commentId']?.toString(),
          data: data,
        ),
      );
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  void _navigateToNotification(NotificationEntity notification) {
    final context = AppRouter.rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    navigateFromNotification(context, notification);
  }
}

@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  // Navigation is handled when the app resumes; payload is stored by the OS.
}

bool _isIncomingCallData(Map<String, dynamic> data) {
  final typeUpper = (data['type'] ?? data['event'] ?? data['action'] ?? data['eventType'] ?? data['callType'] ?? '')
      .toString()
      .toUpperCase();
  final screenUpper = (data['screen'] ?? '').toString().toUpperCase();

  if (typeUpper == 'CALL_INCOMING' ||
      typeUpper == 'INCOMING_CALL' ||
      typeUpper == 'CALL' ||
      typeUpper.contains('INCOMING') ||
      screenUpper == 'INCOMING_CALL' ||
      screenUpper == 'CALL') {
    if (typeUpper != 'CALL_CANCELLED' &&
        typeUpper != 'CALL_ENDED' &&
        typeUpper != 'CALL_REJECTED' &&
        typeUpper != 'CALL_MISSED') {
      return true;
    }
  }

  final callId = data['callId']?.toString() ??
      data['call_id']?.toString() ??
      data['id']?.toString() ??
      data['channel']?.toString();

  if (callId != null &&
      callId.isNotEmpty &&
      typeUpper != 'CALL_CANCELLED' &&
      typeUpper != 'CALL_ENDED' &&
      typeUpper != 'CALL_REJECTED' &&
      typeUpper != 'CALL_MISSED') {
    return true;
  }

  final body = (data['body'] ?? data['notificationBody'] ?? '').toString().toLowerCase();
  final title = (data['title'] ?? data['notificationTitle'] ?? '').toString().toLowerCase();
  if ((body.contains('calling') ||
          body.contains('مكالمة') ||
          body.contains('is calling') ||
          title.contains('calling') ||
          title.contains('مكالمة')) &&
      typeUpper != 'CALL_CANCELLED' &&
      typeUpper != 'CALL_ENDED' &&
      typeUpper != 'CALL_REJECTED' &&
      typeUpper != 'CALL_MISSED') {
    return true;
  }

  return false;
}

Map<String, dynamic> _extractFullMessageData(RemoteMessage message) {
  final data = Map<String, dynamic>.from(message.data);

  if (message.notification != null) {
    final notifTitle = message.notification!.title;
    final notifBody = message.notification!.body;

    if (notifTitle != null && notifTitle.isNotEmpty) {
      data.putIfAbsent('notificationTitle', () => notifTitle);
      data.putIfAbsent('title', () => notifTitle);
      final lowerTitle = notifTitle.toLowerCase();
      if (lowerTitle != 'incoming call' &&
          lowerTitle != 'incoming voice call' &&
          lowerTitle != 'incoming video call' &&
          lowerTitle != 'bimo bond' &&
          lowerTitle != 'مكالمة واردة' &&
          lowerTitle != 'مكالمة') {
        data.putIfAbsent('callerName', () => notifTitle);
        data.putIfAbsent('name', () => notifTitle);
        data.putIfAbsent('username', () => notifTitle);
      }
    }

    if (notifBody != null && notifBody.isNotEmpty) {
      data.putIfAbsent('notificationBody', () => notifBody);
      data.putIfAbsent('body', () => notifBody);

      final trimmedBody = notifBody.trim();
      if (trimmedBody.startsWith('{') && trimmedBody.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmedBody);
          if (decoded is Map) {
            final bodyMap = Map<String, dynamic>.from(decoded);
            bodyMap.forEach((k, v) {
              data.putIfAbsent(k, () => v);
            });
          }
        } catch (_) {}
      }

      String? extractedName;
      if (notifBody.contains(' is calling')) {
        extractedName = notifBody.split(' is calling').first.trim();
      } else if (notifBody.contains('يقوم بالاتصال')) {
        extractedName = notifBody.split('يقوم بالاتصال').first.trim();
      } else if (notifBody.contains('مكالمة من ')) {
        extractedName = notifBody.split('مكالمة من ').last.trim();
      }

      if (extractedName != null &&
          extractedName.isNotEmpty &&
          extractedName.toLowerCase() != 'incoming call' &&
          extractedName.toLowerCase() != 'مكالمة واردة') {
        data['callerName'] = extractedName;
        data['name'] = extractedName;
        data['username'] = extractedName;
        data['fullName'] = extractedName;
      }
    }
  }

  for (final key in ['user', 'caller', 'actor', 'sender', 'initiator', 'data', 'payload', 'call']) {
    final val = data[key];
    if (val is String && val.trim().startsWith('{') && val.trim().endsWith('}')) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is Map) {
          final decodedMap = Map<String, dynamic>.from(decoded);
          decodedMap.forEach((k, v) {
            data.putIfAbsent(k, () => v);
          });
          if (key == 'user' || key == 'caller' || key == 'initiator' || key == 'actor') {
            data.putIfAbsent('initiatedBy', () => decodedMap);
          }
        }
      } catch (_) {}
    } else if (val is Map) {
      final mapVal = Map<String, dynamic>.from(val);
      mapVal.forEach((k, v) {
        data.putIfAbsent(k, () => v);
      });
      if (key == 'user' || key == 'caller' || key == 'initiator' || key == 'actor') {
        data.putIfAbsent('initiatedBy', () => mapVal);
      }
    }
  }

  if (data['initiatedBy'] == null) {
    final callerName = data['callerName'] ?? data['fullName'] ?? data['username'] ?? data['name'];
    final callerAvatar = data['callerAvatar'] ?? data['avatarUrl'] ?? data['avatar'] ?? data['imageUrl'];
    final callerId = data['callerId'] ?? data['initiatorId'] ?? data['userId'] ?? '';
    if (callerName != null) {
      data['initiatedBy'] = {
        'id': callerId.toString(),
        'username': callerName.toString(),
        'fullName': callerName.toString(),
        'avatarUrl': callerAvatar?.toString(),
      };
    }
  }

  return data;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotificationService.instance.initializeEarly();

  final data = _extractFullMessageData(message);
  final typeUpper = (data['type'] ?? data['event'] ?? data['action'] ?? '')
      .toString()
      .toUpperCase();

  if (_isIncomingCallData(data)) {
    await CallkitService.instance.showIncomingCall(data);
    return;
  } else if (typeUpper == 'CALL_CANCELLED' ||
      typeUpper == 'CALL_ENDED' ||
      typeUpper == 'CALL_REJECTED') {
    final callId = data['callId']?.toString();
    if (callId != null && callId.isNotEmpty) {
      await CallkitService.instance.endCall(callId);
    } else {
      await CallkitService.instance.endAllCalls();
    }
    return;
  }

  await PushNotificationService.instance.showRemoteMessage(message);
}
