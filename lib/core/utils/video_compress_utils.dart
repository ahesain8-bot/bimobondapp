import 'dart:io';

import 'package:bimobondapp/core/utils/ffmpeg_kit_support.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class VideoCompressUtils {
  VideoCompressUtils._();

  /// H.264 compression: `-vcodec libx264 -crf 28 -preset veryfast`
  static Future<File> compressIfNeeded(
    File file, {
    int crf = 28,
    String preset = 'veryfast',
    int? maxWidth,
    int? maxHeight,
  }) async {
    if (!VideoThumbnailUtils.isVideoFile(file)) return file;
    if (!await FfmpegKitSupport.isAvailable) return file;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/vid_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final args = <String>[
      '-i',
      file.path,
      '-vcodec',
      'libx264',
      '-crf',
      '$crf',
      '-preset',
      preset,
      '-pix_fmt',
      'yuv420p',
      if (maxWidth != null && maxHeight != null)
        ...['-vf', 'scale=$maxWidth:$maxHeight:force_original_aspect_ratio=decrease'],
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-movflags',
      '+faststart',
      '-y',
      outPath,
    ];

    try {
      final session = await FFmpegKit.executeWithArguments(args).timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw StateError('Video compression timed out'),
      );
      final code = await session.getReturnCode();
      if (!ReturnCode.isSuccess(code)) return file;

      final output = File(outPath);
      if (!await output.exists() || await output.length() == 0) return file;

      final originalSize = await file.length();
      final compressedSize = await output.length();
      if (compressedSize >= originalSize) {
        await output.delete();
        return file;
      }

      return output;
    } catch (e, st) {
      FfmpegKitSupport.markUnavailable();
      debugPrint('Video compression failed: $e\n$st');
      return file;
    }
  }
}
