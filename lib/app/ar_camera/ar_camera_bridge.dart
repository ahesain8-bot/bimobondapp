import 'dart:async';

import 'package:flutter/services.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_constants.dart';

class ArCameraBridge {
  ArCameraBridge._();

  static const _channel = MethodChannel(ArCameraConstants.channelName);

  static void Function(String path)? onRecordingAutoStopped;

  /// Registers platform → Dart callbacks (e.g. layout max-duration auto-stop).
  static void installPlatformCallbacks() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onRecordingAutoStopped') {
        final path = call.arguments?.toString();
        if (path != null && path.isNotEmpty) {
          onRecordingAutoStopped?.call(path);
        }
      }
    });
  }

  static void clearPlatformCallbacks() {
    onRecordingAutoStopped = null;
    _channel.setMethodCallHandler(null);
  }

  static Future<void> warmup() async {
    await _channel.invokeMethod<void>('warmup');
  }

  static Future<void> prepareShaderPipeline() async {
    await _channel.invokeMethod<void>('prepareShaderPipeline');
  }

  static void setFilter(
    String filter, {
    double intensity = 1.0,
    String? lutUrl,
    Map<String, dynamic>? beautyParams,
  }) {
    _channel.invokeMethod<void>('setFilter', {
      'filter': filter,
      'intensity': intensity,
      if (lutUrl != null && lutUrl.trim().isNotEmpty) 'lutUrl': lutUrl.trim(),
      if (beautyParams != null && beautyParams.isNotEmpty)
        'beautyParams': beautyParams,
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
    int? maxDurationMs,
  }) async {
    await _channel.invokeMethod<void>('startRecording', {
      if (letterboxTopPx != null) 'letterboxTopPx': letterboxTopPx,
      if (letterboxBottomPx != null) 'letterboxBottomPx': letterboxBottomPx,
      if (maxDurationMs != null && maxDurationMs > 0)
        'maxDurationMs': maxDurationMs,
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

  /// Remux-trims [path]. Prefer [maxDurationMs] (keep first N ms) for layout
  /// cell equalization; otherwise drop [trimMs] from the end.
  /// Always preserves orientation hint (needed for correct cell cover crop).
  static Future<String?> trimVideoTail(
    String path, {
    int trimMs = 120,
    int? maxDurationMs,
  }) async {
    try {
      return await _channel.invokeMethod<String>('trimVideoTail', {
        'path': path,
        'trimMs': trimMs,
        if (maxDurationMs != null) 'maxDurationMs': maxDurationMs,
      });
    } catch (_) {
      return path;
    }
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

  /// Live retouch preview on native camera (Face tab sliders, -1…1 → -100…100).
  static void setRetouchAdjustments({
    double saturation = 0,
    double brightness = 0,
    double contrast = 0,
    double exposure = 0,
    double whiteBalance = 0,
    double highlights = 0,
    double shadows = 0,
    double nose = 0,
  }) {
    int level(double v) => (v * 100).round().clamp(-100, 100);
    _channel.invokeMethod<void>('setRetouchAdjustments', {
      'saturationLevel': level(saturation),
      'brightnessLevel': level(brightness),
      'contrastLevel': level(contrast),
      'exposureLevel': level(exposure),
      'whiteBalanceLevel': level(whiteBalance),
      'highlightsLevel': level(highlights),
      'shadowsLevel': level(shadows),
      'noseLevel': level(nose),
    });
  }

  static void clearRetouchAdjustments() {
    _channel.invokeMethod<void>('clearRetouchAdjustments');
  }

  static Future<void> setZoom(double zoom) async {
    await _channel.invokeMethod<void>('setZoom', {
      'zoom': zoom.clamp(0.0, 1.0),
    });
  }

  static void playCountdownTick({bool isFinal = false}) {
    unawaited(
      _channel
          .invokeMethod<void>('playCountdownTick', {'isFinal': isFinal})
          .catchError((_) {}),
    );
  }

  static Future<String?> applyColorLut({
    required String path,
    required String filter,
    double intensity = 1.0,
    int? maxEdge,
    String? lutUrl,
    Map<String, dynamic>? beautyParams,
  }) async {
    final out = await _channel.invokeMethod<String>('applyColorLut', {
      'path': path,
      'filter': filter,
      'intensity': intensity.clamp(0.0, 1.0),
      if (maxEdge != null) 'maxEdge': maxEdge,
      if (lutUrl != null && lutUrl.trim().isNotEmpty) 'lutUrl': lutUrl.trim(),
      if (beautyParams != null && beautyParams.isNotEmpty)
        'beautyParams': beautyParams,
    });
    return out;
  }

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
    int jawLevel = 0,
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
      'jawLevel': jawLevel.clamp(-100, 100),
      if (maxEdge != null) 'maxEdge': maxEdge,
    });
    return out;
  }
}
