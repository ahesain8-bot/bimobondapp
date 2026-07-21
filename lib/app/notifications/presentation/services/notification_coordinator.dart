import 'dart:async';

import 'package:bimobondapp/app/auth/data/datasources/auth_remote_data_source.dart';
import 'package:bimobondapp/app/notifications/data/datasources/notification_socket_service.dart';
import 'package:bimobondapp/app/notifications/presentation/services/notification_unread_badge.dart';
import 'package:bimobondapp/app/notifications/presentation/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationCoordinator {
  NotificationCoordinator({
    required this.socketService,
    required this.pushService,
    required this.authRemoteDataSource,
    required this.unreadBadge,
  });

  final NotificationSocketService socketService;
  final PushNotificationService pushService;
  final AuthRemoteDataSource authRemoteDataSource;
  final NotificationUnreadBadge unreadBadge;

  StreamSubscription<String>? _tokenRefreshSub;
  String? _activeUserId;

  Future<void> onLoggedIn(String userId) async {
    // Idempotent on purpose: on cold start AuthSuccess is emitted twice
    // (CheckAuthStatus from cache, then FetchProfile from /auth/me) and a
    // post-frame sync also fires. Without this guard each repeat would
    // re-init push, reconnect the socket, and re-hit unread-count + device
    // login — several redundant API calls on every open.
    if (_activeUserId == userId) return;
    _activeUserId = userId;
    await pushService.initialize(onTokenRefresh: _syncDeviceRegistration);
    await socketService.connectAndJoin(userId);
    await unreadBadge.start();
    await _syncDeviceRegistration();
    _tokenRefreshSub ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(_syncDeviceRegistration());
    });
  }

  Future<void> onLoggedOut() async {
    final userId = _activeUserId;
    _activeUserId = null;
    unreadBadge.stop();
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (userId != null) {
      socketService.leaveAndDisconnect(userId);
    } else {
      socketService.leaveAndDisconnect('');
    }
  }

  Future<void> _syncDeviceRegistration() async {
    try {
      await authRemoteDataSource.syncDeviceRegistration();
    } catch (_) {
      // Non-fatal: push may still work on next login.
    }
  }
}
