import 'package:bimobondapp/app/chats/data/models/chat_message_model.dart';
import 'package:bimobondapp/app/chats/data/models/chat_model.dart';
import 'package:bimobondapp/app/chats/data/models/chat_participant_model.dart';
import 'package:bimobondapp/core/error/dio_handler.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class ChatsRemoteDataSource {
  Future<List<ChatModel>> getChats();

  Future<ChatModel> createOrGetChat({
    required List<String> participantIds,
    bool isGroup = false,
    String? name,
  });

  Future<List<ChatMessageModel>> getMessages({
    required String chatId,
    int page = 1,
    int limit = 20,
  });

  Future<ChatMessageModel> sendMessage({
    required String chatId,
    required Map<String, dynamic> body,
  });

  Future<void> markMessageRead(String messageId);

  Future<void> reactToMessage({
    required String messageId,
    required String emoji,
  });

  Future<void> deleteMessage(String messageId);

  Future<List<ChatParticipantModel>> getFriends();
}

class ChatsRemoteDataSourceImpl implements ChatsRemoteDataSource {
  ChatsRemoteDataSourceImpl({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> _authHeaders() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final idToken = await firebaseUser.getIdToken();
      return {'Authorization': 'Bearer $idToken'};
    }
    return {};
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      return data['message']?.toString() ?? data['error']?.toString();
    }
    return null;
  }

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final data = body['data'];
      if (data is List) return data;
      for (final key in ['items', 'chats', 'messages', 'friends']) {
        final nested = body[key];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  Map<String, dynamic> _extractObject(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      return body;
    }
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      if (map['data'] is Map) {
        return Map<String, dynamic>.from(map['data'] as Map);
      }
      return map;
    }
    throw ServerException(message: 'Invalid response');
  }

  @override
  Future<List<ChatModel>> getChats() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.chats,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _extractList(response.data)
            .whereType<Map>()
            .map((e) => ChatModel.fromJson(Map<String, dynamic>.from(e)))
            .where((c) => c.id.isNotEmpty)
            .toList();
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load chats',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<ChatModel> createOrGetChat({
    required List<String> participantIds,
    bool isGroup = false,
    String? name,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.chats,
        data: {
          'participantIds': participantIds,
          'isGroup': isGroup,
          if (name != null) 'name': name,
        },
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChatModel.fromJson(_extractObject(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to create chat',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<ChatMessageModel>> getMessages({
    required String chatId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.chatMessages(chatId),
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _extractList(response.data)
            .whereType<Map>()
            .map(
              (e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .where((m) => m.id.isNotEmpty)
            .toList();
      }
      throw ServerException(
        message:
            _extractErrorMessage(response.data) ?? 'Failed to load messages',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<ChatMessageModel> sendMessage({
    required String chatId,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.chatMessages(chatId),
        data: body,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChatMessageModel.fromJson(_extractObject(response.data));
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to send message',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> markMessageRead(String messageId) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.markMessageRead(messageId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: _extractErrorMessage(response.data) ?? 'Failed to mark read',
        );
      }
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> reactToMessage({
    required String messageId,
    required String emoji,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.reactToMessage(messageId),
        data: {'emoji': emoji},
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message: _extractErrorMessage(response.data) ?? 'Failed to react',
        );
      }
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.deleteMessage(messageId),
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ServerException(
          message:
              _extractErrorMessage(response.data) ?? 'Failed to delete message',
        );
      }
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<List<ChatParticipantModel>> getFriends() async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.myFriends,
        options: Options(headers: await _authHeaders()),
      );
      if (response.statusCode == 200) {
        return _extractList(response.data)
            .whereType<Map>()
            .map(
              (e) => ChatParticipantModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .where((u) => u.id.isNotEmpty)
            .toList();
      }
      throw ServerException(
        message: _extractErrorMessage(response.data) ?? 'Failed to load friends',
      );
    } on DioException catch (e) {
      throw DioHandler.handle(e);
    }
  }
}
