import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetPostRepostsUseCase
    implements UseCase<RepostsPageEntity, GetPostRepostsParams> {
  GetPostRepostsUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, RepostsPageEntity>> call(
    GetPostRepostsParams params,
  ) {
    return repository.getPostReposts(
      params.postId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetPostRepostsParams {
  const GetPostRepostsParams({
    required this.postId,
    this.page = 1,
    this.limit = 20,
  });

  final String postId;
  final int page;
  final int limit;
}
