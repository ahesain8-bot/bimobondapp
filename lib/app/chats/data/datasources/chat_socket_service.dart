import 'dart:async';

import 'package:bimobondapp/app/chats/data/models/chat_message_model.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatSocketEvent {
  ChatSocketEvent._();

  static const newMessage = 'newMessage';
  static const messageRead = 'messageRead';
  static const messageReacted = 'messageReacted';
  static const messageDeleted = 'messageDeleted';
  static const userTyping = 'userTyping';

  static const joinChat = 'joinChat';
  static const leaveChat = 'leaveChat';
  static const typing = 'typing';
}

class ChatSocketService {
  io.Socket? _socket;
  final _messageController = StreamController<ChatMessageModel>.broadcast();
  final _messageReadController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageReactedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _userTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<ChatMessageModel> get onNewMessage => _messageController.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _messageReadController.stream;
  Stream<Map<String, dynamic>> get onMessageReacted =>
      _messageReactedController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted =>
      _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket?.connected == true) return;

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
      ..onConnect((_) => _connectionController.add(true))
      ..onDisconnect((_) => _connectionController.add(false))
      ..on(
        ChatSocketEvent.newMessage,
        (data) => _handleNewMessage(data),
      )
      ..on(
        ChatSocketEvent.messageRead,
        (data) => _emitMap(_messageReadController, data),
      )
      ..on(
        ChatSocketEvent.messageReacted,
        (data) => _emitMap(_messageReactedController, data),
      )
      ..on(
        ChatSocketEvent.messageDeleted,
        (data) => _emitMap(_messageDeletedController, data),
      )
      ..on(
        ChatSocketEvent.userTyping,
        (data) => _emitMap(_userTypingController, data),
      );

    _socket!.connect();
  }

  void _handleNewMessage(dynamic data) {
    if (data is! Map) return;
    try {
      final message = ChatMessageModel.fromJson(
        Map<String, dynamic>.from(data),
      );
      _messageController.add(message);
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  void _emitMap(
    StreamController<Map<String, dynamic>> controller,
    dynamic data,
  ) {
    if (data is Map) {
      controller.add(Map<String, dynamic>.from(data));
    }
  }

  void joinChat(String chatId, {required String userId}) {
    _socket?.emit(ChatSocketEvent.joinChat, {
      'chatId': chatId,
      'userId': userId,
    });
  }

  void leaveChat(String chatId) {
    _socket?.emit(ChatSocketEvent.leaveChat, {'chatId': chatId});
  }

  void sendTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) {
    _socket?.emit(ChatSocketEvent.typing, {
      'chatId': chatId,
      'userId': userId,
      'isTyping': isTyping,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _messageReadController.close();
    _messageReactedController.close();
    _messageDeletedController.close();
    _userTypingController.close();
    _connectionController.close();
  }
}
