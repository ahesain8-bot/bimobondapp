import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/live_entity.dart';
import '../entities/live_session_entity.dart';

abstract class LiveRepository {
  /// GET /lives/feed
  Future<Either<Failure, List<LiveEntity>>> getLiveFeed({
    int page = 1,
    int limit = 10,
    String? category,
  });

  /// GET /lives/{id}
  Future<Either<Failure, LiveEntity>> getLiveById(String liveId);

  Future<Either<Failure, List<LiveEntity>>> getLivesByCategory(
    String category, {
    int page = 1,
    int limit = 10,
  });

  Future<Either<Failure, List<LiveEntity>>> searchLives(
    String query, {
    int page = 1,
    int limit = 10,
  });

  /// POST /lives/{id}/join — returns tokens for LiveKit + socket.
  Future<Either<Failure, JoinLiveResult>> joinLive(String liveId);

  /// POST /lives/{id}/leave
  Future<Either<Failure, void>> leaveLive(String liveId);

  Future<Either<Failure, void>> reportLive(
    String liveId, {
    required String reason,
    String? details,
  });

  Future<Either<Failure, void>> blockHost(String hostId);

  Future<Either<Failure, void>> unblockHost(String hostId);

  Future<Either<Failure, void>> followHost(String hostId);

  Future<Either<Failure, void>> unfollowHost(String hostId);

  Future<Either<Failure, List<String>>> getTrendingCategories();

  Future<Either<Failure, List<LiveEntity>>> getRecommendedLives({
    int limit = 10,
  });
}
