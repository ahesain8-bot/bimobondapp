import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetCommentLikesUseCase
    implements UseCase<SocialUserPageEntity, GetCommentLikesParams> {
  GetCommentLikesUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, SocialUserPageEntity>> call(
    GetCommentLikesParams params,
  ) {
    return repository.getCommentLikes(
      params.commentId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetCommentLikesParams {
  const GetCommentLikesParams({
    required this.commentId,
    this.page = 1,
    this.limit = 20,
  });

  final String commentId;
  final int page;
  final int limit;
}
