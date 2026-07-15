import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/app/search/domain/entities/search_trend_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class SearchHistoryRepository {
  Future<Either<Failure, SearchHistoryPageEntity>> getHistory({
    String? category,
    int page = 1,
    int limit = 10,
  });

  Future<Either<Failure, SearchHistoryEntity>> addHistory({
    required String query,
    required String category,
  });

  Future<Either<Failure, ClearSearchHistoryResult>> clearHistory({
    String? category,
  });

  Future<Either<Failure, void>> deleteHistory(String id);

  Future<Either<Failure, List<SearchTrendEntity>>> getTrends({
    String? category,
    int limit = 10,
  });
}
