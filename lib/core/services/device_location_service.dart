import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

class DeviceLocationResult {
  const DeviceLocationResult({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
}

/// Reads the device GPS position after permission checks.
class DeviceLocationService {
  DeviceLocationService._();

  static Future<DeviceLocationResult?> getCurrentPosition() async {
    final location = loc.Location();

    var serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return null;
    }

    var permission = await Permission.locationWhenInUse.status;
    if (!permission.isGranted && !permission.isLimited) {
      permission = await Permission.locationWhenInUse.request();
    }
    if (!permission.isGranted && !permission.isLimited) return null;

    var locationPermission = await location.hasPermission();
    if (locationPermission == loc.PermissionStatus.denied) {
      locationPermission = await location.requestPermission();
    }
    if (locationPermission != loc.PermissionStatus.granted &&
        locationPermission != loc.PermissionStatus.grantedLimited) {
      return null;
    }

    final data = await location.getLocation().timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw StateError('Location timeout'),
    );

    final latitude = data.latitude;
    final longitude = data.longitude;
    if (latitude == null || longitude == null) return null;

    return DeviceLocationResult(
      latitude: latitude,
      longitude: longitude,
      accuracy: data.accuracy,
      altitude: data.altitude,
    );
  }
}
