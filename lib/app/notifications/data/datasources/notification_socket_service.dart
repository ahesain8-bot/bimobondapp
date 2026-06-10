import 'dart:async';

import 'package:bimobondapp/app/notifications/data/models/notification_model.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class NotificationSocketEvent {
  NotificationSocketEvent._();

  static const notification = 'notification';
  static const unreadCount = 'notificationUnreadCount';
  static const joinUser = 'joinUser';
  static const leaveUser = 'leaveUser';
  static const joinedUser = 'joinedUser';
}

class NotificationSocketService {
  io.Socket? _socket;
  final _notificationController =
      StreamController<NotificationModel>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();

  Stream<NotificationModel> get onNotification => _notificationController.stream;
  Stream<int> get onUnreadCount => _unreadCountController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connectAndJoin(String userId) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : null;

    _socket?.dispose();
    _socket = io.io(
      ApiConstants.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..on(NotificationSocketEvent.notification, _handleNotification)
      ..on(NotificationSocketEvent.unreadCount, _handleUnreadCount)
      ..onConnect((_) {
        _socket?.emit(NotificationSocketEvent.joinUser, {'userId': userId});
      });

    _socket!.connect();
  }

  void _handleNotification(dynamic data) {
    if (data is! Map) return;
    try {
      _notificationController.add(
        NotificationModel.fromJson(Map<String, dynamic>.from(data)),
      );
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  void _handleUnreadCount(dynamic data) {
    if (data is! Map) return;
    final count = data['unreadCount'];
    if (count is int) {
      _unreadCountController.add(count);
    } else if (count is num) {
      _unreadCountController.add(count.toInt());
    }
  }

  void leaveAndDisconnect(String userId) {
    _socket?.emit(NotificationSocketEvent.leaveUser, {'userId': userId});
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    leaveAndDisconnect('');
    _notificationController.close();
    _unreadCountController.close();
  }
}
