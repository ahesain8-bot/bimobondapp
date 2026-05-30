import 'package:bimobondapp/app/chats/domain/entities/chat_entity.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class ChatsRepository {
  Future<Either<Failure, List<ChatEntity>>> getChats();

  Future<Either<Failure, ChatEntity>> createOrGetChat({
    required List<String> participantIds,
    bool isGroup = false,
    String? name,
  });

  Future<Either<Failure, List<ChatMessageEntity>>> getMessages({
    required String chatId,
    int page = 1,
    int limit = 20,
  });

  Future<Either<Failure, ChatMessageEntity>> sendMessage({
    required String chatId,
    required String content,
    String type = 'TEXT',
    String? mediaUrl,
    String? replyToId,
    String? sharedPostId,
  });

  Future<Either<Failure, void>> markMessageRead(String messageId);

  Future<Either<Failure, void>> reactToMessage({
    required String messageId,
    required String emoji,
  });

  Future<Either<Failure, void>> deleteMessage(String messageId);
}
