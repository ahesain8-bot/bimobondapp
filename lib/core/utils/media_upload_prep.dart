import 'dart:io';

import 'package:bimobondapp/core/utils/image_compress_utils.dart';
import 'package:bimobondapp/core/utils/video_compress_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/foundation.dart';

/// Compresses images/videos before API upload to reduce size and upload time.
class MediaUploadPrep {
  MediaUploadPrep._();

  static Future<File> prepareForUpload(File file) async {
    if (!await file.exists()) return file;

    try {
      if (VideoThumbnailUtils.isVideoFile(file)) {
        return VideoCompressUtils.compressForUpload(file);
      }
      if (ImageCompressUtils.isImageFile(file)) {
        return ImageCompressUtils.compressForUpload(file);
      }
    } catch (e) {
      debugPrint('MediaUploadPrep failed, using original: $e');
    }
    return file;
  }

  static Future<File> prepareChatUpload(File file, String messageType) async {
    switch (messageType.toUpperCase()) {
      case 'IMAGE':
      case 'VIDEO':
        return prepareForUpload(file);
      default:
        return file;
    }
  }
}
