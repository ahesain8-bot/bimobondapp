import 'package:bimobondapp/core/data/datasources/user_location_remote_data_source.dart';
import 'package:bimobondapp/core/data/user_location_store.dart';
import 'package:bimobondapp/core/services/device_location_service.dart';
import 'package:bimobondapp/core/utils/geo_place_resolver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Requests location permission, stores coordinates locally, and syncs to backend.
class AppLocationService {
  AppLocationService({
    required UserLocationStore store,
    required UserLocationRemoteDataSource remote,
  }) : _store = store,
       _remote = remote;

  final UserLocationStore _store;
  final UserLocationRemoteDataSource _remote;

  /// Reuses an in-flight ensure so concurrent callers share one request.
  Future<bool>? _ensureInFlight;

  /// When the last ensure finished, used to throttle repeat syncs.
  DateTime? _lastEnsuredAt;

  /// Splash and the home feed both call [ensureViewerLocation] within a few
  /// seconds of each other; without this window each would geocode and PUT
  /// the location again.
  static const _ensureThrottle = Duration(minutes: 5);

  /// Uses cached coordinates when available; otherwise requests GPS once.
  ///
  /// De-duplicated across the app session: concurrent calls share the same
  /// request, and repeat calls within [_ensureThrottle] are skipped so the
  /// geocode + `PUT /users/me/location` only happens once per open.
  Future<bool> ensureViewerLocation() {
    final inFlight = _ensureInFlight;
    if (inFlight != null) return inFlight;

    final last = _lastEnsuredAt;
    if (last != null && DateTime.now().difference(last) < _ensureThrottle) {
      return Future.value(true);
    }

    final future = _ensureViewerLocation();
    _ensureInFlight = future;
    return future.whenComplete(() {
      _lastEnsuredAt = DateTime.now();
      _ensureInFlight = null;
    });
  }

  Future<bool> _ensureViewerLocation() async {
    if (_store.viewerCoordinates != null) {
      await syncStoredLocationToBackend();
      return true;
    }
    return requestAndSaveLocation();
  }

  Future<bool> requestAndSaveLocation() async {
    try {
      final position = await DeviceLocationService.getCurrentPosition();
      if (position == null) return false;

      await _store.save(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await _syncToBackend(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: _validDouble(position.accuracy ?? double.nan),
        altitude: _validDouble(position.altitude ?? double.nan),
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
