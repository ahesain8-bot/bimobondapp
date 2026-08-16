import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/repositories/calls_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class RejectCallUseCase {
  final CallsRepository repository;

  RejectCallUseCase(this.repository);

  Future<Either<Failure, CallEntity>> call({required String callId}) {
    return repository.rejectCall(callId: callId);
  }
}
