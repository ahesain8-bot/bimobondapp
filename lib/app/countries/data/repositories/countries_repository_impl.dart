import 'package:bimobondapp/app/countries/data/datasources/countries_remote_data_source.dart';
import 'package:bimobondapp/app/countries/domain/entities/country_entity.dart';
import 'package:bimobondapp/app/countries/domain/repositories/countries_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

const _excludedCountryCodes = {'IL'};

class CountriesRepositoryImpl implements CountriesRepository {
  CountriesRepositoryImpl({required this.remoteDataSource});

  final CountriesRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<CountryEntity>>> getCountries() async {
    try {
      final countries = await remoteDataSource.getCountries();
      final filtered = countries
          .where(
            (c) => !_excludedCountryCodes.contains(c.code.toUpperCase()),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return Right(filtered);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, CountryCitiesResult>> getCities(String code) async {
    try {
      final result = await remoteDataSource.getCities(code);
      final cities = List<CityEntity>.from(result.cities)
        ..sort((a, b) => a.name.compareTo(b.name));
      return Right(
        CountryCitiesResult(country: result.country, cities: cities),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
