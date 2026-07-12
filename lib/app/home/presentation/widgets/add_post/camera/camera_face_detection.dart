import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bimobondapp/app/home/presentation/utils/camera_capture_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_mlkit_utils.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart' as fdt;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// On-device face detection.
///
/// Live camera frames use **Google ML Kit** (accurate landmarks + rotation).
/// Still photos use ML Kit when possible, with TFLite as a fallback.
class CameraFaceDetection {
  CameraFaceDetection._();

  static FaceDetector? _mlKitLive;
  static FaceDetector? _mlKitStill;
  static fdt.FaceDetector? _tfliteFallback;

  static FaceDetectorOptions get _liveOptions => FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: false,
        enableClassification: false,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.12,
      );

  static FaceDetectorOptions get _stillOptions => FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: false,
        enableClassification: false,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.08,
      );

  static Future<FaceDetector> _liveMlKit() async {
    _mlKitLive ??= FaceDetector(options: _liveOptions);
    return _mlKitLive!;
  }

  static Future<FaceDetector> _stillMlKit() async {
    _mlKitStill ??= FaceDetector(options: _stillOptions);
    return _mlKitStill!;
  }

  static Future<fdt.FaceDetector> _tflite() async {
    if (_tfliteFallback != null) return _tfliteFallback!;
    final detector = fdt.FaceDetector();
    await detector.initialize(model: fdt.FaceDetectionModel.backCamera);
    _tfliteFallback = detector;
    return detector;
  }

  static Future<void> dispose() async {
    await _mlKitLive?.close();
    await _mlKitStill?.close();
    _mlKitLive = null;
    _mlKitStill = null;
    _tfliteFallback?.dispose();
    _tfliteFallback = null;
  }

  static Future<List<CameraDetectedFace>> detectFromFilepath(
    String path, {
    bool accurate = true,
  }) async {
    try {
      final detector = await _stillMlKit();
      final faces = await detector.processImage(InputImage.fromFilePath(path));
      final converted = faces.map(_convertMlKit).toList(growable: false);
      if (converted.isNotEmpty) return converted;
    } catch (e, st) {
      debugPrint('ML Kit still detection failed, TFLite fallback: $e\n$st');
    }

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
    try {
      final faces = await _detectMlKitFromJpegBytes(bytes);
      if (faces.isNotEmpty) return faces;
    } catch (e, st) {
      debugPrint('ML Kit bytes detection failed, TFLite fallback: $e\n$st');
    }

    final detector = await _tflite();
    final result = await detector.detectFaces(
      bytes,
      mode: fdt.FaceDetectionMode.fast,
    );
    return result.faces.map(_convertTflite).toList(growable: false);
  }

  /// Best-effort detection for still photos: EXIF fix + ML Kit / TFLite refine.
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

    try {
      final faces = await _detectMlKitFromJpegBytes(displayBytes);
      if (faces.isNotEmpty) {
        return CameraFaceDetectionResult(
          faces: faces,
          imageBytes: displayBytes,
          imageSize: originalSize,
        );
      }
    } catch (e, st) {
      debugPrint('ML Kit accurate detection failed: $e\n$st');
    }

    // TFLite fallback with optional resize.
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

    final detector = await _tflite();
    var pipeline = await detector.detectFaces(detectionBytes);
    var faces = pipeline.faces.map(_convertTflite).toList(growable: false);
    if (faces.isEmpty && detectionBytes != displayBytes) {
      pipeline = await detector.detectFaces(displayBytes);
      faces = pipeline.faces.map(_convertTflite).toList(growable: false);
      detectionSize = originalSize;
    }

    if (faces.isEmpty) {
      return CameraFaceDetectionResult(
        faces: const [],
        imageBytes: displayBytes,
        imageSize: originalSize,
      );
    }

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

  /// Live detection via ML Kit on the **native** NV21/BGRA buffer.
  ///
  /// Avoids CamerAwesome `toJpeg` — its Android Rect uses width/height as
  /// right/bottom, which often encodes only a top-left slice (landmarks stuck
  /// in the corner). Coordinates stay in analysis-buffer space; the mapper
  /// rotates them upright for [BoxFit.cover].
  static Future<CameraLiveFaceDetectionResult> detectLiveFromAnalysisImage(
    AnalysisImage image, {
    bool isFrontCamera = true,
  }) async {
    try {
      final inputImage = await _analysisToInputImage(image);
      if (inputImage == null) {
        return const CameraLiveFaceDetectionResult(
          faces: [],
          detectionSize: Size.zero,
        );
      }

      final detector = await _liveMlKit();
      final faces = await detector.processImage(inputImage);
      return CameraLiveFaceDetectionResult(
        faces: faces.map(_convertMlKit).toList(growable: false),
        detectionSize: image.uprightSize,
      );
    } catch (e, st) {
      debugPrint('Live ML Kit face detection failed: $e\n$st');
      return const CameraLiveFaceDetectionResult(
        faces: [],
        detectionSize: Size.zero,
      );
    }
  }

  static Future<InputImage?> _analysisToInputImage(AnalysisImage image) async {
    final direct = image.toInputImage();
    if (direct != null) return direct;

    final nv21 = await image.when<Future<Nv21Image?>>(
      yuv420: (frame) => frame.toNv21(),
      nv21: (frame) async => frame,
      bgra8888: (_) async => null,
      jpeg: (_) async => null,
    );
    return nv21?.toInputImage();
  }

  static Future<List<CameraDetectedFace>> detectFromAnalysisImage(
    AnalysisImage image, {
    bool isFrontCamera = true,
  }) async {
    final result = await detectLiveFromAnalysisImage(
      image,
      isFrontCamera: isFrontCamera,
    );
    return result.faces;
  }

  static Future<List<CameraDetectedFace>> _detectMlKitFromJpegBytes(
    Uint8List bytes, {
    bool live = false,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/face_detect_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    try {
      await file.writeAsBytes(bytes, flush: true);
      final detector = live ? await _liveMlKit() : await _stillMlKit();
      final faces =
          await detector.processImage(InputImage.fromFilePath(file.path));
      return faces.map(_convertMlKit).toList(growable: false);
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
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

  static CameraDetectedFace _convertMlKit(Face face) {
    Offset? landmark(FaceLandmarkType type) {
      final lm = face.landmarks[type];
      if (lm == null) return null;
      return Offset(lm.position.x.toDouble(), lm.position.y.toDouble());
    }

    Offset? mouth() {
      final bottom = landmark(FaceLandmarkType.bottomMouth);
      if (bottom != null) return bottom;
      final left = landmark(FaceLandmarkType.leftMouth);
      final right = landmark(FaceLandmarkType.rightMouth);
      if (left != null && right != null) {
        return Offset((left.dx + right.dx) / 2, (left.dy + right.dy) / 2);
      }
      return left ?? right;
    }

    final landmarks = <CameraFaceLandmarkType, Offset>{};
    final leftEye = landmark(FaceLandmarkType.leftEye);
    final rightEye = landmark(FaceLandmarkType.rightEye);
    final nose = landmark(FaceLandmarkType.noseBase);
    final mouthPoint = mouth();
    final leftEar = landmark(FaceLandmarkType.leftEar);
    final rightEar = landmark(FaceLandmarkType.rightEar);

    if (leftEye != null) landmarks[CameraFaceLandmarkType.leftEye] = leftEye;
    if (rightEye != null) landmarks[CameraFaceLandmarkType.rightEye] = rightEye;
    if (nose != null) landmarks[CameraFaceLandmarkType.noseBase] = nose;
    if (mouthPoint != null) landmarks[CameraFaceLandmarkType.mouth] = mouthPoint;
    if (leftEar != null) landmarks[CameraFaceLandmarkType.leftEar] = leftEar;
    if (rightEar != null) landmarks[CameraFaceLandmarkType.rightEar] = rightEar;

    // If ears are missing, estimate from eyes + face width.
    final box = face.boundingBox;
    if (leftEar == null && leftEye != null) {
      landmarks[CameraFaceLandmarkType.leftEar] = Offset(
        box.left + box.width * 0.05,
        leftEye.dy,
      );
    }
    if (rightEar == null && rightEye != null) {
      landmarks[CameraFaceLandmarkType.rightEar] = Offset(
        box.right - box.width * 0.05,
        rightEye.dy,
      );
    }

    return CameraDetectedFace(
      boundingBox: box,
      landmarks: landmarks,
    );
  }

  static CameraDetectedFace _convertTflite(fdt.FaceResult face) {
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

class CameraLiveFaceDetectionResult {
  const CameraLiveFaceDetectionResult({
    required this.faces,
    required this.detectionSize,
  });

  final List<CameraDetectedFace> faces;
  final Size detectionSize;
}
