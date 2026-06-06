import 'package:bimobondapp/app/posts/domain/entities/post_views_page_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetPostViewsUseCase
    implements UseCase<PostViewsPageEntity, GetPostViewsParams> {
  GetPostViewsUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, PostViewsPageEntity>> call(GetPostViewsParams params) {
    return repository.getPostViews(
      params.postId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetPostViewsParams {
  const GetPostViewsParams({
    required this.postId,
    this.page = 1,
    this.limit = 20,
  });

  final String postId;
  final int page;
  final int limit;
}
