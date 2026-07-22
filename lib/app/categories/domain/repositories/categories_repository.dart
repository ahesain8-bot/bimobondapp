import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class CategoriesListQuery {
  const CategoriesListQuery({
    this.search,
    this.parentId,
    this.flat,
    this.isMain,
  });

  final String? search;
  final String? parentId;
  final bool? flat;
  final bool? isMain;
}

abstract class CategoriesRepository {
  Future<Either<Failure, List<CategoryEntity>>> getCategories([
    CategoriesListQuery query = const CategoriesListQuery(),
  ]);

  Future<Either<Failure, CategoryEntity>> getCategoryById(String id);
}
