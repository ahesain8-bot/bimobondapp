import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/repositories/calls_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class InviteToCallUseCase {
  final CallsRepository repository;

  InviteToCallUseCase(this.repository);

  Future<Either<Failure, CallEntity>> call({
    required String callId,
    required List<String> inviteeIds,
  }) {
    return repository.inviteToCall(
      callId: callId,
      inviteeIds: inviteeIds,
    );
  }
}
