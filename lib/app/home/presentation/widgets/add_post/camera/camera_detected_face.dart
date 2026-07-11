import 'package:flutter/material.dart';

/// Facial landmarks used by AR camera effects (matches API / TFLite keys).
enum CameraFaceLandmarkType {
  leftEye,
  rightEye,
  noseBase,
  mouth,
  leftEar,
  rightEar,
}

/// Face geometry in image pixel coordinates.
class CameraDetectedFace {
  const CameraDetectedFace({
    required this.boundingBox,
    required this.landmarks,
  });

  final Rect boundingBox;
  final Map<CameraFaceLandmarkType, Offset> landmarks;

  CameraDetectedFace scaled(double scaleX, double scaleY) {
    Rect scaleRect(Rect rect) {
      return Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );
    }

    return CameraDetectedFace(
      boundingBox: scaleRect(boundingBox),
      landmarks: {
        for (final entry in landmarks.entries)
          entry.key: Offset(entry.value.dx * scaleX, entry.value.dy * scaleY),
      },
    );
  }
}
