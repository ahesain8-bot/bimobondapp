import 'dart:io';

import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/foundation.dart';

class VideoCompressUtils {
  VideoCompressUtils._();

  static Future<File> compressIfNeeded(
    File file, {
    int crf = 28,
    String preset = 'veryfast',
    int? maxWidth,
    int? maxHeight,
  }) async {
    if (!VideoThumbnailUtils.isVideoFile(file)) return file;
    if (kIsWeb) return file;

    try {
      final compressed = await NativeVideoProcessor.compressVideo(
        file,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
      return compressed ?? file;
    } catch (e, st) {
      debugPrint('Video compression failed: $e\n$st');
      return file;
    }
  }
}
