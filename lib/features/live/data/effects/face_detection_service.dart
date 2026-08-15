import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../domain/entities/tracked_face.dart';
import 'camera_image_converter.dart';

/// On-device face detection backed by Google ML Kit.
class FaceDetectionService {
  FaceDetectionService({
    CameraImageConverter converter = const CameraImageConverter(),
  })  : _converter = converter, // ignore: prefer_initializing_formals
        _detector = FaceDetector(
          options: FaceDetectorOptions(
            enableLandmarks: true,
            enableContours: false,
            enableClassification: false,
            enableTracking: true,
            performanceMode: FaceDetectorMode.fast,
            minFaceSize: 0.15,
          ),
        );

  final CameraImageConverter _converter;
  final FaceDetector _detector;
  bool _busy = false;
  bool _disposed = false;

  Future<TrackedFace?> processFrame({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    if (_disposed || _busy) return null;
    _busy = true;
    try {
      final input = _converter.toInputImage(
        image: image,
        camera: camera,
        deviceOrientation: deviceOrientation,
      );
      if (input == null) return null;

      final faces = await _detector.processImage(input);
      if (faces.isEmpty) return null;

      // Largest face = primary subject for live AR.
      faces.sort(
        (a, b) => (b.boundingBox.width * b.boundingBox.height)
            .compareTo(a.boundingBox.width * a.boundingBox.height),
      );
      final face = faces.first;

      final uprightSize = _uprightSize(
        width: image.width,
        height: image.height,
        rotation: input.metadata?.rotation,
      );

      return TrackedFace(
        boundingBox: face.boundingBox,
        imageSize: uprightSize,
        leftEye: _landmark(face, FaceLandmarkType.leftEye),
        rightEye: _landmark(face, FaceLandmarkType.rightEye),
        noseBase: _landmark(face, FaceLandmarkType.noseBase),
        bottomMouth: _landmark(face, FaceLandmarkType.bottomMouth),
        leftCheek: _landmark(face, FaceLandmarkType.leftCheek),
        rightCheek: _landmark(face, FaceLandmarkType.rightCheek),
        leftEar: _landmark(face, FaceLandmarkType.leftEar),
        rightEar: _landmark(face, FaceLandmarkType.rightEar),
        headEulerAngleX: face.headEulerAngleX ?? 0,
        headEulerAngleY: face.headEulerAngleY ?? 0,
        headEulerAngleZ: face.headEulerAngleZ ?? 0,
      );
    } catch (e, st) {
      debugPrint('FaceDetectionService error: $e\n$st');
      return null;
    } finally {
      _busy = false;
    }
  }

  Offset? _landmark(Face face, FaceLandmarkType type) {
    final landmark = face.landmarks[type];
    if (landmark == null) return null;
    return Offset(
      landmark.position.x.toDouble(),
      landmark.position.y.toDouble(),
    );
  }

  Size _uprightSize({
    required int width,
    required int height,
    required InputImageRotation? rotation,
  }) {
    final rotated = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    if (rotated) {
      return Size(height.toDouble(), width.toDouble());
    }
    return Size(width.toDouble(), height.toDouble());
  }

  Future<void> dispose() async {
    _disposed = true;
    await _detector.close();
  }
}
