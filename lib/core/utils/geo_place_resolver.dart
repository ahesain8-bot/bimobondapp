import 'package:bimobondapp/core/utils/google_maps_constants.dart';
import 'package:dio/dio.dart';

class GeoPlaceInfo {
  const GeoPlaceInfo({
    required this.city,
    required this.region,
    required this.country,
    required this.continent,
  });

  final String city;
  final String region;
  final String country;
  final String continent;

  String get displayLabel => '$city · $country · $continent';
}

class GeoPlaceResolver {
  GeoPlaceResolver._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static String? usableApiField(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '—') return null;
    return trimmed;
  }

  static Future<GeoPlaceInfo?> resolve({
    required double latitude,
    required double longitude,
  }) async {
    final address = await resolveAddress(
      latitude: latitude,
      longitude: longitude,
    );
    if (address == null) return null;

    return GeoPlaceInfo(
      city: address.city ?? '—',
      region: address.region ?? '—',
      country: address.country ?? '—',
      continent: address.continent ?? '—',
    );
  }

  static Future<GeoAddress?> resolveAddress({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$latitude,$longitude',
          'key': GoogleMapsConstants.mapsApiKey,
        },
      );

      final data = response.data;
      if (data == null || data['status'] != 'OK') return null;

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final first = results.first;
      if (first is! Map<String, dynamic>) return null;

      final components = first['address_components'] as List<dynamic>? ?? [];
      final city = _componentValue(
        components,
        const ['locality', 'postal_town', 'sublocality', 'administrative_area_level_2'],
      );
      final region = _componentValue(
        components,
        const ['administrative_area_level_1'],
      );
      final country = _componentValue(components, const ['country']);
      final isoCountryCode = _componentShortName(components, const ['country']);
      final continent = continentFromIsoCountryCode(isoCountryCode) ??
          continentFromCoordinates(latitude, longitude);

      if (city == null && region == null && country == null) return null;

      return GeoAddress(
        city: city,
        region: region,
        country: country,
        continent: continent,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _componentValue(
    List<dynamic> components,
    List<String> types,
  ) {
    for (final type in types) {
      for (final component in components) {
        if (component is! Map<String, dynamic>) continue;
        final componentTypes = component['types'] as List<dynamic>? ?? [];
        if (!componentTypes.contains(type)) continue;
        final longName = component['long_name'] as String?;
        if (longName != null && longName.trim().isNotEmpty) {
          return longName.trim();
        }
      }
    }
    return null;
  }

  static String? _componentShortName(
    List<dynamic> components,
    List<String> types,
  ) {
    for (final type in types) {
      for (final component in components) {
        if (component is! Map<String, dynamic>) continue;
        final componentTypes = component['types'] as List<dynamic>? ?? [];
        if (!componentTypes.contains(type)) continue;
        final shortName = component['short_name'] as String?;
        if (shortName != null && shortName.trim().isNotEmpty) {
          return shortName.trim();
        }
      }
    }
    return null;
  }

  static String? continentFromIsoCountryCode(String? isoCountryCode) {
    if (isoCountryCode == null || isoCountryCode.isEmpty) return null;
    return _isoToContinent[isoCountryCode.toUpperCase()];
  }

  static String? continentFromCoordinates(double latitude, double longitude) {
    if (latitude <= -60) return 'Antarctica';

    if (longitude >= -170 &&
        longitude <= -30 &&
        latitude >= 5 &&
        latitude <= 83) {
      return 'North America';
    }
    if (longitude >= -82 &&
        longitude <= -34 &&
        latitude >= -56 &&
        latitude <= 13) {
      return 'South America';
    }
    if (longitude >= 110 && latitude <= 10 && latitude >= -50) {
      return 'Oceania';
    }
    if (longitude >= -25 &&
        longitude <= 60 &&
        latitude >= -35 &&
        latitude <= 37) {
      return 'Africa';
    }
    if (longitude >= 25 && longitude <= 180 && latitude >= -10) {
      return 'Asia';
    }
    if (longitude >= -25 &&
        longitude <= 45 &&
        latitude >= 35 &&
        latitude <= 72) {
      return 'Europe';
    }
    if (longitude >= 110 && latitude >= -50 && latitude <= 10) {
      return 'Oceania';
    }
    return null;
  }

  static const Map<String, String> _isoToContinent = {
    'AE': 'Asia',
    'SA': 'Asia',
    'QA': 'Asia',
    'KW': 'Asia',
    'BH': 'Asia',
    'OM': 'Asia',
    'YE': 'Asia',
    'IQ': 'Asia',
    'JO': 'Asia',
    'LB': 'Asia',
    'SY': 'Asia',
    'PS': 'Asia',
    'IL': 'Asia',
    'TR': 'Asia',
    'IR': 'Asia',
    'EG': 'Africa',
    'MA': 'Africa',
    'DZ': 'Africa',
    'TN': 'Africa',
    'LY': 'Africa',
    'SD': 'Africa',
    'US': 'North America',
    'CA': 'North America',
    'MX': 'North America',
    'GB': 'Europe',
    'FR': 'Europe',
    'DE': 'Europe',
    'IT': 'Europe',
    'ES': 'Europe',
    'PT': 'Europe',
    'NL': 'Europe',
    'BE': 'Europe',
    'CH': 'Europe',
    'AT': 'Europe',
    'SE': 'Europe',
    'NO': 'Europe',
    'DK': 'Europe',
    'FI': 'Europe',
    'PL': 'Europe',
    'RU': 'Europe',
    'UA': 'Europe',
    'GR': 'Europe',
    'IN': 'Asia',
    'PK': 'Asia',
    'BD': 'Asia',
    'CN': 'Asia',
    'JP': 'Asia',
    'KR': 'Asia',
    'ID': 'Asia',
    'MY': 'Asia',
    'SG': 'Asia',
    'TH': 'Asia',
    'VN': 'Asia',
    'PH': 'Asia',
    'AU': 'Oceania',
    'NZ': 'Oceania',
    'BR': 'South America',
    'AR': 'South America',
    'CL': 'South America',
    'CO': 'South America',
    'PE': 'South America',
    'ZA': 'Africa',
    'NG': 'Africa',
    'KE': 'Africa',
    'ET': 'Africa',
    'GH': 'Africa',
  };
}

class GeoAddress {
  const GeoAddress({this.city, this.region, this.country, this.continent});

  final String? city;
  final String? region;
  final String? country;
  final String? continent;
}
