import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/live_video_quality_preference.dart';
import '../../domain/entities/live_capture_profile.dart';
import '../../domain/repositories/camera_repository.dart';

/// Concrete camera implementation backed by the `camera` plugin.
///
/// Optimized for live-host UX: caches device list, opens at the best 16:9
/// profile the handset actually accepts, and serializes init/dispose so the
/// start-screen ↔ room handoff cannot race.
class CameraRepositoryImpl implements CameraRepository {
  static List<CameraDescription>? _cachedCameras;
  static Future<List<CameraDescription>>? _camerasFuture;
  static Future<void>? _queue;

  /// Runs camera operations one-at-a-time (init/dispose/switch).
  static Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _queue ?? Future<void>.value();
    final gate = Completer<void>();
    _queue = gate.future;
    return previous.catchError((_) {}).then((_) => action()).whenComplete(() {
      if (!gate.isCompleted) gate.complete();
    });
  }

  static Future<List<CameraDescription>> _cameras() {
    if (_cachedCameras != null) {
      return Future.value(_cachedCameras);
    }
    return _camerasFuture ??= availableCameras().then((cameras) {
      _cachedCameras = cameras;
      return cameras;
    }).catchError((Object e, StackTrace st) {
      _camerasFuture = null;
      Error.throwWithStackTrace(e, st);
    });
  }

  @override
  Future<CameraController?> initialize({required bool useFront}) {
    return _serialized(() => _initializeUnlocked(useFront: useFront));
  }

  Future<CameraController?> _initializeUnlocked({required bool useFront}) async {
    try {
      final cameras = await _cameras();
      if (cameras.isEmpty) return null;

      final selectedCamera = useFront
          ? cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => cameras.first,
            )
          : cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => cameras.first,
            );

      // Prefer formats that ML Kit face detection can consume directly.
      final preferredFormat = Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888;

      return _openController(
        selectedCamera,
        preferredFormat,
        LiveVideoQualityPreference.instance.profile,
      );
    } catch (e) {
      debugPrint('Camera init error: $e');
      return null;
    }
  }

  /// Opens [camera] at the best profile it accepts, walking down from
  /// [profile]. A handset that cannot bind 1080p lands on 720p instead of
  /// dropping straight to the old 240p last resort, so the preview stays
  /// sharp everywhere the hardware allows it.
  Future<CameraController?> _openController(
    CameraDescription camera,
    ImageFormatGroup format,
    LiveCaptureProfile profile,
  ) async {
    for (final candidate in profile.fallbacks) {
      final controller = await _tryOpen(camera, format, candidate.preset);
      if (controller != null) return controller;
    }
    // Last resort for hardware that refuses every 16:9 profile — a low
    // preview still beats a black screen on the go-live sheet.
    return _tryOpen(camera, format, ResolutionPreset.low);
  }

  Future<CameraController?> _tryOpen(
    CameraDescription camera,
    ImageFormatGroup format,
    ResolutionPreset preset,
  ) async {
    CameraController? controller;
    try {
      controller = CameraController(
        camera,
        preset,
        enableAudio: false,
        imageFormatGroup: format,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      return controller;
    } catch (e) {
      debugPrint('Camera init with $preset/$format failed: $e');
      await _safeDispose(controller);
      return null;
    }
  }

  @override
  Future<void> dispose(CameraController controller) {
    return _serialized(() => _safeDispose(controller));
  }

  Future<void> _safeDispose(CameraController? controller) async {
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // Ignore stream-stop races during teardown.
    }
    try {
      await controller.dispose();
    } catch (e) {
      debugPrint('Camera dispose error: $e');
    }
  }
}
