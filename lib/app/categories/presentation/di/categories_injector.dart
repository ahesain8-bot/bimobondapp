import 'package:bimobondapp/app/categories/data/datasources/categories_remote_data_source.dart';
import 'package:bimobondapp/app/categories/data/repositories/categories_repository_impl.dart';
import 'package:bimobondapp/app/categories/domain/repositories/categories_repository.dart';
import 'package:bimobondapp/app/categories/domain/usecases/get_categories_usecase.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initCategories() async {
  sl.registerLazySingleton<CategoriesRemoteDataSource>(
    () => CategoriesRemoteDataSourceImpl(apiClient: sl()),
  );

  sl.registerLazySingleton<CategoriesRepository>(
    () => CategoriesRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetCategoryByIdUseCase(sl()));
}
