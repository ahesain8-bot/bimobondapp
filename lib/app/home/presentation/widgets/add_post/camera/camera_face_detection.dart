import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bimobondapp/app/home/presentation/utils/camera_capture_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart' as fdt;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// On-device face detection using the slim front-camera TFLite model.
class CameraFaceDetection {
  CameraFaceDetection._();

  static fdt.FaceDetector? _liveDetector;
  static fdt.FaceDetector? _liveBackDetector;
  static fdt.FaceDetector? _staticDetector;
  static fdt.FaceDetector? _accurateDetector;

  static Future<fdt.FaceDetector> _live({required bool isFrontCamera}) async {
    if (isFrontCamera) {
      if (_liveDetector != null) return _liveDetector!;
      final detector = fdt.FaceDetector();
      await detector.initialize(model: fdt.FaceDetectionModel.frontCamera);
      _liveDetector = detector;
      return detector;
    }

    if (_liveBackDetector != null) return _liveBackDetector!;
    final detector = fdt.FaceDetector();
    await detector.initialize(model: fdt.FaceDetectionModel.backCamera);
    _liveBackDetector = detector;
    return detector;
  }

  static Future<fdt.FaceDetector> _static() async {
    if (_staticDetector != null) return _staticDetector!;
    final detector = fdt.FaceDetector();
    await detector.initialize(model: fdt.FaceDetectionModel.frontCamera);
    _staticDetector = detector;
    return detector;
  }

  /// Photo-oriented detector — same model, but without selfie horizontal flip.
  static Future<fdt.FaceDetector> _accurate() async {
    if (_accurateDetector != null) return _accurateDetector!;
    final detector = fdt.FaceDetector();
    await detector.initialize(model: fdt.FaceDetectionModel.backCamera);
    _accurateDetector = detector;
    return detector;
  }

  static Future<void> dispose() async {
    _liveDetector?.dispose();
    _liveBackDetector?.dispose();
    _staticDetector?.dispose();
    _accurateDetector?.dispose();
    _liveDetector = null;
    _liveBackDetector = null;
    _staticDetector = null;
    _accurateDetector = null;
  }

  static Future<List<CameraDetectedFace>> detectFromFilepath(
    String path, {
    bool accurate = true,
  }) async {
    final bytes = await File(path).readAsBytes();
    if (accurate) {
      final result = await detectAccurateFromBytes(bytes);
      return result.faces;
    }
    return detectFromBytes(bytes, live: false);
  }

  static Future<List<CameraDetectedFace>> detectFromBytes(
    Uint8List bytes, {
    bool live = false,
    bool isFrontCamera = true,
  }) async {
    final detector = live
        ? await _live(isFrontCamera: isFrontCamera)
        : await _static();
    final result = await detector.detectFaces(
      bytes,
      mode: fdt.FaceDetectionMode.fast,
    );
    return result.faces.map(_convert).toList(growable: false);
  }

  /// Best-effort detection for still photos: EXIF fix, no mirror flip, ROI refine.
  static Future<CameraFaceDetectionResult> detectAccurateFromBytes(
    Uint8List bytes,
  ) async {
    final decoded = _decodeStillImage(bytes);
    if (decoded == null) {
      return CameraFaceDetectionResult(
        faces: const [],
        imageBytes: Uint8List(0),
        imageSize: Size.zero,
      );
    }

    final displayBytes = _encodeDisplayBytes(decoded, sourceBytes: bytes);
    final originalSize = Size(
      decoded.width.toDouble(),
      decoded.height.toDouble(),
    );

    var detectionBytes = displayBytes;
    var detectionSize = originalSize;

    final resizedBytes = _normalizeDetectionSize(decoded);
    if (resizedBytes != null) {
      detectionBytes = resizedBytes;
      final resizedDecoded = img.decodeImage(resizedBytes);
      if (resizedDecoded != null) {
        detectionSize = Size(
          resizedDecoded.width.toDouble(),
          resizedDecoded.height.toDouble(),
        );
      }
    }

    var faces = await _detectPhotoFaces(detectionBytes);
    if (faces.isEmpty && detectionBytes != displayBytes) {
      detectionBytes = displayBytes;
      detectionSize = originalSize;
      faces = await _detectPhotoFaces(detectionBytes);
    }

    if (faces.isEmpty) {
      return CameraFaceDetectionResult(
        faces: const [],
        imageBytes: displayBytes,
        imageSize: originalSize,
      );
    }

    final primary = _pickPrimaryFace(faces);
    final detector = await _accurate();
    final refined = await _refineFace(
      detector: detector,
      bytes: detectionBytes,
      face: primary,
      imageSize: detectionSize,
    );
    faces = [refined ?? primary];

    final scaleX = originalSize.width / detectionSize.width;
    final scaleY = originalSize.height / detectionSize.height;
    if ((scaleX - 1.0).abs() > 0.001 || (scaleY - 1.0).abs() > 0.001) {
      faces = faces.map((face) => face.scaled(scaleX, scaleY)).toList();
    }

    return CameraFaceDetectionResult(
      faces: faces,
      imageBytes: displayBytes,
      imageSize: originalSize,
    );
  }

