import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../data/effects/face_detection_service.dart';
import '../../domain/entities/tracked_face.dart';

/// Owns the camera image-stream → face-detection pipeline.
///
/// Face updates intentionally stay outside BLoC to avoid rebuilding the
/// entire Live Room on every processed frame.
class LiveFaceTracker extends ChangeNotifier {
  LiveFaceTracker({FaceDetectionService? service})
      : _service = service ?? FaceDetectionService();

  final FaceDetectionService _service;

  CameraController? _controller;
  bool _enabled = false;
  bool _streaming = false;
  bool _disposed = false;
  TrackedFace? _face;
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  TrackedFace? get face => _face;

  /// Attach/detach the live [CameraController]. Stops streaming on change.
  Future<void> bindController(CameraController? controller) async {
    if (_disposed) return;
    if (identical(_controller, controller)) return;
    await _stopStream();
    _controller = controller;
    _face = null;
    notifyListeners();
    await _syncStream();
  }

  /// Enables detection only while a face-dependent effect is selected.
  Future<void> setEnabled(bool enabled) async {
    if (_disposed || _enabled == enabled) return;
    _enabled = enabled;
    if (!enabled) {
      _face = null;
      notifyListeners();
    }
    await _syncStream();
  }

  Future<void> _syncStream() async {
    if (_disposed) return;
    final controller = _controller;
    final canStream = _enabled &&
        controller != null &&
        controller.value.isInitialized;

    if (canStream && !_streaming) {
      await _startStream(controller);
    } else if (!canStream && _streaming) {
      await _stopStream();
    }
  }

  Future<void> _startStream(CameraController controller) async {
    if (_streaming) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.startImageStream(_onImage);
      _streaming = true;
    } catch (e) {
      debugPrint('LiveFaceTracker startImageStream failed: $e');
      _streaming = false;
    }
  }

  Future<void> _stopStream() async {
    final controller = _controller;
    if (!_streaming && !(controller?.value.isStreamingImages ?? false)) {
      _streaming = false;
      return;
    }
    _streaming = false;
    try {
      if (controller != null && controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (e) {
      debugPrint('LiveFaceTracker stopImageStream failed: $e');
    }
  }

  Future<void> _onImage(CameraImage image) async {
    if (_disposed || !_enabled) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final tracked = await _service.processFrame(
      image: image,
      camera: controller.description,
      deviceOrientation: controller.value.deviceOrientation,
    );

    if (_disposed || !_enabled) return;

    final now = DateTime.now();
    if (tracked == null) {
      if (_face != null &&
          now.difference(_lastEmit) > const Duration(milliseconds: 120)) {
        _face = null;
        _lastEmit = now;
        notifyListeners();
      }
      return;
    }

    _face = tracked;
    if (now.difference(_lastEmit) < const Duration(milliseconds: 33)) {
      return;
    }
    _lastEmit = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Best-effort async cleanup; camera dispose in bloc remains authoritative.
    _stopStream();
    _service.dispose();
    super.dispose();
  }
}
