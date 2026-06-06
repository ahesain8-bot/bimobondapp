import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_page_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetPostLikesUseCase
    implements UseCase<SocialUserPageEntity, GetPostLikesParams> {
  GetPostLikesUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, SocialUserPageEntity>> call(
    GetPostLikesParams params,
  ) {
    return repository.getPostLikes(
      params.postId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetPostLikesParams {
  const GetPostLikesParams({
    required this.postId,
    this.page = 1,
    this.limit = 20,
  });

  final String postId;
  final int page;
  final int limit;
}
