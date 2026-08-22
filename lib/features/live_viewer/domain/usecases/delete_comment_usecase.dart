import 'package:dartz/dartz.dart';

import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../repositories/comment_repository.dart';

class DeleteCommentUseCase {
  final CommentRepository _repository;

  DeleteCommentUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required String commentId,
    String? liveId,
  }) {
    return _repository.deleteComment(commentId, liveId: liveId);
  }
}
