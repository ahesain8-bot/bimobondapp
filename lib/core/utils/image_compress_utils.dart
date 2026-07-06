import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// JPEG/WebP compression for uploads (quality ~80–90%, optional resize).
class ImageCompressUtils {
  ImageCompressUtils._();

  static const defaultQuality = 85;
  static const defaultMaxDimension = 1920;

  static final _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
  };

  static bool isImageFile(File file) {
    final path = file.path.toLowerCase().split('?').first;
    return _imageExtensions.any(path.endsWith);
  }

  static Future<File> compressForUpload(
    File input, {
    int quality = defaultQuality,
    int maxWidth = defaultMaxDimension,
    int maxHeight = defaultMaxDimension,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async {
    if (!isImageFile(input) || kIsWeb) return input;
    if (!await input.exists()) return input;

    final originalSize = await input.length();
    if (originalSize <= 0) return input;

    try {
      final tempDir = await getTemporaryDirectory();
      final ext = format == CompressFormat.webp ? 'webp' : 'jpg';
      final targetPath =
          '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final result = await FlutterImageCompress.compressAndGetFile(
        input.absolute.path,
        targetPath,
        quality: quality.clamp(1, 100),
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: format,
        keepExif: keepExif,
      );

      if (result == null) return input;
      final out = File(result.path);
      if (!await out.exists()) return input;

      final compressedSize = await out.length();
      if (compressedSize <= 0 || compressedSize >= originalSize) {
        await out.delete();
        return input;
      }
      return out;
    } catch (e) {
      debugPrint('Image compression failed: $e');
      return input;
    }
  }
}
