import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Face geometry mapped into the coordinate space where effects are painted.
class ScreenFace {
  const ScreenFace({
    required this.boundingBox,
    required this.landmarks,
  });

  final Rect boundingBox;
  final Map<FaceLandmarkType, Offset> landmarks;
}

class CameraFaceEffectMapper {
  CameraFaceEffectMapper._();

  static const liveAnalysisWidth = 400;

  static FaceDetectorOptions liveDetectorOptions() {
    return FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.12,
    );
  }

  static FaceDetectorOptions staticDetectorOptions() {
    return FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.08,
    );
  }

  /// Maps ML Kit face coordinates from analysis frames onto the camera preview.
  static List<ScreenFace> mapForLivePreview({
    required List<Face> faces,
    required AnalysisPreview preview,
    required AnalysisImage image,
  }) {
    return faces.map((face) => _mapWithPoint(
          face,
          (point) => preview.convertFromImage(point, image),
        )).toList(growable: false);
  }

  /// Maps file-based detection coords through [fit] into the editor frame.
  static List<ScreenFace> mapForBoxFit({
    required List<Face> faces,
    required Size imageSize,
    required Size canvasSize,
    BoxFit fit = BoxFit.cover,
  }) {
    final fitted = applyBoxFit(fit, imageSize, canvasSize);
    final dest = fitted.destination;
    final scale = dest.width / imageSize.width;
    final offset = Offset(
      (canvasSize.width - dest.width) / 2,
      (canvasSize.height - dest.height) / 2,
    );

    return faces
        .map(
          (face) => _mapWithPoint(face, (point) {
            return Offset(
              point.dx * scale + offset.dx,
              point.dy * scale + offset.dy,
            );
          }),
        )
        .toList(growable: false);
  }

  /// Maps file-based detection coords through [BoxFit.cover] into the editor frame.
  static List<ScreenFace> mapForCoverFit({
    required List<Face> faces,
    required Size imageSize,
    required Size canvasSize,
  }) {
    return mapForBoxFit(
      faces: faces,
      imageSize: imageSize,
      canvasSize: canvasSize,
      fit: BoxFit.cover,
    );
  }

  static ScreenFace _mapWithPoint(
    Face face,
    Offset Function(Offset point) mapPoint,
  ) {
    final box = face.boundingBox;
    final topLeft = mapPoint(Offset(box.left, box.top));
    final bottomRight = mapPoint(Offset(box.right, box.bottom));

    final landmarks = <FaceLandmarkType, Offset>{};
    for (final entry in face.landmarks.entries) {
      final landmark = entry.value;
      if (landmark == null) continue;
      landmarks[entry.key] = mapPoint(
        Offset(
          landmark.position.x.toDouble(),
          landmark.position.y.toDouble(),
        ),
      );
    }

    return ScreenFace(
      boundingBox: Rect.fromPoints(topLeft, bottomRight),
      landmarks: landmarks,
    );
  }
}
