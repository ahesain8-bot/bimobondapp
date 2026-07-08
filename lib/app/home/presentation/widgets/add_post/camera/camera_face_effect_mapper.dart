import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

/// Face geometry mapped into the coordinate space where effects are painted.
class ScreenFace {
  const ScreenFace({
    required this.boundingBox,
    required this.landmarks,
  });

  final Rect boundingBox;
  final Map<CameraFaceLandmarkType, Offset> landmarks;
}

class CameraFaceEffectMapper {
  CameraFaceEffectMapper._();

  static const liveAnalysisWidth = 400;

  /// Maps face coordinates from analysis frames onto the camera preview.
  static List<ScreenFace> mapForLivePreview({
    required List<CameraDetectedFace> faces,
    required AnalysisPreview preview,
    required AnalysisImage image,
  }) {
    return faces
        .map(
          (face) => _mapWithPoint(
            face,
            (point) => preview.convertFromImage(point, image),
          ),
        )
        .toList(growable: false);
  }

  /// Maps file-based detection coords through [fit] into the editor frame.
  static List<ScreenFace> mapForBoxFit({
    required List<CameraDetectedFace> faces,
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
    required List<CameraDetectedFace> faces,
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
    CameraDetectedFace face,
    Offset Function(Offset point) mapPoint,
  ) {
    final box = face.boundingBox;
    final topLeft = mapPoint(box.topLeft);
    final bottomRight = mapPoint(box.bottomRight);

    final landmarks = <CameraFaceLandmarkType, Offset>{};
    for (final entry in face.landmarks.entries) {
      landmarks[entry.key] = mapPoint(entry.value);
    }

    return ScreenFace(
      boundingBox: Rect.fromPoints(topLeft, bottomRight),
      landmarks: landmarks,
    );
  }
}
