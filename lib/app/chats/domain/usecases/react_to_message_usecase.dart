import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class ReactToMessageParams extends Equatable {
  const ReactToMessageParams({
    required this.messageId,
    required this.emoji,
  });

  final String messageId;
  final String emoji;

  @override
  List<Object?> get props => [messageId, emoji];
}

class ReactToMessageUseCase implements UseCase<void, ReactToMessageParams> {
  ReactToMessageUseCase(this.repository);

  final ChatsRepository repository;

  @override
  Future<Either<Failure, void>> call(ReactToMessageParams params) {
    return repository.reactToMessage(
      messageId: params.messageId,
      emoji: params.emoji,
    );
  }
}
