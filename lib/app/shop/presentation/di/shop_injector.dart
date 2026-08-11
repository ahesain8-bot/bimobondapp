import 'package:bimobondapp/app/shop/data/datasources/shop_cart_local_cache.dart';
import 'package:bimobondapp/app/shop/data/datasources/shop_favorites_local_store.dart';
import 'package:bimobondapp/app/shop/data/datasources/shop_remote_data_source.dart';
import 'package:bimobondapp/app/shop/data/repositories/shop_repository_impl.dart';
import 'package:bimobondapp/app/shop/data/services/coins_payment_service.dart';
import 'package:bimobondapp/app/shop/domain/repositories/shop_repository.dart';
import 'package:bimobondapp/app/shop/domain/services/payment_service.dart';
import 'package:bimobondapp/app/shop/domain/usecases/shop_usecases.dart';
import 'package:bimobondapp/app/shop/presentation/cubit/shop_cart_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> initShop() async {
  sl.registerLazySingleton<ShopRemoteDataSource>(
    () => ShopRemoteDataSourceImpl(apiClient: sl()),
  );

  sl.registerLazySingleton<ShopCartLocalCache>(
    () => ShopCartLocalCache(sharedPreferences: sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<ShopFavoritesLocalStore>(
    () => ShopFavoritesLocalStore(sharedPreferences: sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(
      remoteDataSource: sl(),
      cartLocalCache: sl(),
    ),
  );

  sl.registerLazySingleton<PaymentService>(
    () => CoinsPaymentService(repository: sl()),
  );

  sl.registerLazySingleton(() => BrowseProductsUseCase(sl()));
  sl.registerLazySingleton(() => GetPlatformShopUseCase(sl()));
  sl.registerLazySingleton(() => GetProductUseCase(sl()));
  sl.registerLazySingleton(() => GetProductCategoriesUseCase(sl()));
  sl.registerLazySingleton(() => GetCartUseCase(sl()));
  sl.registerLazySingleton(() => AddCartItemUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCartItemUseCase(sl()));
  sl.registerLazySingleton(() => RemoveCartItemUseCase(sl()));
  sl.registerLazySingleton(() => ClearCartUseCase(sl()));
  sl.registerLazySingleton(() => PreviewCheckoutUseCase(sl()));
  sl.registerLazySingleton(() => CheckoutUseCase(sl()));
  sl.registerLazySingleton(() => GetMyOrdersUseCase(sl()));
  sl.registerLazySingleton(() => GetPurchasedProductsUseCase(sl()));
  sl.registerLazySingleton(() => GetSalesOrdersUseCase(sl()));
  sl.registerLazySingleton(() => GetOrderUseCase(sl()));
  sl.registerLazySingleton(() => ShipOrderUseCase(sl()));
  sl.registerLazySingleton(() => ReceiveOrderUseCase(sl()));
  sl.registerLazySingleton(() => AcceptOrderUseCase(sl()));
  sl.registerLazySingleton(() => DisputeOrderUseCase(sl()));
  sl.registerLazySingleton(() => GetLiveProductsUseCase(sl()));
  sl.registerLazySingleton(() => AddLiveProductUseCase(sl()));
  sl.registerLazySingleton(() => PinLiveProductUseCase(sl()));
  sl.registerLazySingleton(() => RemoveLiveProductUseCase(sl()));

  sl.registerLazySingleton(
    () => ShopCartCubit(getCartUseCase: sl())..refresh(),
  );
}
