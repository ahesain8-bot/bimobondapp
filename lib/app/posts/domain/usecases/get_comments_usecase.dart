import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetCommentsUsecase implements UseCase<List<CommentEntity>, GetCommentsParams> {
  final PostsRepository repository;

  GetCommentsUsecase(this.repository);

  @override
  Future<Either<Failure, List<CommentEntity>>> call(GetCommentsParams params) async {
    return await repository.getComments(params.postId, page: params.page, limit: params.limit);
  }
}

class GetCommentsParams {
  final String postId;
  final int page;
  final int limit;

  GetCommentsParams({required this.postId, this.page = 1, this.limit = 20});
}
