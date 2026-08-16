import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/repositories/calls_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class AcceptCallUseCase {
  final CallsRepository repository;

  AcceptCallUseCase(this.repository);

  Future<Either<Failure, CallSessionEntity>> call({required String callId}) {
    return repository.acceptCall(callId: callId);
  }
}
