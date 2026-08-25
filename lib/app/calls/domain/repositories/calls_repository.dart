import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class CallsRepository {
  Future<Either<Failure, CallSessionEntity>> startCall({
    required String chatId,
    required String type,
    List<String>? inviteeIds,
  });

  Future<Either<Failure, CallEntity?>> getActiveCall({
    required String chatId,
  });

  Future<Either<Failure, CallEntity>> getCallById({
    required String callId,
  });

  Future<Either<Failure, CallSessionEntity>> acceptCall({
    required String callId,
  });

  Future<Either<Failure, CallEntity>> rejectCall({
    required String callId,
  });

  Future<Either<Failure, CallEntity>> endCall({
    required String callId,
  });

  Future<Either<Failure, CallEntity>> leaveCall({
    required String callId,
  });

  Future<Either<Failure, CallEntity>> inviteToCall({
    required String callId,
    required List<String> inviteeIds,
  });

  Future<Either<Failure, Map<String, dynamic>>> getCallHistory({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
  });
}
