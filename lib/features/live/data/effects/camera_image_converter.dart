import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Converts a [CameraImage] into an ML Kit [InputImage].
class CameraImageConverter {
  const CameraImageConverter();

  static final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? toInputImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final rotation = _rotation(
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    // Ideal path: single-plane nv21 / bgra8888.
    if (format != null &&
        ((Platform.isAndroid && format == InputImageFormat.nv21) ||
            (Platform.isIOS && format == InputImageFormat.bgra8888)) &&
        image.planes.length == 1) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    // CameraX fallback: yuv_420_888 → nv21 bytes.
    if (Platform.isAndroid && image.planes.length >= 2) {
      final bytes = _yuv420ToNv21(image);
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    return null;
  }

  InputImageRotation? _rotation({
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    final rotationCompensation = _orientations[deviceOrientation];
    if (rotationCompensation == null) return null;

    late final int compensation;
    if (camera.lensDirection == CameraLensDirection.front) {
      compensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      compensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(compensation);
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes.length > 2 ? image.planes[2] : uPlane;

    final ySize = width * height;
    final uvSize = width * height ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    // Copy Y.
    var dst = 0;
    for (var row = 0; row < height; row++) {
      final start = row * yPlane.bytesPerRow;
      nv21.setRange(dst, dst + width, yPlane.bytes, start);
      dst += width;
    }

    // Interleave VU for NV21.
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    var uvIndex = ySize;
    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < width ~/ 2; col++) {
        final uvOffset = row * uvRowStride + col * uvPixelStride;
        final v = vPlane.bytes.length > uvOffset ? vPlane.bytes[uvOffset] : 0;
        final u = uPlane.bytes.length > uvOffset ? uPlane.bytes[uvOffset] : 0;
        nv21[uvIndex++] = v;
        nv21[uvIndex++] = u;
      }
    }
    return nv21;
  }
}
