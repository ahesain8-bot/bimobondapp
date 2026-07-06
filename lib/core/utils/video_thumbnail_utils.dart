import 'dart:io';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailUtils {
  VideoThumbnailUtils._();

  static bool isVideoFile(File file) {
    final path = file.path.toLowerCase().split('?').first;
    return MediaUtils.videoExtensions.any((ext) => path.endsWith(ext));
  }

  /// Extracts a JPEG frame from a local [videoFile] and returns a temp file.
  static Future<File?> generateThumbnailFile(
    File videoFile, {
    int timeMs = 0,
    int maxHeight = 720,
    int quality = 85,
  }) async {
    if (!isVideoFile(videoFile)) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: maxHeight,
        quality: quality.clamp(1, 100),
        timeMs: timeMs,
      );
      if (thumbPath == null) return null;
      final thumbFile = File(thumbPath);
      if (!await thumbFile.exists()) return null;
      return thumbFile;
    } catch (e) {
      debugPrint('Video thumbnail generation failed: $e');
      return null;
    }
  }

  /// Extracts a JPEG frame from a local path or network URL.
  static Future<Uint8List?> generateThumbnailBytes(
    String videoSource, {
    int timeMs = 0,
    int maxHeight = 720,
    int quality = 85,
  }) async {
    final source = videoSource.trim();
    if (source.isEmpty) return null;

    try {
      return await VideoThumbnail.thumbnailData(
        video: source,
        imageFormat: ImageFormat.JPEG,
        maxHeight: maxHeight,
        quality: quality.clamp(1, 100),
        timeMs: timeMs,
      );
    } catch (e) {
      debugPrint('Video thumbnail generation failed: $e');
      return null;
    }
  }

  static Future<void> deleteIfExists(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
