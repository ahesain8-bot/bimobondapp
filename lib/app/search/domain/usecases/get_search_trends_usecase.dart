import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/app/search/domain/entities/search_trend_entity.dart';
import 'package:bimobondapp/app/search/domain/repositories/search_history_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetSearchTrendsUseCase
    implements UseCase<List<SearchTrendEntity>, GetSearchTrendsParams> {
  GetSearchTrendsUseCase(this.repository);

  final SearchHistoryRepository repository;

  @override
  Future<Either<Failure, List<SearchTrendEntity>>> call(
    GetSearchTrendsParams params,
  ) {
    return repository.getTrends(
      category: params.category,
      limit: params.limit,
    );
  }
}

class GetSearchTrendsParams extends Equatable {
  const GetSearchTrendsParams({
    this.category = SearchHistoryCategory.posts,
    this.limit = 10,
  });

  final String? category;
  final int limit;

  @override
  List<Object?> get props => [category, limit];
}
