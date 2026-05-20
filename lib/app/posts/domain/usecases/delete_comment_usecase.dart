import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class DeleteCommentUsecase implements UseCase<bool, String> {
  final PostsRepository repository;

  DeleteCommentUsecase(this.repository);

  @override
  Future<Either<Failure, bool>> call(String commentId) async {
    return await repository.deleteComment(commentId);
  }
}
