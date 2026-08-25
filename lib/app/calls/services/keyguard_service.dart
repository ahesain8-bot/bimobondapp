import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class KeyguardService {
  KeyguardService._();
  static final KeyguardService instance = KeyguardService._();

  static const MethodChannel _channel =
      MethodChannel('com.dubai.bimobondapp/keyguard');

  Future<void> setShowWhenLocked(bool show) async {
    try {
      await _channel.invokeMethod('setShowWhenLocked', {'show': show});
    } catch (e) {
      debugPrint('KeyguardService: setShowWhenLocked error: $e');
    }
  }

  Future<void> requestDismissKeyguard() async {
    try {
      await _channel.invokeMethod('requestDismissKeyguard');
    } catch (e) {
      debugPrint('KeyguardService: requestDismissKeyguard error: $e');
    }
  }

  Future<bool> isKeyguardLocked() async {
    try {
      final locked = await _channel.invokeMethod<bool>('isKeyguardLocked');
      return locked ?? false;
    } catch (e) {
      return false;
    }
  }
}
