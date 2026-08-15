import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';

import '../../domain/entities/tracked_face.dart';

/// Maps ML Kit upright-image coordinates into the same space used by
/// [AspectPreservingCameraPreview] (BoxFit.cover of the portrait preview).
///
/// The Android CameraX plugin already mirrors the **front** camera preview
/// (ImageReader path). The analysis / ML Kit buffer is **not** mirrored, so
/// front-camera overlays must flip X here to stay glued to the face.
///
/// The optional host "video mirror" toggle ([Transform.flip] around preview +
/// overlay) is applied *outside* this mapper and must not be encoded here.
class FaceCoordinateMapper {
  const FaceCoordinateMapper({
    required this.widgetSize,
    required this.detectionImageSize,
    required this.previewPortraitSize,
    required this.mirrorX,
  });

  /// Overlay / preview viewport (usually the full screen).
  final Size widgetSize;

  /// Upright size of the frame ML Kit analyzed ([TrackedFace.imageSize]).
  final Size detectionImageSize;

  /// Portrait size fed to FittedBox in [AspectPreservingCameraPreview]
  /// (`Size(previewSize.height, previewSize.width)`).
  final Size previewPortraitSize;

  /// When true, flip X after preview→widget mapping (front-camera preview).
  final bool mirrorX;

  /// Builds a mapper aligned with the live [CameraController] preview.
  factory FaceCoordinateMapper.forPreview({
    required Size widgetSize,
    required TrackedFace face,
    required CameraController controller,
  }) {
    final preview = controller.value.previewSize;
    final portrait = preview == null
        ? face.imageSize
        : Size(preview.height, preview.width);

    final isFront =
        controller.description.lensDirection == CameraLensDirection.front;

    return FaceCoordinateMapper(
      widgetSize: widgetSize,
      detectionImageSize: face.imageSize,
      previewPortraitSize: portrait,
      mirrorX: isFront,
    );
  }

  Offset mapPoint(Offset detectionPoint) {
    // 1) Detection image → preview portrait buffer (resolutions can differ).
    final toPreview = Offset(
      detectionPoint.dx *
          (previewPortraitSize.width / detectionImageSize.width),
      detectionPoint.dy *
          (previewPortraitSize.height / detectionImageSize.height),
    );

    // 2) Preview portrait → widget via BoxFit.cover (same math as FittedBox).
    final scale = math.max(
      widgetSize.width / previewPortraitSize.width,
      widgetSize.height / previewPortraitSize.height,
    );
    final fitted = Size(
      previewPortraitSize.width * scale,
      previewPortraitSize.height * scale,
    );
    final dx = (widgetSize.width - fitted.width) / 2;
    final dy = (widgetSize.height - fitted.height) / 2;

    final mapped = Offset(
      toPreview.dx * scale + dx,
      toPreview.dy * scale + dy,
    );

    // 3) Match CameraX / platform front-camera preview mirroring.
    if (!mirrorX) return mapped;
    return Offset(widgetSize.width - mapped.dx, mapped.dy);
  }

  Rect mapRect(Rect detectionRect) {
    final a = mapPoint(detectionRect.topLeft);
    final b = mapPoint(detectionRect.bottomRight);
    return Rect.fromPoints(a, b);
  }

  TrackedFace mapFace(TrackedFace face) {
    Offset? mapNullable(Offset? p) => p == null ? null : mapPoint(p);
    return TrackedFace(
      boundingBox: mapRect(face.boundingBox),
      imageSize: widgetSize,
      leftEye: mapNullable(face.leftEye),
      rightEye: mapNullable(face.rightEye),
      noseBase: mapNullable(face.noseBase),
      bottomMouth: mapNullable(face.bottomMouth),
      leftCheek: mapNullable(face.leftCheek),
      rightCheek: mapNullable(face.rightCheek),
      leftEar: mapNullable(face.leftEar),
      rightEar: mapNullable(face.rightEar),
      headEulerAngleX: face.headEulerAngleX,
      // Yaw/roll reverse when the overlay is horizontally mirrored.
      headEulerAngleY:
          mirrorX ? -face.headEulerAngleY : face.headEulerAngleY,
      headEulerAngleZ:
          mirrorX ? -face.headEulerAngleZ : face.headEulerAngleZ,
    );
  }
}
