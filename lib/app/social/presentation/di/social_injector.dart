import 'package:bimobondapp/app/social/data/datasources/social_remote_data_source.dart';
import 'package:bimobondapp/app/social/data/repositories/social_repository_impl.dart';
import 'package:bimobondapp/app/social/domain/repositories/social_repository.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initSocial() async {
  sl.registerLazySingleton<SocialRemoteDataSource>(
    () => SocialRemoteDataSourceImpl(apiClient: sl()),
  );

  sl.registerLazySingleton<SocialRepository>(
    () => SocialRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => ToggleFollowUseCase(sl()));
  sl.registerLazySingleton(() => GetFollowersUseCase(sl()));
  sl.registerLazySingleton(() => GetFollowingUseCase(sl()));
  sl.registerLazySingleton(() => GetMyFriendsUseCase(sl()));
  sl.registerLazySingleton(() => CheckIsFollowingUseCase(sl()));
}
