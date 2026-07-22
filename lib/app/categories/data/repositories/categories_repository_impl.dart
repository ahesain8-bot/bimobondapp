import 'package:bimobondapp/app/categories/data/datasources/categories_remote_data_source.dart';
import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/repositories/categories_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  CategoriesRepositoryImpl({required this.remoteDataSource});

  final CategoriesRemoteDataSource remoteDataSource;

  CategoriesQuery _toRemote(CategoriesListQuery query) => CategoriesQuery(
        search: query.search,
        parentId: query.parentId,
        flat: query.flat,
        isMain: query.isMain,
      );

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories([
    CategoriesListQuery query = const CategoriesListQuery(),
  ]) async {
    try {
      final categories = await remoteDataSource.getCategories(_toRemote(query));
      return Right(categories);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CategoryEntity>> getCategoryById(String id) async {
    try {
      return Right(await remoteDataSource.getCategoryById(id));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
