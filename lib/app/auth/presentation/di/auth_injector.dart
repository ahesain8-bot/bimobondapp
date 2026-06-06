import 'package:bimobondapp/app/auth/domain/usecases/get_profile_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';
import 'package:bimobondapp/app/auth/domain/usecases/login_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/sign_up_with_email_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/verify_phone_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/sign_in_with_phone_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/sign_in_with_facebook_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/update_profile_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/get_admin_user_activity_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/get_user_by_id_usecase.dart';

import 'package:bimobondapp/app/auth/data/repositories/auth_repository_impl.dart';
import 'package:bimobondapp/app/auth/data/datasources/auth_remote_data_source.dart';
import 'package:bimobondapp/app/auth/data/datasources/auth_local_data_source.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/core/data/likes_local_data_source.dart';
import 'package:bimobondapp/core/data/viewed_stories_store.dart';
import 'package:bimobondapp/app/home/presentation/utils/active_stories_registry.dart';

final sl = GetIt.instance;

Future<void> initAuth() async {
  // SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  sl.registerLazySingleton<LikesLocalDataSource>(
    () => LikesLocalDataSourceImpl(sharedPreferences: sl()),
  );

  sl.registerLazySingleton<ViewedStoriesStore>(
    () => ViewedStoriesStore(sl()),
  );

  sl.registerLazySingleton<ActiveStoriesRegistry>(
    () => ActiveStoriesRegistry(),
  );

  // Core
  sl.registerLazySingleton(() => ApiClient(sharedPreferences: sl()));

  // Data sources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: sl()),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      likesLocalDataSource: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => SignUpWithEmailUseCase(sl()));
  sl.registerLazySingleton(() => VerifyPhoneUseCase(sl()));
  sl.registerLazySingleton(() => SignInWithPhoneUseCase(sl()));
  sl.registerLazySingleton(() => SignInWithFacebookUseCase(sl()));
  sl.registerLazySingleton(() => SignInWithGoogleUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl()));
  sl.registerLazySingleton(() => GetProfileUseCase(sl()));
  sl.registerLazySingleton(() => GetUserByIdUseCase(sl()));
  sl.registerLazySingleton(() => GetAdminUserActivityUseCase(sl()));

  // Bloc
  sl.registerFactory(
    () => AuthBloc(
      authRepository: sl(),
      loginUseCase: sl(),
      signUpWithEmailUseCase: sl(),
      verifyPhoneUseCase: sl(),
      signInWithPhoneUseCase: sl(),
      signInWithFacebookUseCase: sl(),
      signInWithGoogleUseCase: sl(),
      updateProfileUseCase: sl(),
      getProfileUseCase: sl(),
    ),
  );
}
