import 'dart:async';

import 'package:bimobondapp/app/notifications/data/models/notification_model.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class NotificationSocketEvent {
  NotificationSocketEvent._();

  static const notification = 'notification';
  static const unreadCount = 'notificationUnreadCount';
  static const chatUpdated = 'chatUpdated';
  static const storyUpdated = 'storyUpdated';
  static const joinUser = 'joinUser';
  static const leaveUser = 'leaveUser';
  static const joinedUser = 'joinedUser';
  static const joinStoryUser = 'joinStoryUser';
  static const leaveStoryUser = 'leaveStoryUser';
}

class StorySocketUpdate {
  const StorySocketUpdate({
    required this.userId,
    required this.storyId,
    required this.action,
  });

  final String userId;
  final String storyId;
  final String action;
}

class NotificationSocketService {
  io.Socket? _socket;
  final _notificationController =
      StreamController<NotificationModel>.broadcast();
  final _unreadCountController = StreamController<int>.broadcast();
  final _chatUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _storyUpdatedController =
      StreamController<StorySocketUpdate>.broadcast();

  Stream<NotificationModel> get onNotification => _notificationController.stream;
  Stream<int> get onUnreadCount => _unreadCountController.stream;
  Stream<Map<String, dynamic>> get onChatUpdated =>
      _chatUpdatedController.stream;
  Stream<StorySocketUpdate> get onStoryUpdated =>
      _storyUpdatedController.stream;

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
      ..on(NotificationSocketEvent.chatUpdated, _handleChatUpdated)
      ..on(NotificationSocketEvent.storyUpdated, _handleStoryUpdated)
      ..onConnect((_) {
        // Docs: joinUser after login for inbox + storyUpdated mirror.
        _socket?.emit(NotificationSocketEvent.joinUser, {'userId': userId});
      });

    _socket!.connect();
  }

  void joinStoryUser(String ownerUserId) {
    if (ownerUserId.isEmpty) return;
    _socket?.emit(
      NotificationSocketEvent.joinStoryUser,
      {'userId': ownerUserId},
    );
  }

  void leaveStoryUser(String ownerUserId) {
    if (ownerUserId.isEmpty) return;
    _socket?.emit(
      NotificationSocketEvent.leaveStoryUser,
      {'userId': ownerUserId},
    );
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

  void _handleChatUpdated(dynamic data) {
    if (data is Map) {
      _chatUpdatedController.add(Map<String, dynamic>.from(data));
    }
  }

  void _handleStoryUpdated(dynamic data) {
    if (data is! Map) return;
    final userId = data['userId']?.toString() ?? '';
    final storyId = data['storyId']?.toString() ?? '';
    final action = data['action']?.toString() ?? '';
    if (userId.isEmpty || storyId.isEmpty) return;
    _storyUpdatedController.add(
      StorySocketUpdate(
        userId: userId,
        storyId: storyId,
        action: action,
      ),
    );
  }

  void leaveAndDisconnect(String userId) {
    if (userId.isNotEmpty) {
      _socket?.emit(NotificationSocketEvent.leaveUser, {'userId': userId});
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    leaveAndDisconnect('');
    _notificationController.close();
    _unreadCountController.close();
    _chatUpdatedController.close();
    _storyUpdatedController.close();
  }
}
