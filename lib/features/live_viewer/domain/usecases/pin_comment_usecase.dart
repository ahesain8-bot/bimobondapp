import 'package:dartz/dartz.dart';

import '../repositories/comment_repository.dart';
import '../../core/errors/failures.dart';

class PinCommentUseCase {
  const PinCommentUseCase(this._repository);

  final CommentRepository _repository;

  Future<Either<Failure, void>> call({
    required String liveId,
    required String commentId,
    required bool pinned,
  }) {
    return pinned
        ? _repository.pinComment(liveId: liveId, commentId: commentId)
        : _repository.unpinComment(liveId: liveId, commentId: commentId);
  }
}
