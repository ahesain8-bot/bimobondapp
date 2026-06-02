import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class DeleteMessageParams extends Equatable {
  const DeleteMessageParams({required this.messageId});

  final String messageId;

  @override
  List<Object?> get props => [messageId];
}

class DeleteMessageUseCase implements UseCase<void, DeleteMessageParams> {
  DeleteMessageUseCase(this.repository);

  final ChatsRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteMessageParams params) {
    return repository.deleteMessage(params.messageId);
  }
}
