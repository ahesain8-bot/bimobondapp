import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetRepliesUsecase implements UseCase<List<CommentEntity>, GetRepliesParams> {
  final PostsRepository repository;

  GetRepliesUsecase(this.repository);

  @override
  Future<Either<Failure, List<CommentEntity>>> call(GetRepliesParams params) async {
    return await repository.getReplies(params.commentId, page: params.page, limit: params.limit);
  }
}

class GetRepliesParams {
  final String commentId;
  final int page;
  final int limit;

  GetRepliesParams({required this.commentId, this.page = 1, this.limit = 20});
}
