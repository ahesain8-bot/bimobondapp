import 'dart:io';

import 'package:bimobondapp/core/utils/image_compress_utils.dart';
import 'package:bimobondapp/core/utils/video_compress_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';

class MediaUploadUtils {
  MediaUploadUtils._();

  /// Compresses images and videos before upload when possible.
  static Future<File> prepareForUpload(File file) async {
    if (VideoThumbnailUtils.isVideoFile(file)) {
      return VideoCompressUtils.compressIfNeeded(file);
    }
    if (ImageCompressUtils.isImageFile(file)) {
      return ImageCompressUtils.compressIfNeeded(file);
    }
    return file;
  }

  static Future<void> deleteIfTemp(File original, File prepared) async {
    if (prepared.path == original.path) return;
    try {
      if (await prepared.exists()) await prepared.delete();
    } catch (_) {}
  }
}
