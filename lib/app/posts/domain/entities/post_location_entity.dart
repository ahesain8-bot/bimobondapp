import 'package:equatable/equatable.dart';

class PostLocationEntity extends Equatable {
  const PostLocationEntity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.city,
    this.countryCode,
    this.address,
    this.placeId,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? city;
  final String? countryCode;
  final String? address;
  final String? placeId;

  factory PostLocationEntity.fromJson(Map<String, dynamic> json) {
    return PostLocationEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      latitude: _toDouble(json['latitude']) ?? 0,
      longitude: _toDouble(json['longitude']) ?? 0,
      city: json['city']?.toString(),
      countryCode: json['countryCode']?.toString(),
      address: json['address']?.toString(),
      placeId: json['placeId']?.toString(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props =>
      [id, name, latitude, longitude, city, countryCode, address, placeId];
}

class PostInlineLocationInput extends Equatable {
  const PostInlineLocationInput({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.countryCode,
    this.placeId,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? countryCode;
  final String? placeId;

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    if (address != null && address!.isNotEmpty) 'address': address,
    if (city != null && city!.isNotEmpty) 'city': city,
    if (countryCode != null && countryCode!.isNotEmpty) 'countryCode': countryCode,
    if (placeId != null && placeId!.isNotEmpty) 'placeId': placeId,
  };

  @override
  List<Object?> get props =>
      [name, latitude, longitude, address, city, countryCode, placeId];
}
