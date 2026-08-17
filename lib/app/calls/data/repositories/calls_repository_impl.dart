import 'package:bimobondapp/app/calls/data/datasources/calls_remote_data_source.dart';
import 'package:bimobondapp/app/calls/domain/entities/call_entity.dart';
import 'package:bimobondapp/app/calls/domain/repositories/calls_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class CallsRepositoryImpl implements CallsRepository {
  final CallsRemoteDataSource remoteDataSource;

  CallsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, CallSessionEntity>> startCall({
    required String chatId,
    required String type,
    List<String>? inviteeIds,
  }) async {
    try {
      final result = await remoteDataSource.startCall(
        chatId: chatId,
        type: type,
        inviteeIds: inviteeIds,
      );
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CallEntity?>> getActiveCall({
    required String chatId,
  }) async {
    try {
      final result = await remoteDataSource.getActiveCall(chatId: chatId);
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CallEntity>> getCallById({
    required String callId,
  }) async {
    try {
      final result = await remoteDataSource.getCallById(callId: callId);
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CallSessionEntity>> acceptCall({
    required String callId,
  }) async {
    try {
      final result = await remoteDataSource.acceptCall(callId: callId);
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CallEntity>> rejectCall({
    required String callId,
  }) async {
    try {
      final result = await remoteDataSource.rejectCall(callId: callId);
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CallEntity>> endCall({
    required String callId,
  }) async {
    try {
      final result = await remoteDataSource.endCall(callId: callId);
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CallEntity>> leaveCall({
    required String callId,
  }) async {
    try {
      final result = await remoteDataSource.leaveCall(callId: callId);
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CallEntity>> inviteToCall({
    required String callId,
    required List<String> inviteeIds,
  }) async {
    try {
      final result = await remoteDataSource.inviteToCall(
        callId: callId,
        inviteeIds: inviteeIds,
      );
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getCallHistory({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
  }) async {
    try {
      final result = await remoteDataSource.getCallHistory(
        page: page,
        limit: limit,
        status: status,
        type: type,
      );
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
