import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/app/search/domain/repositories/search_history_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class ClearSearchHistoryUseCase
    implements UseCase<ClearSearchHistoryResult, ClearSearchHistoryParams> {
  ClearSearchHistoryUseCase(this.repository);

  final SearchHistoryRepository repository;

  @override
  Future<Either<Failure, ClearSearchHistoryResult>> call(
    ClearSearchHistoryParams params,
  ) {
    return repository.clearHistory(category: params.category);
  }
}

class ClearSearchHistoryParams {
  const ClearSearchHistoryParams({this.category});

  final String? category;
}
