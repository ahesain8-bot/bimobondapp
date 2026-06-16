import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class DeleteChatParams extends Equatable {
  const DeleteChatParams({
    required this.chatId,
    this.deleteForEveryone = false,
  });

  final String chatId;
  final bool deleteForEveryone;

  @override
  List<Object?> get props => [chatId, deleteForEveryone];
}

class DeleteChatUseCase implements UseCase<void, DeleteChatParams> {
  DeleteChatUseCase(this.repository);

  final ChatsRepository repository;

  @override
  Future<Either<Failure, void>> call(DeleteChatParams params) {
    return repository.deleteChat(
      params.chatId,
      deleteForEveryone: params.deleteForEveryone,
    );
  }
}
