import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_analysis_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detection.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

export 'camera_analysis_utils.dart';

/// Runs on-device face detection on CamerAwesome analysis frames.
class CameraFaceDetectorService {
  CameraFaceDetectorService({bool isFrontCamera = false})
      : _isFrontCamera = isFrontCamera;

  final _controller = StreamController<CameraFaceDetectionFrame>.broadcast();
  bool _busy = false;
  bool _isFrontCamera;

  /// How much of the previous frame to keep (0 = raw, higher = smoother).
  /// Lower with ML Kit — landmarks are already more stable.
  static const double _smoothKeep = 0.25;

  List<CameraDetectedFace>? _smoothedFaces;

  bool get isFrontCamera => _isFrontCamera;

  set isFrontCamera(bool value) {
    if (_isFrontCamera == value) return;
    _isFrontCamera = value;
    _smoothedFaces = null;
  }

  Stream<CameraFaceDetectionFrame> get stream => _controller.stream;

  Future<void> analyze(AnalysisImage image) async {
    if (_busy || _controller.isClosed) return;
    _busy = true;

    try {
      final result = await CameraFaceDetection.detectLiveFromAnalysisImage(
        image,
        isFrontCamera: _isFrontCamera,
      );
      final smoothed = _smoothFaces(result.faces);
      if (!_controller.isClosed) {
        _controller.add(
          CameraFaceDetectionFrame(
            faces: smoothed,
            image: image,
            detectionSize: result.detectionSize,
            isFrontCamera: _isFrontCamera,
          ),
        );
      }
    } catch (error) {
      debugPrint('Face detection failed: $error');
    } finally {
      _busy = false;
    }
  }

  List<CameraDetectedFace> _smoothFaces(List<CameraDetectedFace> next) {
    if (next.isEmpty) {
      _smoothedFaces = null;
      return next;
    }

    final previous = _smoothedFaces;
    if (previous == null || previous.isEmpty) {
      _smoothedFaces = next;
      return next;
    }

    final count = next.length < previous.length ? next.length : previous.length;
    final out = <CameraDetectedFace>[];
    for (var i = 0; i < count; i++) {
      out.add(_lerpFace(previous[i], next[i], 1.0 - _smoothKeep));
    }
    for (var i = count; i < next.length; i++) {
      out.add(next[i]);
    }
    _smoothedFaces = out;
    return out;
  }

  static CameraDetectedFace _lerpFace(
    CameraDetectedFace from,
    CameraDetectedFace to,
    double t,
  ) {
    final keep = 1.0 - t;
    Rect lerpRect(Rect a, Rect b) {
      return Rect.fromLTRB(
        a.left * keep + b.left * t,
        a.top * keep + b.top * t,
        a.right * keep + b.right * t,
        a.bottom * keep + b.bottom * t,
      );
    }

    Offset lerpOffset(Offset a, Offset b) {
      return Offset(a.dx * keep + b.dx * t, a.dy * keep + b.dy * t);
    }

    final landmarks = <CameraFaceLandmarkType, Offset>{};
    for (final entry in to.landmarks.entries) {
      final prev = from.landmarks[entry.key];
      landmarks[entry.key] =
          prev == null ? entry.value : lerpOffset(prev, entry.value);
    }

    return CameraDetectedFace(
      boundingBox: lerpRect(from.boundingBox, to.boundingBox),
      landmarks: landmarks,
    );
  }

  Future<void> dispose() async {
    await _controller.close();
    await CameraFaceDetection.dispose();
  }
}
