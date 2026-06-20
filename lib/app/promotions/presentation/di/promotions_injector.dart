import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/app/promotions/data/datasources/promotions_remote_data_source.dart';

Future<void> initPromotions() async {
  sl.registerLazySingleton<PromotionsRemoteDataSource>(
    () => PromotionsRemoteDataSource(apiClient: sl()),
  );
}
