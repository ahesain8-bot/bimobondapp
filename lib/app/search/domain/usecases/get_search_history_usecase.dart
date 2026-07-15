import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/app/search/domain/repositories/search_history_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetSearchHistoryUseCase
    implements UseCase<SearchHistoryPageEntity, GetSearchHistoryParams> {
  GetSearchHistoryUseCase(this.repository);

  final SearchHistoryRepository repository;

  @override
  Future<Either<Failure, SearchHistoryPageEntity>> call(
    GetSearchHistoryParams params,
  ) {
    return repository.getHistory(
      category: params.category,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetSearchHistoryParams {
  const GetSearchHistoryParams({
    this.category,
    this.page = 1,
    this.limit = 10,
  });

  final String? category;
  final int page;
  final int limit;
}
