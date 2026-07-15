import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class SendMessageParams extends Equatable {
  const SendMessageParams({
    required this.chatId,
    this.content = '',
    this.type = 'TEXT',
    this.mediaUrl,
    this.replyToId,
    this.sharedPostId,
    this.sharedProfileId,
    this.payload,
  });

  final String chatId;
  final String content;
  final String type;
  final String? mediaUrl;
  final String? replyToId;
  final String? sharedPostId;
  final String? sharedProfileId;
  final Map<String, dynamic>? payload;

  @override
  List<Object?> get props => [
        chatId,
        content,
        type,
        mediaUrl,
        replyToId,
        sharedPostId,
        sharedProfileId,
        payload,
      ];
}

class SendMessageUseCase implements UseCase<ChatMessageEntity, SendMessageParams> {
  SendMessageUseCase(this.repository);

  final ChatsRepository repository;

  @override
  Future<Either<Failure, ChatMessageEntity>> call(SendMessageParams params) {
    return repository.sendMessage(
      chatId: params.chatId,
      content: params.content,
      type: params.type,
      mediaUrl: params.mediaUrl,
      replyToId: params.replyToId,
      sharedPostId: params.sharedPostId,
      sharedProfileId: params.sharedProfileId,
      payload: params.payload,
    );
  }
}
