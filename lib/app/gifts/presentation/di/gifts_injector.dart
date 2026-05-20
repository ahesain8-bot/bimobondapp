import 'package:bimobondapp/app/gifts/data/datasources/gifts_remote_data_source.dart';
import 'package:bimobondapp/app/gifts/data/repositories/gifts_repository_impl.dart';
import 'package:bimobondapp/app/gifts/domain/repositories/gifts_repository.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gift_inventory_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/get_gifts_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/purchase_gift_usecase.dart';
import 'package:bimobondapp/app/gifts/domain/usecases/send_gift_usecase.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initGifts() async {
  sl.registerLazySingleton<GiftsRemoteDataSource>(
    () => GiftsRemoteDataSourceImpl(apiClient: sl()),
  );

  sl.registerLazySingleton<GiftsRepository>(
    () => GiftsRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetGiftsUseCase(sl()));
  sl.registerLazySingleton(() => GetGiftInventoryUseCase(sl()));
  sl.registerLazySingleton(() => PurchaseGiftUseCase(sl()));
  sl.registerLazySingleton(() => SendGiftUseCase(sl()));
}
