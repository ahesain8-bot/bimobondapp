import 'package:bimobondapp/app/stories/data/datasources/stories_remote_data_source.dart';
import 'package:bimobondapp/app/stories/data/repositories/stories_repository_impl.dart';
import 'package:bimobondapp/app/stories/domain/repositories/stories_repository.dart';
import 'package:bimobondapp/app/stories/domain/usecases/stories_usecases.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initStories() async {
  sl.registerLazySingleton<StoriesRemoteDataSource>(
    () => StoriesRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<StoriesRepository>(
    () => StoriesRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => CreateStoryUseCase(sl()));
  sl.registerLazySingleton(() => GetStoryRingsUseCase(sl()));
  sl.registerLazySingleton(() => GetMyStoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetUserStoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetStoryByIdUseCase(sl()));
  sl.registerLazySingleton(() => DeleteStoryUseCase(sl()));
  sl.registerLazySingleton(() => RecordStoryViewUseCase(sl()));
  sl.registerLazySingleton(() => GetStoryViewersUseCase(sl()));
}
