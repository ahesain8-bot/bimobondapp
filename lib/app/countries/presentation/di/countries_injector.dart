import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' show sl;
import 'package:bimobondapp/app/countries/data/datasources/countries_remote_data_source.dart';
import 'package:bimobondapp/app/countries/data/repositories/countries_repository_impl.dart';
import 'package:bimobondapp/app/countries/domain/repositories/countries_repository.dart';
import 'package:bimobondapp/app/countries/domain/usecases/get_countries_usecase.dart';
import 'package:bimobondapp/app/countries/domain/usecases/get_country_cities_usecase.dart';

export 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' show sl;

Future<void> initCountries() async {
  sl.registerLazySingleton<CountriesRemoteDataSource>(
    () => CountriesRemoteDataSource(apiClient: sl()),
  );

  sl.registerLazySingleton<CountriesRepository>(
    () => CountriesRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton(() => GetCountriesUseCase(sl()));
  sl.registerLazySingleton(() => GetCountryCitiesUseCase(sl()));
}
