import 'package:bimobondapp/app/camera_studio/data/datasources/camera_studio_local_data_source.dart';
import 'package:bimobondapp/app/camera_studio/data/datasources/camera_studio_remote_data_source.dart';
import 'package:bimobondapp/app/camera_studio/data/repositories/camera_studio_repository_impl.dart';
import 'package:bimobondapp/app/camera_studio/domain/repositories/camera_studio_repository.dart';
import 'package:bimobondapp/app/camera_studio/domain/usecases/get_camera_studio_catalog_usecase.dart';
import 'package:bimobondapp/app/camera_studio/presentation/services/camera_studio_catalog_loader.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> initCameraStudio() async {
  sl.registerLazySingleton<CameraStudioRemoteDataSource>(
    () => CameraStudioRemoteDataSourceImpl(apiClient: sl()),
  );

  sl.registerLazySingleton<CameraStudioLocalDataSource>(
    () => CameraStudioLocalDataSourceImpl(sharedPreferences: sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<CameraStudioRepository>(
    () => CameraStudioRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  sl.registerLazySingleton(() => GetCameraStudioCatalogUseCase(sl()));
  sl.registerLazySingleton(() => CameraStudioCatalogLoader(sl()));
}
