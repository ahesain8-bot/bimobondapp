import 'package:bimobondapp/app/chats/domain/repositories/chats_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class MarkMessageReadParams extends Equatable {
  const MarkMessageReadParams({required this.messageId});

  final String messageId;

  @override
  List<Object?> get props => [messageId];
}

class MarkMessageReadUseCase implements UseCase<void, MarkMessageReadParams> {
  MarkMessageReadUseCase(this.repository);

  final ChatsRepository repository;

  @override
  Future<Either<Failure, void>> call(MarkMessageReadParams params) {
    return repository.markMessageRead(params.messageId);
  }
}
