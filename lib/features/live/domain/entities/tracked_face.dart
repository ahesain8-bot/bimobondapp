import 'dart:math' as math;
import 'dart:ui';

/// Face geometry in upright detection-image space (pre-preview / pre-mirror).
class TrackedFace {
  const TrackedFace({
    required this.boundingBox,
    required this.imageSize,
    this.leftEye,
    this.rightEye,
    this.noseBase,
    this.bottomMouth,
    this.leftCheek,
    this.rightCheek,
    this.leftEar,
    this.rightEar,
    this.headEulerAngleX = 0,
    this.headEulerAngleY = 0,
    this.headEulerAngleZ = 0,
  });

  /// Face bounds in the upright (rotation-compensated) detection image.
  final Rect boundingBox;

  /// Upright detection image size matching [boundingBox] coordinates.
  final Size imageSize;

  final Offset? leftEye;
  final Offset? rightEye;
  final Offset? noseBase;
  final Offset? bottomMouth;
  final Offset? leftCheek;
  final Offset? rightCheek;
  final Offset? leftEar;
  final Offset? rightEar;

  /// Pitch (degrees) from ML Kit, when available.
  final double headEulerAngleX;

  /// Yaw (degrees) from ML Kit, when available.
  final double headEulerAngleY;

  /// Roll (degrees) from ML Kit, when available.
  final double headEulerAngleZ;

  Offset get forehead {
    final box = boundingBox;
    return Offset(box.center.dx, box.top + box.height * 0.16);
  }

  Offset get eyesCenter {
    if (leftEye != null && rightEye != null) {
      return Offset(
        (leftEye!.dx + rightEye!.dx) / 2,
        (leftEye!.dy + rightEye!.dy) / 2,
      );
    }
    return Offset(
      boundingBox.center.dx,
      boundingBox.top + boundingBox.height * 0.38,
    );
  }

  double get eyeDistance {
    if (leftEye != null && rightEye != null) {
      return (leftEye! - rightEye!).distance;
    }
    return boundingBox.width * 0.35;
  }

  /// Roll in radians. Prefers ML Kit Z; falls back to eye-line angle.
  double get rollRadians {
    if (headEulerAngleZ.abs() > 0.01) {
      return headEulerAngleZ * math.pi / 180;
    }
    if (leftEye != null && rightEye != null) {
      final delta = rightEye! - leftEye!;
      return math.atan2(delta.dy, delta.dx);
    }
    return 0;
  }

  double get yawRadians => headEulerAngleY * math.pi / 180;

  double get faceScale => boundingBox.width;
}
