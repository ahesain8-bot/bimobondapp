import 'dart:ui';

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:camerawesome/camerawesome_plugin.dart';

class CameraFaceDetectionFrame {
  const CameraFaceDetectionFrame({
    required this.faces,
    required this.image,
    this.detectionSize,
    this.isFrontCamera = false,
  });

  final List<CameraDetectedFace> faces;
  final AnalysisImage image;

  /// Pixel size of the JPEG/buffer that TFLite ran on (cropped analysis frame).
  final Size? detectionSize;

  /// True when the analysis frame came from the front camera (mirrored preview).
  final bool isFrontCamera;
}
