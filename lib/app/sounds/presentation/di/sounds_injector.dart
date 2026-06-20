import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' show sl;
import 'package:bimobondapp/app/sounds/data/datasources/sounds_remote_data_source.dart';
import 'package:bimobondapp/app/sounds/data/repositories/sounds_repository_impl.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_my_sounds_usecase.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_sound_detail_usecase.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_sounds_usecase.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/get_trending_sounds_usecase.dart';
import 'package:bimobondapp/app/sounds/domain/usecases/upload_sound_usecase.dart';

export 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' show sl;

Future<void> initSounds() async {
  sl.registerLazySingleton<SoundsRemoteDataSource>(
    () => SoundsRemoteDataSource(apiClient: sl()),
  );

  sl.registerLazySingleton<SoundsRepository>(
    () => SoundsRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetTrendingSoundsUseCase(sl()));
  sl.registerLazySingleton(() => GetSoundsUseCase(sl()));
  sl.registerLazySingleton(() => GetMySoundsUseCase(sl()));
  sl.registerLazySingleton(() => GetSoundDetailUseCase(sl()));
  sl.registerLazySingleton(() => UploadSoundUseCase(sl()));
}
