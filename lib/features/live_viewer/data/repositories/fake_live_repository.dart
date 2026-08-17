import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../domain/repositories/live_repository.dart';
import '../datasources/live_remote_datasource.dart';

class FakeLiveRepository implements LiveRepository {
  final LiveRemoteDataSource _remote;

  FakeLiveRepository(this._remote);

  @override
  Future<Either<Failure, List<LiveEntity>>> getLiveFeed({
    int page = 1,
    int limit = 10,
    String? category,
  }) async {
    try {
      final lives = await _remote.getLiveFeed(
        page: page,
        limit: limit,
        category: category,
      );
      final activeLives = lives
          .where((l) => l.status == LiveStatus.live)
          .toList();
      return Right(activeLives);
    } on SocketException catch (e) {
      return Left(NetworkFailure(
        'No internet connection. Please check your network and try again.',
        details: e.message,
      ));
    } on TimeoutException {
      return const Left(NetworkFailure(
        'Connection timed out. Please try again.',
      ));
    } on UnauthorizedException catch (e) {
      return Left(AuthorizationFailure(
        e.message,
        code: e.statusCode?.toString(),
        details: e.details,
      ));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(
        e.message,
        code: e.statusCode?.toString(),
        details: e.details,
      ));
    } on ServiceUnavailableException catch (e) {
      return Left(ServerFailure(
        'Live service is temporarily unavailable. Please try again later.',
        code: e.statusCode?.toString(),
        details: e.details,
      ));
    } on BadRequestException catch (e) {
      return Left(ValidationFailure(
        e.message,
        code: e.statusCode?.toString(),
        details: e.details,
      ));
    } on ApiException catch (e) {
      return Left(ServerFailure(
        e.message,
        code: e.statusCode?.toString(),
        details: e.details,
      ));
    } catch (e) {
      return Left(ServerFailure('Failed to fetch live feed: $e'));
    }
  }

  @override
  Future<Either<Failure, LiveEntity>> getLiveById(String liveId) async {
    try {
      final live = await _remote.getLiveById(liveId);
      return Right(live);
    } catch (e) {
      return const Left(NotFoundFailure('Live not found'));
    }
  }

  @override
  Future<Either<Failure, List<LiveEntity>>> getLivesByCategory(
    String category, {
    int page = 1,
    int limit = 10,
  }) {
    return getLiveFeed(page: page, limit: limit, category: category);
  }

  @override
  Future<Either<Failure, List<LiveEntity>>> searchLives(
    String query, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final lives = await _remote.getLiveFeed(page: page, limit: limit);
      final filtered = lives.where((live) {
        final q = query.toLowerCase();
        return live.title.toLowerCase().contains(q) ||
            live.hostName.toLowerCase().contains(q) ||
            live.category.toLowerCase().contains(q);
      }).toList();
      return Right(filtered);
    } catch (e) {
      return Left(ServerFailure('Search failed: $e'));
    }
  }

  @override
  Future<Either<Failure, JoinLiveResult>> joinLive(String liveId) async {
    try {
      final result = await _remote.joinLive(liveId);
      return Right(result);
    } on SocketException catch (e) {
      return Left(NetworkFailure(
        'No internet connection. Please check your network and try again.',
        details: e.message,
      ));
    } on TimeoutException {
      return const Left(NetworkFailure(
        'Connection timed out. Please try again.',
      ));
    } on UnauthorizedException catch (e) {
      return Left(AuthorizationFailure(
        e.message,
        code: e.statusCode?.toString(),
        details: e.details,
      ));
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(
        e.message,
        code: e.statusCode?.toString(),
        details: e.details,
      ));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('BANNED')) {
        return const Left(AuthorizationFailure(
          'You are banned from this live stream.',
          code: 'USER_BANNED',
        ));
      }
      if (msg.contains('ENDED')) {
        return const Left(NotFoundFailure(
          'This live stream has ended.',
          code: 'LIVE_ENDED',
        ));
      }
      if (msg.contains('INVALID_JOIN_RESPONSE')) {
        return const Left(ServerFailure(
          'Failed to start stream. Please try again.',
          code: 'INVALID_JOIN_RESPONSE',
        ));
      }
      return Left(ServerFailure('Failed to join live: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> leaveLive(String liveId) async {
    try {
      await _remote.leaveLive(liveId);
      return const Right(null);
    } on SocketException catch (e) {
      return Left(NetworkFailure(
        'No internet connection.',
        details: e.message,
      ));
    } on UnauthorizedException catch (e) {
      return Left(AuthorizationFailure(
        e.message,
        code: e.statusCode?.toString(),
        details: e.details,
      ));
    } catch (e) {
      return Left(ServerFailure('Failed to leave live: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> reportLive(
    String liveId, {
    required String reason,
    String? details,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> blockHost(String hostId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unblockHost(String hostId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> followHost(String hostId) async {
    try {
      await _remote.followHost(hostId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Follow failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unfollowHost(String hostId) async {
    try {
      await _remote.unfollowHost(hostId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Unfollow failed: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getTrendingCategories() async {
    try {
      return Right(await _remote.getTrendingCategories());
    } catch (e) {
      return Left(ServerFailure('Failed to load categories: $e'));
    }
  }

  @override
  Future<Either<Failure, List<LiveEntity>>> getRecommendedLives({
    int limit = 10,
  }) {
    return getLiveFeed(limit: limit);
  }
}
