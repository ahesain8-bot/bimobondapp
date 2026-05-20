import 'package:bimobondapp/app/chats/data/datasources/chats_remote_data_source.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_entity.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_participant_entity.dart';
import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class ChatsRepositoryImpl implements ChatsRepository {
  ChatsRepositoryImpl({required this.remoteDataSource});

  final ChatsRemoteDataSource remoteDataSource;

  Failure _mapException(Object e) {
    if (e is ServerException) {
      return ServerFailure(e.message ?? 'Something went wrong');
    }
    if (e is UnauthorizedException) {
      return UnauthorizedFailure(e.message ?? 'Unauthorized');
    }
    return ServerFailure(e.toString());
  }

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
    required String content,
    String type = 'TEXT',
    String? mediaUrl,
    String? replyToId,
    String? sharedPostId,
  }) async {
    try {
      final message = await remoteDataSource.sendMessage(
        chatId: chatId,
        body: {
          'content': content,
          'type': type,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (replyToId != null) 'replyToId': replyToId,
          if (sharedPostId != null) 'sharedPostId': sharedPostId,
        },
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
  Future<Either<Failure, List<ChatParticipantEntity>>> getFriends() async {
    try {
      final friends = await remoteDataSource.getFriends();
      return Right(friends);
    } catch (e) {
      return Left(_mapException(e));
    }
  }
}
