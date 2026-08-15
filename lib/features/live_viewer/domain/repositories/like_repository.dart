import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';

abstract class LikeRepository {
  /// Like a live
  Future<Either<Failure, void>> likeLive(String liveId);

  /// Unlike a live
  Future<Either<Failure, void>> unlikeLive(String liveId);

  /// Check if user has liked a live
  Future<Either<Failure, bool>> hasLikedLive(String liveId);

  /// Get like count for a live
  Future<Either<Failure, int>> getLikeCount(String liveId);

  /// Send multiple likes (burst)
  Future<Either<Failure, void>> sendBurstLikes(String liveId, int count);

  /// Watch like count updates (real-time)
  Stream<Either<Failure, int>> watchLikeCount(String liveId);

  /// Watch if current user has liked (real-time)
  Stream<Either<Failure, bool>> watchHasLiked(String liveId);
}
