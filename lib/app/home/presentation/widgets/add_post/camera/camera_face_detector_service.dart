import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_analysis_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detection.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';

export 'camera_analysis_utils.dart';

/// Runs on-device face detection on CamerAwesome analysis frames.
class CameraFaceDetectorService {
  CameraFaceDetectorService({bool isFrontCamera = false})
      : _isFrontCamera = isFrontCamera;

  final _controller = StreamController<CameraFaceDetectionFrame>.broadcast();
  bool _busy = false;
  bool _isFrontCamera;

  bool get isFrontCamera => _isFrontCamera;

  set isFrontCamera(bool value) => _isFrontCamera = value;

  Stream<CameraFaceDetectionFrame> get stream => _controller.stream;

  Future<void> analyze(AnalysisImage image) async {
    if (_busy || _controller.isClosed) return;
    _busy = true;

    try {
      final faces = await CameraFaceDetection.detectFromAnalysisImage(
        image,
        isFrontCamera: _isFrontCamera,
      );
      if (!_controller.isClosed) {
        _controller.add(CameraFaceDetectionFrame(faces: faces, image: image));
      }
    } catch (error) {
      debugPrint('Face detection failed: $error');
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() async {
    await _controller.close();
    await CameraFaceDetection.dispose();
  }
}
