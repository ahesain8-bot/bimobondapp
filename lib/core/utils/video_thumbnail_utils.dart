import 'dart:io';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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
      final outputPath =
          '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final success = await _extractThumbnail(
        videoSource: videoFile.path,
        outputPath: outputPath,
        timeMs: timeMs,
        maxHeight: maxHeight,
        quality: quality,
      );
      if (!success) return null;
      final thumbFile = File(outputPath);
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

    File? tempOutput;
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      tempOutput = File(outputPath);

      final success = await _extractThumbnail(
        videoSource: source,
        outputPath: outputPath,
        timeMs: timeMs,
        maxHeight: maxHeight,
        quality: quality,
      );
      if (!success || !await tempOutput.exists()) return null;
      return await tempOutput.readAsBytes();
    } catch (e) {
      debugPrint('Video thumbnail generation failed: $e');
      return null;
    } finally {
      await deleteIfExists(tempOutput);
    }
  }

  static Future<bool> _extractThumbnail({
    required String videoSource,
    required String outputPath,
    required int timeMs,
    required int maxHeight,
    required int quality,
  }) async {
    final seekSeconds = (timeMs / 1000).toStringAsFixed(3);
    final qValue = _mapQualityToFfmpegQ(quality);
    final parts = <String>[
      '-ss',
      seekSeconds,
      '-i',
      _quoteArg(videoSource),
      '-vframes',
      '1',
      if (maxHeight > 0) ...['-vf', 'scale=-2:$maxHeight'],
      '-q:v',
      '$qValue',
      '-y',
      _quoteArg(outputPath),
    ];
    final command = parts.join(' ');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode);
  }

  static int _mapQualityToFfmpegQ(int quality) {
    final clamped = quality.clamp(1, 100);
    return (((100 - clamped) / 100) * 30 + 1).round().clamp(1, 31);
  }

  static String _quoteArg(String value) =>
      '"${value.replaceAll('"', r'\"')}"';

  static Future<void> deleteIfExists(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
