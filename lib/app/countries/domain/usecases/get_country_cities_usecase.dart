import 'package:bimobondapp/app/countries/domain/entities/country_entity.dart';
import 'package:bimobondapp/app/countries/domain/repositories/countries_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class GetCountryCitiesUseCase
    implements UseCase<CountryCitiesResult, GetCountryCitiesParams> {
  GetCountryCitiesUseCase(this.repository);

  final CountriesRepository repository;

  @override
  Future<Either<Failure, CountryCitiesResult>> call(
    GetCountryCitiesParams params,
  ) {
    return repository.getCities(params.code);
  }
}

class GetCountryCitiesParams extends Equatable {
  const GetCountryCitiesParams({required this.code});

  final String code;

  @override
  List<Object?> get props => [code];
}
