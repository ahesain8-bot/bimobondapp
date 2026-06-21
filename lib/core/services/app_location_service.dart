import 'package:bimobondapp/core/data/datasources/user_location_remote_data_source.dart';
import 'package:bimobondapp/core/data/user_location_store.dart';
import 'package:bimobondapp/core/utils/geo_place_resolver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  /// Uses cached coordinates when available; otherwise requests GPS once.
  Future<bool> ensureViewerLocation() async {
    if (_store.viewerCoordinates != null) {
      await syncStoredLocationToBackend();
      return true;
    }
    return requestAndSaveLocation();
  }

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

      await _syncToBackend(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: _validDouble(position.accuracy),
        altitude: _validDouble(position.altitude),
        source: 'APP_OPEN',
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('AppLocationService: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> syncStoredLocationToBackend({String source = 'APP_OPEN'}) async {
    final coords = _store.viewerCoordinates;
    if (coords == null) return;

    await _syncToBackend(
      latitude: coords.latitude,
      longitude: coords.longitude,
      source: source,
    );
  }

  Future<void> _syncToBackend({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    String source = 'APP_OPEN',
  }) async {
    if (FirebaseAuth.instance.currentUser == null) return;

    final address = await GeoPlaceResolver.resolveAddress(
      latitude: latitude,
      longitude: longitude,
    );

    final payload = UserLocationPayload(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      city: address?.city,
      region: address?.region,
      country: address?.country,
      source: source,
    );

    try {
      await _remote.saveLocation(payload);
    } catch (error) {
      debugPrint('AppLocationService sync failed: $error');
    }
  }

  double? _validDouble(double value) {
    if (value.isNaN || value.isInfinite) return null;
    return value;
  }
}
