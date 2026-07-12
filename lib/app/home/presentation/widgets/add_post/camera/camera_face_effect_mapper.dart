import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_mlkit_utils.dart';
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

  /// Analysis frame width — higher = better landmarks, slightly more CPU.
  static const liveAnalysisWidth = 480;

  /// Live overlay calibration (analysis FOV vs preview cover crop).
  /// Scale about canvas center, then nudge down/right out of the top-left bias.
  static const double liveScale = 1.22;
  static const Offset liveNudge = Offset(28, 56);

  /// Maps ML Kit faces onto the live preview canvas.
  ///
  /// ML Kit already returns coordinates in the **upright** frame when
  /// [InputImageMetadata.rotation] is set — do not rotate points again.
  ///
  /// Same idea as the effect test screen: [BoxFit.cover], front X-mirror,
  /// then [liveScale] / [liveNudge] so the overlay matches the selfie preview.
  static List<ScreenFace> mapForLivePreview({
    required List<CameraDetectedFace> faces,
    required AnalysisPreview preview,
    required AnalysisImage image,
    Size? detectionSize,
    Size? canvasSize,
    bool mirrorFrontCamera = false,
  }) {
    final destSize = canvasSize ?? preview.previewSize;
    // Upright size matches ML Kit's coordinate space when rotation is set.
    final imageSize = detectionSize ?? image.uprightSize;
    if (imageSize.width <= 0 ||
        imageSize.height <= 0 ||
        destSize.width <= 0 ||
        destSize.height <= 0) {
      return const [];
    }

    var mapped = mapForBoxFit(
      faces: faces,
      imageSize: imageSize,
      canvasSize: destSize,
      fit: BoxFit.cover,
    );

    if (mirrorFrontCamera) {
      mapped = mapped
          .map((face) => _mirrorHorizontal(face, destSize.width))
          .toList(growable: false);
    }

    return mapped
        .map((face) => _calibrateLive(face, destSize))
        .toList(growable: false);
  }

  /// Enlarge about canvas center, then shift down/right.
  static ScreenFace _calibrateLive(ScreenFace face, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);

    Offset adjust(Offset p) {
      final scaled = center + (p - center) * liveScale;
      return scaled + liveNudge;
    }

    final a = adjust(face.boundingBox.topLeft);
    final b = adjust(face.boundingBox.bottomRight);

    return ScreenFace(
      boundingBox: Rect.fromLTRB(
        a.dx < b.dx ? a.dx : b.dx,
        a.dy < b.dy ? a.dy : b.dy,
        a.dx > b.dx ? a.dx : b.dx,
        a.dy > b.dy ? a.dy : b.dy,
      ),
      landmarks: {
        for (final entry in face.landmarks.entries)
          entry.key: adjust(entry.value),
      },
    );
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

  static ScreenFace _mirrorHorizontal(ScreenFace face, double width) {
    Offset mirror(Offset p) => Offset(width - p.dx, p.dy);

    final box = face.boundingBox;
    final left = width - box.right;
    final right = width - box.left;

    return ScreenFace(
      boundingBox: Rect.fromLTRB(left, box.top, right, box.bottom),
      landmarks: {
        for (final entry in face.landmarks.entries)
          entry.key: mirror(entry.value),
      },
    );
  }

  static ScreenFace _mapWithPoint(
    CameraDetectedFace face,
    Offset Function(Offset point) mapPoint,
  ) {
    final box = face.boundingBox;
    final a = mapPoint(box.topLeft);
    final b = mapPoint(box.bottomRight);

    final landmarks = <CameraFaceLandmarkType, Offset>{};
    for (final entry in face.landmarks.entries) {
      landmarks[entry.key] = mapPoint(entry.value);
    }

    return ScreenFace(
      boundingBox: Rect.fromLTRB(
        a.dx < b.dx ? a.dx : b.dx,
        a.dy < b.dy ? a.dy : b.dy,
        a.dx > b.dx ? a.dx : b.dx,
        a.dy > b.dy ? a.dy : b.dy,
      ),
      landmarks: landmarks,
    );
  }
}
