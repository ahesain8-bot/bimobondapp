import 'package:camera/camera.dart';

/// Represents a physical camera available on the device.
class CameraDevice {
  const CameraDevice({
    required this.description,
    required this.isFront,
  });

  /// The underlying camera description from the camera plugin.
  final CameraDescription description;

  /// Whether this is a front-facing camera.
  final bool isFront;

  factory CameraDevice.fromDescription(CameraDescription description) {
    return CameraDevice(
      description: description,
      isFront: description.lensDirection == CameraLensDirection.front,
    );
  }
}
