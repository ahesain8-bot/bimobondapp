import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:camerawesome/camerawesome_plugin.dart';

class CameraFaceDetectionFrame {
  const CameraFaceDetectionFrame({required this.faces, required this.image});

  final List<CameraDetectedFace> faces;
  final AnalysisImage image;
}
