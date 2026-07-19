import 'dart:async';

import 'package:flutter/services.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_constants.dart';

class ArCameraBridge {
  ArCameraBridge._();

  static const _channel = MethodChannel(ArCameraConstants.channelName);

  static Future<void> warmup() async {
    await _channel.invokeMethod<void>('warmup');
  }

  static Future<void> prepareShaderPipeline() async {
    await _channel.invokeMethod<void>('prepareShaderPipeline');
  }

  static void setFilter(String filter, {double intensity = 1.0}) {
    _channel.invokeMethod<void>('setFilter', {
      'filter': filter,
      'intensity': intensity,
    });
  }

  static void setFilterIntensity(double intensity) {
    _channel.invokeMethod<void>('setFilterIntensity', {
      'intensity': intensity.clamp(0.0, 1.0),
    });
  }

  static Future<String?> takePhoto({
    int? letterboxTopPx,
    int? letterboxBottomPx,
  }) async {
    final path = await _channel
        .invokeMethod<String>('takePhoto', {
          if (letterboxTopPx != null) 'letterboxTopPx': letterboxTopPx,
          if (letterboxBottomPx != null) 'letterboxBottomPx': letterboxBottomPx,
        })
        .timeout(const Duration(seconds: 10));
    return path;
  }

  static Future<void> startRecording({
    int? letterboxTopPx,
    int? letterboxBottomPx,
  }) async {
    await _channel.invokeMethod<void>('startRecording', {
      if (letterboxTopPx != null) 'letterboxTopPx': letterboxTopPx,
      if (letterboxBottomPx != null) 'letterboxBottomPx': letterboxBottomPx,
    });
  }

  static Future<String?> stopRecording() async {
    final path = await _channel.invokeMethod<String>('stopRecording');
    return path;
  }

  static Future<String?> mergeVideoSegments(List<String> paths) async {
    if (paths.isEmpty) return null;
    if (paths.length == 1) return paths.first;
    final path = await _channel.invokeMethod<String>('mergeVideoSegments', {
      'paths': paths,
    });
    return path;
  }

  static Future<bool> flipCamera() async {
    final isFront = await _channel.invokeMethod<bool>('flipCamera');
    return isFront ?? true;
  }

  static Future<bool> toggleTorch() async {
    final enabled = await _channel.invokeMethod<bool>('toggleTorch');
    return enabled ?? false;
  }

  static Future<void> setPreviewLetterbox({
    required int topPx,
    required int bottomPx,
  }) async {
    await _channel.invokeMethod<void>('setPreviewLetterbox', {
      'topPx': topPx,
      'bottomPx': bottomPx,
    });
  }

  static Future<void> setZoom(double zoom) async {
    await _channel.invokeMethod<void>('setZoom', {
      'zoom': zoom.clamp(0.0, 1.0),
    });
  }

  /// Plays a native countdown beep (TikTok-style). A short tick each second and
  /// a distinct double-beep on the last second ([isFinal]). Native so it plays
  /// on the media stream regardless of the system touch-sound setting.
  /// Fire-and-forget; errors (e.g. no handler on non-Android) are ignored.
  static void playCountdownTick({bool isFinal = false}) {
    unawaited(
      _channel
          .invokeMethod<void>('playCountdownTick', {'isFinal': isFinal})
          .catchError((_) {}),
    );
  }

  /// Native OpenCV tone/color adjustments (Android).
  /// All levels are -100…100 (0 = original).
  static Future<String?> applyBeauty({
    required String path,
    int saturationLevel = 0,
    int brightnessLevel = 0,
    int contrastLevel = 0,
    int exposureLevel = 0,
    int whiteBalanceLevel = 0,
    int highlightsLevel = 0,
    int shadowsLevel = 0,
    int noseLevel = 0,
    int? maxEdge,
  }) async {
    final out = await _channel.invokeMethod<String>('applyBeauty', {
      'path': path,
      'saturationLevel': saturationLevel.clamp(-100, 100),
      'brightnessLevel': brightnessLevel.clamp(-100, 100),
      'contrastLevel': contrastLevel.clamp(-100, 100),
      'exposureLevel': exposureLevel.clamp(-100, 100),
      'whiteBalanceLevel': whiteBalanceLevel.clamp(-100, 100),
      'highlightsLevel': highlightsLevel.clamp(-100, 100),
      'shadowsLevel': shadowsLevel.clamp(-100, 100),
      'noseLevel': noseLevel.clamp(-100, 100),
      if (maxEdge != null) 'maxEdge': maxEdge,
    });
    return out;
  }
}
