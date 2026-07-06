import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_effect_mapper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_mlkit_utils.dart';

export 'camera_mlkit_utils.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Runs ML Kit face detection on CamerAwesome analysis frames.
class CameraFaceDetectorService {
  CameraFaceDetectorService() {
    _detector = FaceDetector(
      options: CameraFaceEffectMapper.liveDetectorOptions(),
    );
  }

  late final FaceDetector _detector;
  final _controller = StreamController<CameraFaceDetectionFrame>.broadcast();
  bool _busy = false;

  Stream<CameraFaceDetectionFrame> get stream => _controller.stream;

  Future<void> analyze(AnalysisImage image) async {
    if (_busy || _controller.isClosed) return;
    _busy = true;

    try {
      final inputImage = image.toInputImage();
      final faces = await _detector.processImage(inputImage);
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
    await _detector.close();
  }
}
