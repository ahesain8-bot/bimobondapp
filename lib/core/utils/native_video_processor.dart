import 'dart:io';

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Native video processing without FFmpeg (MediaCodec / AVFoundation).
class NativeVideoProcessor {
  NativeVideoProcessor._();

  static const _maxVideoFilterSeconds = 60;

  static Future<File?> compressVideo(
    File input, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    if (kIsWeb) return input;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/vid_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final resultPath = await VideoEditorBuilder(videoPath: input.path)
          .compress(resolution: _pickResolution(maxWidth, maxHeight))
          .export(outputPath: outPath);

      if (resultPath == null) return null;

      final output = File(resultPath);
      if (!await output.exists() || await output.length() == 0) return null;

      final originalSize = await input.length();
      final compressedSize = await output.length();
      if (compressedSize >= originalSize) {
        await output.delete();
        return null;
      }
      return output;
    } catch (e, st) {
      debugPrint('Native video compression failed: $e\n$st');
      return null;
    }
  }

  static Future<File?> applyColorMatrix({
    required File input,
    required List<double> matrix,
    Duration? maxDuration,
  }) async {
    if (kIsWeb) return null;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/filter_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final resultPath = await ProVideoEditor.instance.renderVideoToFile(
        outPath,
        VideoRenderData(
          videoSegments: [
            VideoSegment(
              video: EditorVideo.file(input),
              endTime: maxDuration ??
                  const Duration(seconds: _maxVideoFilterSeconds),
            ),
          ],
          outputFormat: VideoOutputFormat.mp4,
          enableAudio: true,
          colorFilters: [ColorFilter(matrix: matrix)],
        ),
      );

      final output = File(resultPath);
      return await output.exists() ? output : null;
    } catch (e, st) {
      debugPrint('Native color-matrix video bake failed: $e\n$st');
      return null;
    }
  }

  static Future<File?> overlayImage({
    required File input,
    required File overlayPng,
  }) async {
    if (kIsWeb) return null;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/effect_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final overlayBytes = await overlayPng.readAsBytes();
      final resultPath = await ProVideoEditor.instance.renderVideoToFile(
        outPath,
        VideoRenderData(
          videoSegments: [VideoSegment(video: EditorVideo.file(input))],
          imageLayers: [
            ImageLayer(
              image: EditorLayerImage.memory(overlayBytes),
            ),
          ],
          outputFormat: VideoOutputFormat.mp4,
          enableAudio: true,
        ),
      );

      final output = File(resultPath);
      return await output.exists() ? output : null;
    } catch (e, st) {
      debugPrint('Native video overlay failed: $e\n$st');
      return null;
    }
  }

  static VideoResolution _pickResolution(int? maxWidth, int? maxHeight) {
    final values = [maxWidth, maxHeight].whereType<int>();
    if (values.isEmpty) return VideoResolution.p720;

    final maxDim = values.reduce((a, b) => a > b ? a : b);
    if (maxDim <= 360) return VideoResolution.p360;
    if (maxDim <= 480) return VideoResolution.p480;
    if (maxDim <= 720) return VideoResolution.p720;
    if (maxDim <= 1080) return VideoResolution.p1080;
    return VideoResolution.p2160;
  }
}
