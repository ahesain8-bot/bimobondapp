import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/comment_entity.dart';

abstract class CommentRepository {
  /// Get comments for a live with pagination
  Future<Either<Failure, CommentBatch>> getComments({
    required String liveId,
    String? cursor,
    int limit = 20,
  });

  /// Send a comment
  Future<Either<Failure, CommentEntity>> sendComment({
    required String liveId,
    required String content,
    String? replyToUserId,
  });

  /// Delete a comment (if authorized)
  Future<Either<Failure, void>> deleteComment(String commentId);

  /// Report a comment
  Future<Either<Failure, void>> reportComment({
    required String commentId,
    required String reason,
    String? details,
  });

  /// Get recent comments stream (for real-time updates)
  Stream<Either<Failure, List<CommentEntity>>> watchComments(String liveId);

  /// Mark comments as read
  Future<Either<Failure, void>> markCommentsAsRead(String liveId);
}
