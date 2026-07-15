import 'package:bimobondapp/app/search/data/datasources/search_remote_data_source.dart';
import 'package:bimobondapp/app/search/domain/entities/search_result_entity.dart';
import 'package:bimobondapp/app/search/domain/repositories/search_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({required this.remoteDataSource});

  final SearchRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, SearchResultEntity>> search({
    required String q,
    required SearchApiTab tab,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final result = await remoteDataSource.search(
        q: q,
        tab: tab,
        page: page,
        limit: limit,
      );
      return Right(result);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
