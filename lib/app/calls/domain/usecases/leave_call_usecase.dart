import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/repositories/calls_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class LeaveCallUseCase {
  final CallsRepository repository;

  LeaveCallUseCase(this.repository);

  Future<Either<Failure, CallEntity>> call({required String callId}) {
    return repository.leaveCall(callId: callId);
  }
}
