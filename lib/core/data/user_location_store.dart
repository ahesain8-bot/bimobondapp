import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's last known coordinates locally.
class UserLocationStore {
  UserLocationStore(this._prefs);

  static const String latitudeKey = 'user_latitude';
  static const String longitudeKey = 'user_longitude';
  static const String updatedAtKey = 'user_location_updated_at';

  final SharedPreferences _prefs;

  double? get latitude {
    if (!_prefs.containsKey(latitudeKey)) return null;
    return _prefs.getDouble(latitudeKey);
  }

  double? get longitude {
    if (!_prefs.containsKey(longitudeKey)) return null;
    return _prefs.getDouble(longitudeKey);
  }

  DateTime? get updatedAt {
    final millis = _prefs.getInt(updatedAtKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  bool get hasLocation => latitude != null && longitude != null;

  Future<void> save({
    required double latitude,
    required double longitude,
  }) async {
    await _prefs.setDouble(latitudeKey, latitude);
    await _prefs.setDouble(longitudeKey, longitude);
    await _prefs.setInt(
      updatedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> clear() async {
    await _prefs.remove(latitudeKey);
    await _prefs.remove(longitudeKey);
    await _prefs.remove(updatedAtKey);
  }
}
