import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceUtility {
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    print('DeviceUtility: Initializing plugins...');
    final deviceInfo = DeviceInfoPlugin();

    print('DeviceUtility: Fetching package info...');
    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
      print('DeviceUtility: Package info fetched: ${packageInfo.version}');
    } catch (e) {
      print('DeviceUtility: Error fetching package info: $e');
    }

    print('DeviceUtility: Fetching FCM token...');
    String? fcmToken;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }
      fcmToken = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
      );
      print('DeviceUtility: FCM Token: $fcmToken');
    } catch (e) {
      print('DeviceUtility: Error fetching FCM token: $e');
    }

    String deviceId = '';
    String deviceType = '';
    String osVersion = '';

    print('DeviceUtility: Identifying platform...');
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
      deviceType = 'android';
      osVersion = androidInfo.version.release;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
      deviceType = 'ios';
      osVersion = iosInfo.systemVersion;
    }

    return {
      "deviceId": deviceId,
      "deviceType": deviceType,
      "fcmToken": fcmToken ?? '',
      "osVersion": osVersion,
      "appVersion": packageInfo?.version ?? '1.0.0',
    };
  }
}
