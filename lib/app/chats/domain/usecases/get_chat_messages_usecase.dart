import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetChatMessagesParams extends Equatable {
  const GetChatMessagesParams({
    required this.chatId,
    this.page = 1,
    this.limit = 20,
  });

  final String chatId;
  final int page;
  final int limit;

  @override
  List<Object?> get props => [chatId, page, limit];
}

class GetChatMessagesUseCase
    implements UseCase<List<ChatMessageEntity>, GetChatMessagesParams> {
  GetChatMessagesUseCase(this.repository);

  final ChatsRepository repository;

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> call(
    GetChatMessagesParams params,
  ) {
    return repository.getMessages(
      chatId: params.chatId,
      page: params.page,
      limit: params.limit,
    );
  }
}
