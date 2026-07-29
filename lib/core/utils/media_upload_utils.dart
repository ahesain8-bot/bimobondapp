import 'dart:io';

import 'package:bimobondapp/core/utils/image_compress_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';

class MediaUploadUtils {
  MediaUploadUtils._();

  /// Images are compressed for upload. Videos are already encoded by the
  /// camera/editor pipeline at their final resolution and bitrate, so upload
  /// the exact file. Recompressing here used the compressor's default 720p
  /// preset and visibly reduced post quality.
  static Future<File> prepareForUpload(File file) async {
    if (VideoThumbnailUtils.isVideoFile(file)) {
      return file;
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
