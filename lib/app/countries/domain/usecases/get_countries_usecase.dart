import 'package:bimobondapp/app/countries/domain/entities/country_entity.dart';
import 'package:bimobondapp/app/countries/domain/repositories/countries_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetCountriesUseCase implements UseCase<List<CountryEntity>, NoParams> {
  GetCountriesUseCase(this.repository);

  final CountriesRepository repository;

  @override
  Future<Either<Failure, List<CountryEntity>>> call(NoParams params) {
    return repository.getCountries();
  }
}
