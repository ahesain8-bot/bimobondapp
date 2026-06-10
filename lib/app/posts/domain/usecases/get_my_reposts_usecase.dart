import 'package:bimobondapp/app/posts/domain/entities/user_repost_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetMyRepostsUseCase
    implements UseCase<UserRepostsPageEntity, GetMyRepostsParams> {
  GetMyRepostsUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, UserRepostsPageEntity>> call(
    GetMyRepostsParams params,
  ) {
    return repository.getMyReposts(
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetMyRepostsParams {
  const GetMyRepostsParams({
    this.page = 1,
    this.limit = 10,
  });

  final int page;
  final int limit;
}
