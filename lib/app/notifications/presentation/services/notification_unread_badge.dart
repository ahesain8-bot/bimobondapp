import 'dart:async';

import 'package:bimobondapp/app/notifications/data/datasources/notification_socket_service.dart';
import 'package:bimobondapp/app/notifications/domain/usecases/notifications_usecases.dart';
import 'package:bimobondapp/core/utils/build_safe_notifier.dart';
import 'package:flutter/foundation.dart';

/// Driven by a socket push and by API refreshes, so a change can land at any
/// point in a frame — [BuildSafeNotifier] keeps that from tearing down a
/// [ListenableBuilder] mid-build.
class NotificationUnreadBadge extends ChangeNotifier with BuildSafeNotifier {
  NotificationUnreadBadge({
    required this.getUnreadCountUseCase,
    required this.socketService,
  });

  final GetUnreadNotificationsCountUseCase getUnreadCountUseCase;
  final NotificationSocketService socketService;

  int _count = 0;
  StreamSubscription<int>? _socketSub;

  int get count => _count;
  bool get hasUnread => _count > 0;

  Future<void> start() async {
    await refresh();
    _socketSub ??= socketService.onUnreadCount.listen((count) {
      if (_count == count) return;
      _count = count;
      notifySafely();
    });
  }

  void stop() {
    _socketSub?.cancel();
    _socketSub = null;
    if (_count == 0) return;
    _count = 0;
    notifySafely();
  }

  Future<void> refresh() async {
    final result = await getUnreadCountUseCase();
    result.fold((_) {}, (count) {
      if (_count == count) return;
      _count = count;
      notifySafely();
    });
  }

  void setCount(int count) {
    if (_count == count) return;
    _count = count;
    notifySafely();
  }
}
