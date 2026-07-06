import 'dart:io';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressUtils {
  ImageCompressUtils._();

  static bool isImageFile(File file) {
    final path = file.path.toLowerCase().split('?').first;
    return MediaUtils.imageExtensions.any((ext) => path.endsWith(ext));
  }

  /// Compresses images before upload (quality 85, max 1920px).
  static Future<File> compressIfNeeded(
    File file, {
    int quality = 85,
    int maxDimension = 1920,
  }) async {
    if (!isImageFile(file)) return file;

    try {
      final tempDir = await getTemporaryDirectory();
      final lower = file.path.toLowerCase();
      final useWebp = lower.endsWith('.webp');
      final usePng = lower.endsWith('.png');
      final ext = useWebp
          ? 'webp'
          : usePng
          ? 'png'
          : 'jpg';
      final targetPath =
          '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final format = useWebp
          ? CompressFormat.webp
          : usePng
          ? CompressFormat.png
          : CompressFormat.jpeg;

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality.clamp(1, 100),
        minWidth: maxDimension,
        minHeight: maxDimension,
        format: format,
      );

      if (result == null) return file;

      final compressed = File(result.path);
      if (!await compressed.exists()) return file;

      final originalSize = await file.length();
      final compressedSize = await compressed.length();
      if (compressedSize >= originalSize) {
        await compressed.delete();
        return file;
      }

      return compressed;
    } catch (e, st) {
      debugPrint('Image compression failed: $e\n$st');
      return file;
    }
  }
}
