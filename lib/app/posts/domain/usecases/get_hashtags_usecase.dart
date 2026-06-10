import 'package:bimobondapp/app/posts/domain/entities/hashtag_entity.dart';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetHashtagsUseCase
    implements UseCase<HashtagsPageEntity, GetHashtagsParams> {
  GetHashtagsUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, HashtagsPageEntity>> call(GetHashtagsParams params) {
    return repository.getHashtags(
      page: params.page,
      limit: params.limit,
      search: params.search,
      sort: params.sort,
    );
  }
}

class GetHashtagsParams {
  const GetHashtagsParams({
    this.page = 1,
    this.limit = 20,
    this.search,
    this.sort = HashtagSort.popular,
  });

  final int page;
  final int limit;
  final String? search;
  final HashtagSort sort;
}
