import 'dart:async';

import 'package:flutter/services.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_constants.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/ar_camera/effect_definition.dart';

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

  /// Selects an effect on the native camera.
  ///
  /// Screen overlays are looked up here rather than at the call site so the
  /// animation source always travels with the id: native no longer keeps its
  /// own hardcoded overlay list, so an id alone means nothing to it — it needs
  /// either the remote animation URL or a bundled asset name to play.
  static void setFilter(String filter, {double intensity = 1.0}) {
    final overlay = ArFilterCatalog.overlayById(filter);

    // Mobile Rendering Decision Tree: Does video object/videoId exist & is360 == true?
    final is360Video = filter == 'static_360_test' || (overlay != null && overlay.is360);
    final String? video360Url = is360Video
        ? (overlay?.video?.url ??
            (filter == 'static_360_test'
                ? 'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
                : null))
        : null;

    _channel.invokeMethod<void>('setFilter', {
      'filter': filter,
      'intensity': intensity,
      'overlayUrl': overlay?.animationUrl,
      'overlayAsset': overlay?.bundledAsset,
      'overlayLoop': overlay?.loop ?? true,
      'overlayMediaType': overlay?.isVideo == true ? 'video' : 'lottie',
      'is360': is360Video,
      'video360Url': video360Url,
      'projection': overlay?.video?.projection.name.toUpperCase() ?? 'EQUIRECTANGULAR',
      'stereoMode': overlay?.video?.stereoMode.name.toUpperCase() ?? 'MONO',
    });
  }

  /// Warms overlay caches (Lottie compositions + MP4 files) so the first tap
  /// on one doesn't pay a download. Safe to call repeatedly; native skips any
  /// composition already cached.
  static Future<void> prefetchOverlays() async {
    final overlays = ArFilterCatalog.overlayCatalog.overlays;
    final lottieUrls = <String>[];
    final videoUrls = <String>[];
    for (final overlay in overlays) {
      final url = overlay.animationUrl;
      if (url == null || url.isEmpty) continue;
      if (overlay.isVideo) {
        videoUrls.add(url);
      } else {
        lottieUrls.add(url);
      }
    }
    // Bundled entries too: when the endpoint is unreachable the catalog is the
    // offline fallback, and those animations still benefit from being parsed
    // ahead of the first tap.
    final assets = [
      for (final overlay in overlays)
        if ((overlay.bundledAsset ?? '').isNotEmpty) overlay.bundledAsset!,
    ];
    if (lottieUrls.isEmpty && videoUrls.isEmpty && assets.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('prefetchOverlays', {
        'urls': lottieUrls,
        'videoUrls': videoUrls,
        'assets': assets,
      });
    } catch (_) {
      // Prefetch is an optimisation — a failure just means a slower first tap.
    }
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

  /// Stops the native camera pipeline (camera stream, GL view and any
  /// screen-overlay Lottie animation) while the camera screen is still mounted
  /// but hidden behind another route.
  ///
  /// A Flutter route push does not pause the host Activity, so the native side
  /// otherwise keeps rendering at full cost behind the editor and competes with
  /// video playback there. Pair every call with [resumePreview].
  static Future<void> suspendPreview() async {
    try {
      await _channel.invokeMethod<void>('suspendPreview');
    } catch (_) {
      // Camera view may already be disposed — nothing to suspend.
    }
  }

  /// Restarts what [suspendPreview] stopped.
  static Future<void> resumePreview() async {
    try {
      await _channel.invokeMethod<void>('resumePreview');
    } catch (_) {
      // Camera view may already be disposed — nothing to resume.
    }
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
    double shape = 0,
    double eyes = 0,
    double tooth = 0,
    double mouth = 0,
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
      'shapeLevel': level(shape),
      'eyesLevel': level(eyes),
      'toothLevel': level(tooth),
      'mouthLevel': level(mouth),
    });
  }

  static void clearRetouchAdjustments() {
    _channel.invokeMethod<void>('clearRetouchAdjustments');
  }

  /// Named beauty filter (Soft Glow, Pure, Rosy, Clean, ...) — TikTok-style
  /// preset applied on top of the live camera baseline. All 0..1 except
  /// [lipTint] (hex color) and [intensity] (overall preset strength, 0..1).
  static void setBeautyFilter({
    required double smooth,
    required double whiten,
    required double brighten,
    required double blush,
    required String lipTint,
    required double lipStrength,
    double intensity = 1.0,
  }) {
    _channel.invokeMethod<void>('setBeautyFilter', {
      'smooth': smooth.clamp(0.0, 1.0),
      'whiten': whiten.clamp(0.0, 1.0),
      'brighten': brighten.clamp(0.0, 1.0),
      'blush': blush.clamp(0.0, 1.0),
      'lipTint': lipTint,
      'lipStrength': lipStrength.clamp(0.0, 1.0),
      'intensity': intensity.clamp(0.0, 1.0),
    });
  }

  static void clearBeautyFilter() {
    _channel.invokeMethod<void>('clearBeautyFilter');
  }

  /// Retouch panel Off/On — light face smooth / scar cleanup only.
  /// [strength] is the Smooth slider 0..1 (defaults to auto when null / On).
  static void setMagicEnabled(bool enabled, {double? strength}) {
    _channel.invokeMethod<void>('setMagicEnabled', {
      'enabled': enabled,
      if (strength != null) 'strength': strength.clamp(0.0, 1.0),
    });
  }

  /// Retouch Smooth slider while Magic is On (0..1).
  static void setMagicStrength(double strength) {
    _channel.invokeMethod<void>('setMagicStrength', {
      'strength': strength.clamp(0.0, 1.0),
    });
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

  /// Initializes native GPU EffectEngine.
  static Future<void> initializeEffectEngine() async {
    await _channel.invokeMethod<void>('initializeEffectEngine');
  }

  /// Configures live overlay effect definition on native EffectEngine.
  static Future<void> setOverlayEffect(EffectDefinition effect) async {
    await _channel.invokeMethod<void>('setOverlayEffect', effect.toMap());
  }

  /// Removes current overlay effect from native EffectEngine.
  static Future<void> removeOverlayEffect() async {
    await _channel.invokeMethod<void>('removeOverlayEffect');
  }

  /// Updates overlay position using normalized 0.0..1.0 coordinates.
  static Future<void> setOverlayPosition(double x, double y) async {
    await _channel.invokeMethod<void>('setOverlayPosition', {
      'positionX': x.clamp(0.0, 1.0),
      'positionY': y.clamp(0.0, 1.0),
    });
  }

  /// Updates overlay scale factor.
  static Future<void> setOverlayScale(double scale) async {
    await _channel.invokeMethod<void>('setOverlayScale', {
      'scale': scale.clamp(0.1, 5.0),
    });
  }

  /// Updates overlay opacity (0.0..1.0).
  static Future<void> setOverlayOpacity(double opacity) async {
    await _channel.invokeMethod<void>('setOverlayOpacity', {
      'opacity': opacity.clamp(0.0, 1.0),
    });
  }

  /// Toggles overlay playback loop mode.
  static Future<void> setOverlayLoop(bool loop) async {
    await _channel.invokeMethod<void>('setOverlayLoop', {'loop': loop});
  }
}
