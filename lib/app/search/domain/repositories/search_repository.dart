import 'package:bimobondapp/app/search/domain/entities/search_result_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class SearchRepository {
  Future<Either<Failure, SearchResultEntity>> search({
    required String q,
    required SearchApiTab tab,
    int page = 1,
    int limit = 20,
  });
}
