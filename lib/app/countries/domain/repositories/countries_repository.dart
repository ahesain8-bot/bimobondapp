import 'package:bimobondapp/app/countries/domain/entities/country_entity.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class CountriesRepository {
  Future<Either<Failure, List<CountryEntity>>> getCountries();

  Future<Either<Failure, CountryCitiesResult>> getCities(String code);
}
