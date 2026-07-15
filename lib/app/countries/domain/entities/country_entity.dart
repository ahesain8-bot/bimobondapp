import 'package:equatable/equatable.dart';

class CountryEntity extends Equatable {
  const CountryEntity({
    required this.id,
    required this.code,
    required this.name,
    this.phoneCode,
    this.capital,
    this.emoji,
    this.region,
    this.currency,
  });

  final int id;
  final String code;
  final String name;
  final String? phoneCode;
  final String? capital;
  final String? emoji;
  final String? region;
  final String? currency;

  @override
  List<Object?> get props =>
      [id, code, name, phoneCode, capital, emoji, region, currency];
}

class CityEntity extends Equatable {
  const CityEntity({
    required this.id,
    required this.name,
    this.stateCode,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String name;
  final String? stateCode;
  final double? latitude;
  final double? longitude;

  @override
  List<Object?> get props => [id, name, stateCode, latitude, longitude];
}

class CountryCitiesResult extends Equatable {
  const CountryCitiesResult({
    required this.country,
    required this.cities,
  });

  final CountryEntity country;
  final List<CityEntity> cities;

  @override
  List<Object?> get props => [country, cities];
}
