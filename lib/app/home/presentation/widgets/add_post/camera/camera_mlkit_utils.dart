import 'dart:typed_data';
import 'dart:ui';

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Converts CamerAwesome analysis frames into ML Kit [InputImage]s.
extension CameraMlKitUtils on AnalysisImage {
  /// Builds an [InputImage], copying bytes so native buffers can be released.
  InputImage? toInputImage() {
    if (this is Nv21Image) {
      final image = this as Nv21Image;
      return InputImage.fromBytes(
        bytes: Uint8List.fromList(image.bytes),
        metadata: InputImageMetadata(
          size: image.size,
          rotation: inputImageRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    if (this is Bgra8888Image) {
      final image = this as Bgra8888Image;
      return InputImage.fromBytes(
        bytes: Uint8List.fromList(image.bytes),
        metadata: InputImageMetadata(
          size: image.size,
          rotation: inputImageRotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    return null;
  }

  InputImageRotation get inputImageRotation =>
      InputImageRotation.values.byName(rotation.name);

  /// Pixel size of the frame after applying [rotation] (upright display size).
  Size get uprightSize {
    return switch (rotation) {
      InputAnalysisImageRotation.rotation90deg ||
      InputAnalysisImageRotation.rotation270deg =>
        Size(size.height, size.width),
      _ => size,
    };
  }
}
