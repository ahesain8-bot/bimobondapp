import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/repositories/calls_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class StartCallUseCase {
  final CallsRepository repository;

  StartCallUseCase(this.repository);

  Future<Either<Failure, CallSessionEntity>> call({
    required String chatId,
    required String type,
    List<String>? inviteeIds,
  }) {
    return repository.startCall(
      chatId: chatId,
      type: type,
      inviteeIds: inviteeIds,
    );
  }
}
