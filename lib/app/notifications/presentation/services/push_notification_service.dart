import 'dart:convert';
import 'dart:io';

import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/notification_navigation.dart';
import 'package:bimobondapp/app/notifications/presentation/utils/push_payload_parser.dart';
import 'package:bimobondapp/core/routes/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              channelName,
              description: channelDescription,
              importance: Importance.high,
            ),
          );
    }

    _initialized = true;
  }

  Future<void> initialize({
    TokenRefreshCallback? onTokenRefresh,
  }) async {
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
      debugPrint('PushNotificationService: foreground message ${message.messageId}');
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
          id: data['notificationId']?.toString() ?? '',
          userId: data['userId']?.toString() ?? '',
          type: data['type']?.toString() ?? 'SYSTEM',
          isRead: false,
          createdAt: DateTime.now(),
          actorId: data['actorId']?.toString(),
          postId: data['postId']?.toString(),
          commentId: data['commentId']?.toString(),
          data: data['auctionId'] != null
              ? {'auctionId': data['auctionId'].toString()}
              : null,
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

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotificationService.instance.initializeEarly();
  await PushNotificationService.instance.showRemoteMessage(message);
}
