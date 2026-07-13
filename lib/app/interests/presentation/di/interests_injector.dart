import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' show sl;
import 'package:bimobondapp/app/interests/data/datasources/interests_remote_data_source.dart';
import 'package:bimobondapp/app/interests/data/repositories/interests_repository_impl.dart';
import 'package:bimobondapp/app/interests/domain/repositories/interests_repository.dart';
import 'package:bimobondapp/app/interests/domain/usecases/get_my_interests_usecase.dart';
import 'package:bimobondapp/app/interests/domain/usecases/set_my_interests_usecase.dart';

export 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' show sl;

Future<void> initInterests() async {
  sl.registerLazySingleton<InterestsRemoteDataSource>(
    () => InterestsRemoteDataSource(apiClient: sl()),
  );

  sl.registerLazySingleton<InterestsRepository>(
    () => InterestsRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetMyInterestsUseCase(sl()));
  sl.registerLazySingleton(() => SetMyInterestsUseCase(sl()));
}
