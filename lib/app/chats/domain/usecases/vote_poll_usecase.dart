import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class VotePollParams extends Equatable {
  const VotePollParams({
    required this.messageId,
    required this.optionIndex,
  });

  final String messageId;
  final int optionIndex;

  @override
  List<Object?> get props => [messageId, optionIndex];
}

class VotePollUseCase implements UseCase<ChatMessageEntity, VotePollParams> {
  VotePollUseCase(this.repository);

  final ChatsRepository repository;

  @override
  Future<Either<Failure, ChatMessageEntity>> call(VotePollParams params) {
    return repository.votePoll(
      messageId: params.messageId,
      optionIndex: params.optionIndex,
    );
  }
}
