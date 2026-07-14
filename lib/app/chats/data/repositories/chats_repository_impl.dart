import 'package:bimobondapp/app/chats/data/datasources/chats_remote_data_source.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_entity.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class ChatsRepositoryImpl implements ChatsRepository {
  ChatsRepositoryImpl({required this.remoteDataSource});

  final ChatsRemoteDataSource remoteDataSource;

  Failure _mapException(Object e) => FailureMapper.from(e);

  @override
  Future<Either<Failure, List<ChatEntity>>> getChats() async {
    try {
      final chats = await remoteDataSource.getChats();
      return Right(chats);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, ChatEntity>> createOrGetChat({
    required List<String> participantIds,
    bool isGroup = false,
    String? name,
  }) async {
    try {
      final chat = await remoteDataSource.createOrGetChat(
        participantIds: participantIds,
        isGroup: isGroup,
        name: name,
      );
      return Right(chat);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> getMessages({
    required String chatId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final messages = await remoteDataSource.getMessages(
        chatId: chatId,
        page: page,
        limit: limit,
      );
      return Right(messages);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, ChatMessageEntity>> sendMessage({
    required String chatId,
    String content = '',
    String type = 'TEXT',
    String? mediaUrl,
    String? replyToId,
    String? sharedPostId,
    String? sharedProfileId,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final trimmed = content.trim();
      final message = await remoteDataSource.sendMessage(
        chatId: chatId,
        body: {
          if (trimmed.isNotEmpty) 'content': trimmed,
          'type': type,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (replyToId != null) 'replyToId': replyToId,
          if (sharedPostId != null) 'sharedPostId': sharedPostId,
          if (sharedProfileId != null) 'sharedProfileId': sharedProfileId,
          if (payload != null) 'payload': payload,
        },
      );
      return Right(message);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, ChatMessageEntity>> votePoll({
    required String messageId,
    required int optionIndex,
  }) async {
    try {
      final message = await remoteDataSource.votePoll(
        messageId: messageId,
        optionIndex: optionIndex,
      );
      return Right(message);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, void>> markMessageRead(String messageId) async {
    try {
      await remoteDataSource.markMessageRead(messageId);
      return const Right(null);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, void>> reactToMessage({
    required String messageId,
    required String emoji,
  }) async {
    try {
      await remoteDataSource.reactToMessage(
        messageId: messageId,
        emoji: emoji,
      );
      return const Right(null);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMessage(String messageId) async {
    try {
      await remoteDataSource.deleteMessage(messageId);
      return const Right(null);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteChat(String chatId, {bool deleteForEveryone = false}) async {
    try {
      await remoteDataSource.deleteChat(chatId, deleteForEveryone: deleteForEveryone);
      return const Right(null);
    } catch (e) {
      return Left(_mapException(e));
    }
  }
}
