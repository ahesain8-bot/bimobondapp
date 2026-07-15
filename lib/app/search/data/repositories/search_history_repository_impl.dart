import 'package:bimobondapp/app/search/data/datasources/search_history_remote_data_source.dart';
import 'package:bimobondapp/app/search/domain/entities/search_history_entity.dart';
import 'package:bimobondapp/app/search/domain/entities/search_trend_entity.dart';
import 'package:bimobondapp/app/search/domain/repositories/search_history_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class SearchHistoryRepositoryImpl implements SearchHistoryRepository {
  SearchHistoryRepositoryImpl({required this.remoteDataSource});

  final SearchHistoryRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, SearchHistoryPageEntity>> getHistory({
    String? category,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final pageResult = await remoteDataSource.getHistory(
        category: category,
        page: page,
        limit: limit,
      );
      return Right(pageResult);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SearchHistoryEntity>> addHistory({
    required String query,
    required String category,
  }) async {
    try {
      final item = await remoteDataSource.addHistory(
        query: query,
        category: category,
      );
      return Right(item);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, ClearSearchHistoryResult>> clearHistory({
    String? category,
  }) async {
    try {
      final result = await remoteDataSource.clearHistory(category: category);
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteHistory(String id) async {
    try {
      await remoteDataSource.deleteHistory(id);
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<SearchTrendEntity>>> getTrends({
    String? category,
    int limit = 10,
  }) async {
    try {
      final trends = await remoteDataSource.getTrends(
        category: category,
        limit: limit,
      );
      return Right(trends);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
