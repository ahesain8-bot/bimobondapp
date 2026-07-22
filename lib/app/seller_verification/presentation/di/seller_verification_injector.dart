import 'package:bimobondapp/app/seller_verification/data/datasources/seller_verification_remote_data_source.dart';
import 'package:bimobondapp/app/seller_verification/data/repositories/seller_verification_repository_impl.dart';
import 'package:bimobondapp/app/seller_verification/domain/repositories/seller_verification_repository.dart';
import 'package:bimobondapp/app/seller_verification/domain/usecases/seller_verification_usecases.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initSellerVerification() async {
  sl.registerLazySingleton<SellerVerificationRemoteDataSource>(
    () => SellerVerificationRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<SellerVerificationRepository>(
    () => SellerVerificationRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetSellerVerificationEligibilityUseCase(sl()));
  sl.registerLazySingleton(() => GetSellerVerificationMeUseCase(sl()));
  sl.registerLazySingleton(() => UploadSellerDocumentUseCase(sl()));
  sl.registerLazySingleton(() => SubmitSellerVerificationUseCase(sl()));
}
