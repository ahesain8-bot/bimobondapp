import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../domain/repositories/like_repository.dart';
import '../services/fake_socket_service.dart';

class FakeLikeRepository implements LikeRepository {
  final SocketService _socket;
  final Map<String, int> _likeCounts = {};
  final Set<String> _likedLives = {};
  final Map<String, StreamController<int>> _countControllers = {};

  FakeLikeRepository(this._socket);

  @override
  Future<Either<Failure, void>> likeLive(String liveId) async {
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      _likedLives.add(liveId);
      final next = (_likeCounts[liveId] ?? 0) + 1;
      _likeCounts[liveId] = next;
      _countControllers[liveId]?.add(next);
      await _socket.emitLike(likeCount: next, delta: 1);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to like: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unlikeLive(String liveId) async {
    await Future.delayed(const Duration(milliseconds: 120));
    _likedLives.remove(liveId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, bool>> hasLikedLive(String liveId) async {
    return Right(_likedLives.contains(liveId));
  }

  @override
  Future<Either<Failure, int>> getLikeCount(String liveId) async {
    return Right(_likeCounts[liveId] ?? 0);
  }

  @override
  Future<Either<Failure, void>> sendBurstLikes(String liveId, int count) async {
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      _likedLives.add(liveId);
      final next = (_likeCounts[liveId] ?? 0) + count;
      _likeCounts[liveId] = next;
      _countControllers[liveId]?.add(next);
      await _socket.emitLike(likeCount: next, delta: count);
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
    return _countControllers[liveId]!.stream.map(Right.new);
  }

  @override
  Stream<Either<Failure, bool>> watchHasLiked(String liveId) async* {
    yield Right(_likedLives.contains(liveId));
  }

  void seedLikeCount(String liveId, int count) {
    _likeCounts[liveId] = count;
  }
}
