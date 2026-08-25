import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_exceptions.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../domain/entities/hourly_ranking_entity.dart';
import '../../domain/entities/socket_event.dart';
import '../../domain/repositories/ranking_repository.dart';
import '../datasources/ranking_remote_datasource.dart';
import '../services/fake_socket_service.dart' show SocketService;

/// Real [RankingRepository] backed by:
/// - `GET /lives/leaderboard/hourly`     → global hourly host ranking
/// - `GET /lives/:id/leaderboard/hourly` → this stream's rank this hour
/// - socket `liveHourlyRankUpdated`      → live rank movements
class RealRankingRepository implements RankingRepository {
  RealRankingRepository({
    required RankingRemoteDataSource remote,
    required SocketService socket,
  }) : _remote = remote,
       _socket = socket;

  final RankingRemoteDataSource _remote;
  final SocketService _socket;

  @override
  Future<Either<Failure, HourlyLeaderboard>> getHourlyLeaderboard({
    int limit = 20,
  }) async {
    try {
      return Right(await _remote.getHourlyLeaderboard(limit: limit));
    } catch (e) {
      return Left(_toFailure(e, 'Failed to load the hourly ranking'));
    }
  }

  @override
  Future<Either<Failure, LiveHourlyRank>> getLiveHourlyRank(
    String liveId,
  ) async {
    if (liveId.trim().isEmpty) {
      return const Left(ValidationFailure('Missing live id'));
    }
    try {
      return Right(await _remote.getLiveHourlyRank(liveId));
    } catch (e) {
      return Left(_toFailure(e, 'Failed to load this stream\'s hourly rank'));
    }
  }

  @override
  Stream<LiveHourlyRank> watchLiveHourlyRank(String liveId) {
    return _socket.events
        .where((e) => e is LiveHourlyRankEvent && e.liveId == liveId)
        .cast<LiveHourlyRankEvent>()
        .map((e) => e.rank);
  }

  Failure _toFailure(Object error, String fallbackMessage) {
    if (error is SocketException) {
      return NetworkFailure(
        'No internet connection. Please check your network and try again.',
        details: error.message,
      );
    }
    if (error is TimeoutException) {
      return const NetworkFailure('Connection timed out. Please try again.');
    }
    if (error is UnauthorizedException) {
      return AuthorizationFailure(
        error.message,
        code: error.statusCode?.toString(),
        details: error.details,
      );
    }
    if (error is NotFoundException) {
      return NotFoundFailure(
        error.message,
        code: error.statusCode?.toString(),
        details: error.details,
      );
    }
    if (error is ServiceUnavailableException) {
      return ServerFailure(
        'Ranking service is temporarily unavailable. Please try again later.',
        code: error.statusCode?.toString(),
        details: error.details,
      );
    }
    if (error is BadRequestException) {
      return ValidationFailure(
        error.message,
        code: error.statusCode?.toString(),
        details: error.details,
      );
    }
    if (error is ApiException) {
      return ServerFailure(
        error.message,
        code: error.statusCode?.toString(),
        details: error.details,
      );
    }
    return ServerFailure('$fallbackMessage: $error');
  }
}
