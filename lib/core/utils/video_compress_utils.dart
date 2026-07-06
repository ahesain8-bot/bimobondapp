import 'dart:io';

import 'package:bimobondapp/core/utils/ffmpeg_kit_binding.dart';
import 'package:bimobondapp/core/utils/ffmpeg_kit_support.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum VideoUploadCodec { h264, h265 }

/// FFmpeg-based video compression for smaller uploads while keeping good quality.
class VideoCompressUtils {
  VideoCompressUtils._();

  static const defaultCrf = 28;
  static const defaultPreset = 'veryfast';
  static const defaultMaxHeight = 1280;
  static const defaultFps = 30;

  static Future<File> compressForUpload(
    File input, {
    VideoUploadCodec codec = VideoUploadCodec.h264,
    int crf = defaultCrf,
    String preset = defaultPreset,
    int? maxWidth,
    int? maxHeight = defaultMaxHeight,
    int? fps = defaultFps,
    String? videoBitrate,
    String? audioBitrate = '128k',
  }) async {
    if (kIsWeb || !await FfmpegKitSupport.isAvailable) return input;
    if (!await input.exists()) return input;

    final originalSize = await input.length();
    if (originalSize <= 0) return input;

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/vid_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final vcodec = switch (codec) {
        VideoUploadCodec.h264 => 'libx264',
        VideoUploadCodec.h265 => 'libx265',
      };

      final parts = <String>[
        '-i',
        _quote(input.path),
        '-vcodec',
        vcodec,
        '-crf',
        '${crf.clamp(18, 35)}',
        '-preset',
        preset,
        if (maxWidth != null || maxHeight != null)
          ...[
            '-vf',
            _scaleFilter(maxWidth: maxWidth, maxHeight: maxHeight),
          ],
        if (fps != null) ...['-r', '$fps'],
        if (videoBitrate != null && videoBitrate.isNotEmpty) ...[
          '-b:v',
          videoBitrate,
        ],
        '-c:a',
        'aac',
        if (audioBitrate != null) ...['-b:a', audioBitrate],
        '-movflags',
        '+faststart',
        '-y',
        _quote(outputPath),
      ];

      final session = await FFmpegKit.execute(parts.join(' '));
      final code = await session.getReturnCode();
      if (!ReturnCode.isSuccess(code)) return input;

      final output = File(outputPath);
      if (!await output.exists()) return input;

      final compressedSize = await output.length();
      if (compressedSize <= 0 || compressedSize >= originalSize) {
        await output.delete();
        return input;
      }
      return output;
    } catch (e) {
      FfmpegKitSupport.markUnavailable();
      debugPrint('Video compression failed: $e');
      return input;
    }
  }

  static String _scaleFilter({int? maxWidth, int? maxHeight}) {
    if (maxWidth != null && maxHeight != null) {
      return 'scale=$maxWidth:$maxHeight:force_original_aspect_ratio=decrease';
    }
    if (maxHeight != null) return 'scale=-2:$maxHeight';
    if (maxWidth != null) return 'scale=$maxWidth:-2';
    return 'scale=iw:ih';
  }

  static String _quote(String value) =>
      '"${value.replaceAll('"', r'\"')}"';
}
