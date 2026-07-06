import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Normalizes camera captures (EXIF orientation only — no reframing).
class CameraCaptureUtils {
  CameraCaptureUtils._();

  static const cameraPreviewAspectRatio = 16 / 9;

  /// Bakes EXIF orientation into pixels so preview matches the saved file.
  static Future<File> normalizeCapturedImage(File file) async {
    final bytes = await file.readAsBytes();
    final normalized = normalizeImageBytes(bytes);
    if (normalized == null) return file;

    final tempDir = await getTemporaryDirectory();
    final out = File(
      '${tempDir.path}/norm_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(normalized);
    return out;
  }

  static Uint8List? normalizeImageBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final image = img.bakeOrientation(decoded);
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  /// Decodes image bytes with EXIF orientation applied — for compositors.
  static img.Image? decodeNormalized(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return img.bakeOrientation(decoded);
  }

  static Uint8List encodeJpg(img.Image image, {int quality = 92}) {
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
}
