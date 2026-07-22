import 'package:bimobondapp/app/categories/domain/entities/category_entity.dart';
import 'package:bimobondapp/app/categories/domain/repositories/categories_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetCategoriesParams extends Equatable {
  const GetCategoriesParams({
    this.search,
    this.parentId,
    this.flat,
    this.isMain,
  });

  /// Default tree of active mains + children.
  const GetCategoriesParams.tree() : this();

  /// Flat list for pickers (mains + subs, no nesting).
  const GetCategoriesParams.flat({this.isMain})
      : search = null,
        parentId = null,
        flat = true;

  final String? search;
  final String? parentId;
  final bool? flat;
  final bool? isMain;

  @override
  List<Object?> get props => [search, parentId, flat, isMain];
}

class GetCategoriesUseCase
    implements UseCase<List<CategoryEntity>, GetCategoriesParams> {
  GetCategoriesUseCase(this.repository);

  final CategoriesRepository repository;

  @override
  Future<Either<Failure, List<CategoryEntity>>> call(
    GetCategoriesParams params,
  ) {
    return repository.getCategories(
      CategoriesListQuery(
        search: params.search,
        parentId: params.parentId,
        flat: params.flat,
        isMain: params.isMain,
      ),
    );
  }
}

class GetCategoryByIdUseCase implements UseCase<CategoryEntity, String> {
  GetCategoryByIdUseCase(this.repository);

  final CategoriesRepository repository;

  @override
  Future<Either<Failure, CategoryEntity>> call(String params) {
    return repository.getCategoryById(params);
  }
}
