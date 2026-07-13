import 'package:bimobondapp/app/countries/domain/entities/country_entity.dart';

class CountryModel extends CountryEntity {
  const CountryModel({
    required super.id,
    required super.code,
    required super.name,
    super.phoneCode,
    super.capital,
    super.emoji,
    super.region,
    super.currency,
  });

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    return CountryModel(
      id: _asInt(json['id']) ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phoneCode: json['phoneCode']?.toString(),
      capital: json['capital']?.toString(),
      emoji: json['emoji']?.toString(),
      region: json['region']?.toString(),
      currency: json['currency']?.toString(),
    );
  }
}

class CityModel extends CityEntity {
  const CityModel({
    required super.id,
    required super.name,
    super.stateCode,
    super.latitude,
    super.longitude,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      stateCode: json['stateCode']?.toString(),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
    );
  }
}

class CountryCitiesResultModel extends CountryCitiesResult {
  const CountryCitiesResultModel({
    required super.country,
    required super.cities,
  });

  factory CountryCitiesResultModel.fromJson(Map<String, dynamic> json) {
    final countryRaw = json['country'];
    final country = countryRaw is Map
        ? CountryModel.fromJson(Map<String, dynamic>.from(countryRaw))
        : const CountryModel(id: 0, code: '', name: '');

    final citiesRaw = json['cities'];
    final cities = citiesRaw is List
        ? citiesRaw
            .whereType<Map>()
            .map((e) => CityModel.fromJson(Map<String, dynamic>.from(e)))
            .where((c) => c.name.isNotEmpty)
            .toList()
        : <CityModel>[];

    return CountryCitiesResultModel(country: country, cities: cities);
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
