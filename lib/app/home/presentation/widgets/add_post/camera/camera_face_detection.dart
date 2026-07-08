import 'dart:io';
import 'dart:typed_data';

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart' as fdt;
import 'package:flutter/material.dart';

/// On-device face detection using the slim front-camera TFLite model.
class CameraFaceDetection {
  CameraFaceDetection._();

  static fdt.FaceDetector? _liveDetector;
  static fdt.FaceDetector? _staticDetector;

  static Future<fdt.FaceDetector> _live() async {
    if (_liveDetector != null) return _liveDetector!;
    final detector = fdt.FaceDetector();
    await detector.initialize(model: fdt.FaceDetectionModel.frontCamera);
    _liveDetector = detector;
    return detector;
  }

  static Future<fdt.FaceDetector> _static() async {
    if (_staticDetector != null) return _staticDetector!;
    final detector = fdt.FaceDetector();
    await detector.initialize(model: fdt.FaceDetectionModel.frontCamera);
    _staticDetector = detector;
    return detector;
  }

  static Future<void> dispose() async {
    _liveDetector?.dispose();
    _staticDetector?.dispose();
    _liveDetector = null;
    _staticDetector = null;
  }

  static Future<List<CameraDetectedFace>> detectFromFilepath(
    String path, {
    bool accurate = true,
  }) async {
    final bytes = await File(path).readAsBytes();
    return detectFromBytes(bytes, live: !accurate);
  }

  static Future<List<CameraDetectedFace>> detectFromBytes(
    Uint8List bytes, {
    bool live = false,
  }) async {
    final detector = live ? await _live() : await _static();
    // Slim TFLite package only ships the front detector (fast keypoints).
    final result = await detector.detectFaces(
      bytes,
      mode: fdt.FaceDetectionMode.fast,
    );
    return result.faces.map(_convert).toList(growable: false);
  }

  static Future<List<CameraDetectedFace>> detectFromAnalysisImage(
    AnalysisImage image,
  ) async {
    try {
      final jpegBytes = await _analysisImageToJpegBytes(image);
      if (jpegBytes == null) return const [];
      return detectFromBytes(jpegBytes, live: true);
    } catch (e, st) {
      debugPrint('Live face detection failed: $e\n$st');
      return const [];
    }
  }

  static Future<Uint8List?> _analysisImageToJpegBytes(
    AnalysisImage image,
  ) async {
    return image.when<Future<Uint8List?>>(
      jpeg: (frame) async => frame.bytes,
      nv21: (frame) async => (await frame.toJpeg(quality: 80)).bytes,
      bgra8888: (frame) async => (await frame.toJpeg(quality: 80)).bytes,
      yuv420: (frame) async {
        final nv21 = await frame.toNv21();
        return (await nv21.toJpeg(quality: 80)).bytes;
      },
    );
  }

  static CameraDetectedFace _convert(fdt.FaceResult face) {
    final det = face.detection;
    final width = face.originalSize.width;
    final height = face.originalSize.height;
    final bbox = det.bbox;

    Offset landmark(fdt.FaceIndex index) {
      final x = det.keypointsXY[index.index * 2] * width;
      final y = det.keypointsXY[index.index * 2 + 1] * height;
      return Offset(x, y);
    }

    return CameraDetectedFace(
      boundingBox: Rect.fromLTRB(
        bbox.xmin * width,
        bbox.ymin * height,
        bbox.xmax * width,
        bbox.ymax * height,
      ),
      landmarks: {
        CameraFaceLandmarkType.leftEye: landmark(fdt.FaceIndex.leftEye),
        CameraFaceLandmarkType.rightEye: landmark(fdt.FaceIndex.rightEye),
        CameraFaceLandmarkType.noseBase: landmark(fdt.FaceIndex.noseTip),
      },
    );
  }
}
