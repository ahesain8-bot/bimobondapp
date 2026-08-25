import 'dart:async';

import 'package:bimobondapp/app/chats/data/models/chat_message_model.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatSocketEvent {
  ChatSocketEvent._();

  static const newMessage = 'newMessage';
  static const newChat = 'newChat';
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
  final _newChatController =
      StreamController<Map<String, dynamic>>.broadcast();
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
  Stream<Map<String, dynamic>> get onNewChat => _newChatController.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _messageReadController.stream;
  Stream<Map<String, dynamic>> get onMessageReacted =>
      _messageReactedController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted =>
      _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> _ensureConnected() async {
    if (_socket?.connected == true) return;

    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : null;

    _socket?.dispose();
    _socket = io.io(
      ApiConstants.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setExtraHeaders({
            if (token != null) 'Authorization': 'Bearer $token',
            'x-api-key': ApiConstants.apiKey,
          })
          .setAuth({'token': token})
          .build(),
    );

    final socket = _socket!;

    socket
      ..onConnect((_) {
        _connectionController.add(true);
      })
      ..onDisconnect((_) => _connectionController.add(false));

    final chatEvents = [
      ChatSocketEvent.newChat,
      'new_chat',
      'chatCreated',
      'chat_created',
      'newChatCreated',
      'new_chat_created',
      'chat',
    ];
    for (final event in chatEvents) {
      socket.on(event, (data) => _emitMap(_newChatController, data));
    }

    final messageEvents = [
      ChatSocketEvent.newMessage,
      'new_message',
      'message',
      'chat_message',
    ];
    for (final event in messageEvents) {
      socket.on(event, (data) => _handleNewMessage(data));
    }

    final readEvents = [
      ChatSocketEvent.messageRead,
      'message_read',
      'read_message',
      'messages_read',
    ];
    for (final event in readEvents) {
      socket.on(event, (data) => _emitMap(_messageReadController, data));
    }

    final reactedEvents = [
      ChatSocketEvent.messageReacted,
      'message_reacted',
      'reaction_added',
      'message_reaction',
    ];
    for (final event in reactedEvents) {
      socket.on(event, (data) => _emitMap(_messageReactedController, data));
    }

    final deletedEvents = [
      ChatSocketEvent.messageDeleted,
      'message_deleted',
      'delete_message',
    ];
    for (final event in deletedEvents) {
      socket.on(event, (data) => _emitMap(_messageDeletedController, data));
    }

    final typingEvents = [
      ChatSocketEvent.userTyping,
      'user_typing',
      'typing_status',
      'typing',
    ];
    for (final event in typingEvents) {
      socket.on(event, (data) => _emitMap(_userTypingController, data));
    }

    socket.connect();
  }

  Future<void> connect() async {
    await _ensureConnected();
  }

  void _handleNewMessage(dynamic data) {
    if (data is! Map) return;
    try {
      final messageMap = Map<String, dynamic>.from(data);
      final payload = messageMap['message'] is Map
          ? Map<String, dynamic>.from(messageMap['message'] as Map)
          : (messageMap['data'] is Map
              ? Map<String, dynamic>.from(messageMap['data'] as Map)
              : messageMap);

      final message = ChatMessageModel.fromJson(payload);
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
      final mapData = Map<String, dynamic>.from(data);
      final payload = mapData['data'] is Map
          ? Map<String, dynamic>.from(mapData['data'] as Map)
          : mapData;
      controller.add(payload);
    }
  }

  void joinChat(String chatId, {required String userId}) {
    _ensureConnected();
    final payload = {
      'chatId': chatId,
      'chat_id': chatId,
      'userId': userId,
      'user_id': userId,
    };
    _socket?.emit(ChatSocketEvent.joinChat, payload);
    _socket?.emit('join_chat', payload);
    _socket?.emit('join', payload);
  }

  void leaveChat(String chatId) {
    final payload = {'chatId': chatId, 'chat_id': chatId};
    _socket?.emit(ChatSocketEvent.leaveChat, payload);
    _socket?.emit('leave_chat', payload);
    _socket?.emit('leave', payload);
  }

  void sendTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) {
    _ensureConnected();
    final payload = {
      'chatId': chatId,
      'chat_id': chatId,
      'userId': userId,
      'user_id': userId,
      'isTyping': isTyping,
      'is_typing': isTyping,
    };
    _socket?.emit(ChatSocketEvent.typing, payload);
    _socket?.emit('typing', payload);
    _socket?.emit('user_typing', payload);
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
    _newChatController.close();
    _messageReadController.close();
    _messageReactedController.close();
    _messageDeletedController.close();
    _userTypingController.close();
    _connectionController.close();
  }
}