  static img.Image? _decodeStillImage(Uint8List bytes) {
    final normalized = CameraCaptureUtils.normalizeImageBytes(bytes);
    if (normalized != null) {
      return CameraCaptureUtils.decodeNormalized(normalized);
    }
    return img.decodeImage(bytes);
  }

  static Uint8List _encodeDisplayBytes(
    img.Image decoded, {
    required Uint8List sourceBytes,
  }) {
    if (_isJpeg(sourceBytes)) {
      return Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
    }
    return Uint8List.fromList(img.encodePng(decoded));
  }

  static bool _isJpeg(Uint8List bytes) {
    return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  }

  static Future<List<CameraDetectedFace>> _detectPhotoFaces(
    Uint8List bytes,
  ) async {
    final detector = await _accurate();
    final pipeline = await detector.detectFaces(bytes);
    return pipeline.faces.map(_convert).toList(growable: false);
  }

  static Future<List<CameraDetectedFace>> detectFromAnalysisImage(
    AnalysisImage image, {
    bool isFrontCamera = true,
  }) async {
    try {
      final jpegBytes = await _analysisImageToJpegBytes(image);
      if (jpegBytes == null) return const [];
      return detectFromBytes(
        jpegBytes,
        live: true,
        isFrontCamera: isFrontCamera,
      );
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

  static Uint8List? _normalizeDetectionSize(img.Image decoded) {
    const targetSide = 1280;
    final longest = math.max(decoded.width, decoded.height);
    if ((longest - targetSide).abs() < 24) return null;

    final scale = targetSide / longest;
    final resized = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: longest < targetSide
          ? img.Interpolation.cubic
          : img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodePng(resized));
  }

  static CameraDetectedFace _pickPrimaryFace(List<CameraDetectedFace> faces) {
    return faces.reduce((a, b) {
      final areaA = a.boundingBox.width * a.boundingBox.height;
      final areaB = b.boundingBox.width * b.boundingBox.height;
      return areaA >= areaB ? a : b;
    });
  }

  static Future<CameraDetectedFace?> _refineFace({
    required fdt.FaceDetector detector,
    required Uint8List bytes,
    required CameraDetectedFace face,
    required Size imageSize,
  }) async {
    final w = imageSize.width;
    final h = imageSize.height;
    if (w <= 0 || h <= 0) return null;

    final box = face.boundingBox;
    final roi = fdt.RectF(
      box.left / w,
      box.top / h,
      box.right / w,
      box.bottom / h,
    ).expand(0.45);

    final clamped = fdt.RectF(
      roi.xmin.clamp(0.0, 1.0),
      roi.ymin.clamp(0.0, 1.0),
      roi.xmax.clamp(0.0, 1.0),
      roi.ymax.clamp(0.0, 1.0),
    );

    if (clamped.w <= 0.05 || clamped.h <= 0.05) return null;

    final refined = await detector.detectFaces(bytes, roi: clamped);
    if (refined.faces.isEmpty) return null;

    final best = refined.faces.reduce(
      (a, b) => a.detection.score >= b.detection.score ? a : b,
    );
    return _convert(best);
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
        CameraFaceLandmarkType.mouth: landmark(fdt.FaceIndex.mouth),
        CameraFaceLandmarkType.leftEar: landmark(fdt.FaceIndex.leftEyeTragion),
        CameraFaceLandmarkType.rightEar: landmark(fdt.FaceIndex.rightEyeTragion),
      },
    );
  }
}

class CameraFaceDetectionResult {
  const CameraFaceDetectionResult({
    required this.faces,
    required this.imageBytes,
    required this.imageSize,
  });

  final List<CameraDetectedFace> faces;
  final Uint8List imageBytes;
  final Size imageSize;
}
