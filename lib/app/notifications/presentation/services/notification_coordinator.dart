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
  String? _pendingLoginUserId;
  bool _loginSideEffectsAllowed = false;

  Future<void> onLoggedIn(String userId) async {
    // Auth is resolved before the first feed page. Queue notification network
    // work so socket, unread count, and device registration do not compete
    // with the initial For You request.
    if (!_loginSideEffectsAllowed) {
      _pendingLoginUserId = userId;
      return;
    }

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

  /// Allows login side effects after the first For You page is visible.
  ///
  /// The gate remains open for this app process, so later re-logins do not
  /// depend on another feed load.
  void allowLoginSideEffects() {
    if (_loginSideEffectsAllowed) return;
    _loginSideEffectsAllowed = true;
    final pendingUserId = _pendingLoginUserId;
    _pendingLoginUserId = null;
    if (pendingUserId != null) {
      unawaited(onLoggedIn(pendingUserId));
    }
  }

  Future<void> onLoggedOut() async {
    _pendingLoginUserId = null;
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
