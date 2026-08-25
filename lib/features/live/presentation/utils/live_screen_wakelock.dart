import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while a live session is visible.
class LiveScreenWakelock {
  LiveScreenWakelock._();

  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
