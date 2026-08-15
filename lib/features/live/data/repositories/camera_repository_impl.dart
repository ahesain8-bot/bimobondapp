import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/repositories/camera_repository.dart';

/// Concrete camera implementation backed by the `camera` plugin.
///
/// Optimized for live-host UX: caches device list, prefers a faster preset,
/// and serializes init/dispose so start-screen ↔ room handoff cannot race.
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

      // `medium` opens much faster than `high` on mid-range Android devices;
      // still enough for host preview + face effects.
      return _openController(
        selectedCamera,
        preferredFormat,
        ResolutionPreset.medium,
      );
    } catch (e) {
      debugPrint('Camera init error: $e');
      return null;
    }
  }

  Future<CameraController?> _openController(
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
      if (preset != ResolutionPreset.low) {
        return _openController(camera, format, ResolutionPreset.low);
      }
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
