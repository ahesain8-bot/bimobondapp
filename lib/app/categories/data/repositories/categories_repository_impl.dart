import 'package:bimobondapp/app/categories/data/datasources/categories_remote_data_source.dart';
import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/repositories/categories_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  CategoriesRepositoryImpl({required this.remoteDataSource});

  final CategoriesRemoteDataSource remoteDataSource;

  Failure _mapException(Object e) => FailureMapper.from(e);

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async {
    try {
      final categories = await remoteDataSource.getCategories();
      return Right(categories);
    } catch (e) {
      return Left(_mapException(e));
    }
  }
}
