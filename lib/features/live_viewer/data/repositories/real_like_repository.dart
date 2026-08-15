import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/socket_event.dart';
import '../../domain/repositories/like_repository.dart';
import '../services/fake_socket_service.dart' show SocketService;

/// Real [LikeRepository] backed by the backend:
/// - `POST /lives/:id/like` → TikTok-style heart tap (each call bumps count)
/// - Socket `liveLike` events → real-time like count
///
/// Soft rate limit is 15 taps/sec/user/live (400 when exceeded) — bursts are
/// clamped to that window.
class RealLikeRepository implements LikeRepository {
  RealLikeRepository({
    required LiveApiClient apiClient,
    required SocketService socket,
  })  : _api = apiClient,
        _socket = socket;

  final LiveApiClient _api;
  final SocketService _socket;

  final Map<String, StreamController<int>> _countControllers = {};
  final Map<String, StreamSubscription<SocketEvent>> _subs = {};

  @override
  Future<Either<Failure, void>> likeLive(String liveId) async {
    try {
      await _api.post(ApiEndpoints.liveLike(liveId));
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to like: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unlikeLive(String liveId) async {
    // No unlike endpoint in mobile-api.md — no-op.
    return const Right(null);
  }

  @override
  Future<Either<Failure, bool>> hasLikedLive(String liveId) async {
    // No dedicated endpoint — optimistic local answer.
    return const Right(false);
  }

  @override
  Future<Either<Failure, int>> getLikeCount(String liveId) async {
    try {
      final payload = await _api.get(ApiEndpoints.liveById(liveId));
      final count = payload['likeCount'];
      if (count is int) return Right(count);
      if (count is num) return Right(count.toInt());
      return const Right(0);
    } catch (e) {
      return Left(ServerFailure('Failed to get like count: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> sendBurstLikes(
    String liveId,
    int count,
  ) async {
    // Soft limit: max 15 taps/sec/user/live.
    final safe = count.clamp(1, 15);
    try {
      for (var i = 0; i < safe; i++) {
        await _api.post(ApiEndpoints.liveLike(liveId));
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to send likes: $e'));
    }
  }

  @override
  Stream<Either<Failure, int>> watchLikeCount(String liveId) {
    _countControllers.putIfAbsent(
      liveId,
      () => StreamController<int>.broadcast(),
    );
    _subs.putIfAbsent(liveId, () {
      return _socket.events.listen((event) {
        if (event.liveId != liveId) return;
        if (event is LiveLikeEvent) {
          _countControllers[liveId]?.add(event.likeCount);
        }
      });
    });
    return _countControllers[liveId]!.stream.map(Right.new);
  }

  @override
  Stream<Either<Failure, bool>> watchHasLiked(String liveId) async* {
    yield Right(false);
  }

  void dispose() {
    for (final s in _subs.values) {
      s.cancel();
    }
    for (final c in _countControllers.values) {
      c.close();
    }
  }
}
