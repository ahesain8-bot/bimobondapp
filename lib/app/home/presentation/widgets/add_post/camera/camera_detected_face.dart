import 'package:flutter/material.dart';

/// Facial landmarks used by AR camera effects.
enum CameraFaceLandmarkType {
  leftEye,
  rightEye,
  noseBase,
}

/// Face geometry in image pixel coordinates.
class CameraDetectedFace {
  const CameraDetectedFace({
    required this.boundingBox,
    required this.landmarks,
  });

  final Rect boundingBox;
  final Map<CameraFaceLandmarkType, Offset> landmarks;
}
