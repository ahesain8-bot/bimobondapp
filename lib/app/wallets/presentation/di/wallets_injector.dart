import 'package:bimobondapp/app/wallets/data/datasources/wallets_remote_data_source.dart';
import 'package:bimobondapp/app/wallets/data/repositories/wallets_repository_impl.dart';
import 'package:bimobondapp/app/wallets/domain/repositories/wallets_repository.dart';
import 'package:bimobondapp/app/wallets/domain/usecases/wallet_usecases.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initWallets() async {
  sl.registerLazySingleton<WalletsRemoteDataSource>(
    () => WalletsRemoteDataSourceImpl(apiClient: sl()),
  );

  sl.registerLazySingleton<WalletsRepository>(
    () => WalletsRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetMyWalletUseCase(sl()));
  sl.registerLazySingleton(() => GetCoinPackagesUseCase(sl()));
  sl.registerLazySingleton(() => PurchaseCoinsUseCase(sl()));
  sl.registerLazySingleton(() => TopUpWalletUseCase(sl()));
}
