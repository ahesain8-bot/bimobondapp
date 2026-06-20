import 'package:bimobondapp/core/data/datasources/user_location_remote_data_source.dart';
import 'package:bimobondapp/core/data/user_location_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Requests location permission, stores coordinates locally, and syncs to backend.
class AppLocationService {
  AppLocationService({
    required UserLocationStore store,
    required UserLocationRemoteDataSource remote,
  }) : _store = store,
       _remote = remote;

  final UserLocationStore _store;
  final UserLocationRemoteDataSource _remote;

  Future<bool> requestAndSaveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      await _store.save(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await _syncToBackend(position);
      return true;
    } catch (error, stackTrace) {
      debugPrint('AppLocationService: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> _syncToBackend(Position position) async {
    if (FirebaseAuth.instance.currentUser == null) return;

    final place = await _resolvePlace(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    final payload = UserLocationPayload(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: _validDouble(position.accuracy),
      altitude: _validDouble(position.altitude),
      city: place?.city,
      region: place?.region,
      country: place?.country,
      source: 'APP_OPEN',
    );

    try {
      await _remote.saveLocation(payload);
    } catch (error) {
      debugPrint('AppLocationService sync failed: $error');
    }
  }

  Future<_ResolvedPlace?> _resolvePlace({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final placemark = placemarks.first;
      return _ResolvedPlace(
        city: _firstNonEmpty([
          placemark.locality,
          placemark.subAdministrativeArea,
          placemark.subLocality,
        ]),
        region: _firstNonEmpty([
          placemark.administrativeArea,
          placemark.subAdministrativeArea,
        ]),
        country: placemark.country,
      );
    } catch (error) {
      debugPrint('AppLocationService geocoding failed: $error');
      return null;
    }
  }

  double? _validDouble(double value) {
    if (value.isNaN || value.isInfinite) return null;
    return value;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

class _ResolvedPlace {
  const _ResolvedPlace({this.city, this.region, this.country});

  final String? city;
  final String? region;
  final String? country;
}
