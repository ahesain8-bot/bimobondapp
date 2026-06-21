import 'package:geocoding/geocoding.dart';

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
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final placemark = placemarks.first;
      final city = _firstNonEmpty([
        placemark.locality,
        placemark.subLocality,
        placemark.subAdministrativeArea,
      ]);
      final region = _firstNonEmpty([
        placemark.administrativeArea,
        placemark.subAdministrativeArea,
      ]);
      final country = placemark.country?.trim();
      final continent = _continentForPlacemark(
        placemark,
        latitude: latitude,
        longitude: longitude,
      );

      if (city == null &&
          region == null &&
          (country == null || country.isEmpty)) {
        return null;
      }

      return GeoAddress(
        city: city,
        region: region,
        country: (country != null && country.isNotEmpty) ? country : null,
        continent: continent,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _continentForPlacemark(
    Placemark placemark, {
    required double latitude,
    required double longitude,
  }) {
    final fromIso = continentFromIsoCountryCode(placemark.isoCountryCode);
    if (fromIso != null) return fromIso;
    return continentFromCoordinates(latitude, longitude);
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

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
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
