import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/live_beauty_preset.dart';

/// Talks to the native beauty shader that runs on the published LiveKit track.
///
/// The Flutter effect layer paints over the host's own preview only, so nothing
/// it draws ever reaches a viewer. This bridge instead installs a frame
/// processor on the WebRTC track LiveKit encodes, which is the one place a
/// change is visible on both sides of the broadcast.
///
/// Both mobile platforms hook the same extension point under different names —
/// `LocalVideoTrack.ExternalVideoFrameProcessing` on Android,
/// `ExternalVideoProcessingDelegate` on iOS. The two shaders are not identical:
/// Android gates smoothing by a YCbCr skin probability and can lift the eyes,
/// while iOS applies an edge-preserving Core Image chain to the whole frame and
/// ignores [LiveBeautyPreset.eyes], which needs landmarks it does not run.
/// Every method is a no-op on other platforms so callers need no guard.
class LiveBeautyBridge {
  const LiveBeautyBridge._();

  static const _channel = MethodChannel('com.dubai.bimobondapp/live_beauty');

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static String? _attachedTrackId;

  /// WebRTC id of the track the processor is installed on, if any.
  static String? get attachedTrackId => _attachedTrackId;

  /// Installs the processor on [trackId] — the WebRTC id of the published
  /// camera track, i.e. `localVideoTrack.mediaStreamTrack.id`.
  ///
  /// Safe to call repeatedly: a flip publishes a new track, and native hands
  /// the processor over rather than stacking two of them.
  static Future<bool> attach(String? trackId) async {
    if (!isSupported || trackId == null || trackId.isEmpty) return false;
    try {
      final ok =
          await _channel.invokeMethod<bool>('attach', {'trackId': trackId}) ??
          false;
      _attachedTrackId = ok ? trackId : null;
      return ok;
    } catch (e) {
      debugPrint('LiveBeautyBridge.attach failed: $e');
      _attachedTrackId = null;
      return false;
    }
  }

  static Future<void> detach() async {
    if (!isSupported) return;
    _attachedTrackId = null;
    try {
      await _channel.invokeMethod<void>('detach');
    } catch (e) {
      debugPrint('LiveBeautyBridge.detach failed: $e');
    }
  }

  /// Pushes [preset] at [intensity] (0…1) to the shader.
  static Future<void> apply(
    LiveBeautyPreset preset, {
    double intensity = 1.0,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setBeauty', {
        'smooth': preset.smooth,
        'brighten': preset.brighten,
        'tone': preset.tone,
        'sharpen': preset.sharpen,
        'eyes': preset.eyes,
        'intensity': intensity.clamp(0.0, 1.0),
        'enabled': preset.isActive,
      });
    } catch (e) {
      debugPrint('LiveBeautyBridge.apply failed: $e');
    }
  }

  static Future<void> clear() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('clearBeauty');
    } catch (e) {
      debugPrint('LiveBeautyBridge.clear failed: $e');
    }
  }
}
