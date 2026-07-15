import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' show sl;
import 'package:bimobondapp/app/search/data/datasources/search_history_remote_data_source.dart';
import 'package:bimobondapp/app/search/data/datasources/search_remote_data_source.dart';
import 'package:bimobondapp/app/search/data/repositories/search_history_repository_impl.dart';
import 'package:bimobondapp/app/search/data/repositories/search_repository_impl.dart';
import 'package:bimobondapp/app/search/domain/repositories/search_history_repository.dart';
import 'package:bimobondapp/app/search/domain/repositories/search_repository.dart';
import 'package:bimobondapp/app/search/domain/usecases/add_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/clear_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/delete_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/get_search_history_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/get_search_trends_usecase.dart';
import 'package:bimobondapp/app/search/domain/usecases/search_usecase.dart';

export 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' show sl;

Future<void> initSearch() async {
  sl.registerLazySingleton<SearchHistoryRemoteDataSource>(
    () => SearchHistoryRemoteDataSource(apiClient: sl()),
  );
  sl.registerLazySingleton<SearchRemoteDataSource>(
    () => SearchRemoteDataSource(apiClient: sl()),
  );

  sl.registerLazySingleton<SearchHistoryRepository>(
    () => SearchHistoryRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetSearchHistoryUseCase(sl()));
  sl.registerLazySingleton(() => GetSearchTrendsUseCase(sl()));
  sl.registerLazySingleton(() => AddSearchHistoryUseCase(sl()));
  sl.registerLazySingleton(() => ClearSearchHistoryUseCase(sl()));
  sl.registerLazySingleton(() => DeleteSearchHistoryUseCase(sl()));
  sl.registerLazySingleton(() => SearchUseCase(sl()));
}
