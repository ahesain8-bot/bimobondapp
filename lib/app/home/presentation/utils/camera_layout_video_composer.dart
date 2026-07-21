import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Size;

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_layout_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Composes per-cell video clips into one grid video (same geometry as photos).
class CameraLayoutVideoComposer {
  CameraLayoutVideoComposer._();

  static Future<File> compose({
    required CameraLayoutMode mode,
    required List<String> cellPaths,
  }) async {
    const outW = 720.0;
    const outH = 1280.0;
    final fracs = mode.cellFractions;
    if (cellPaths.isEmpty || fracs.isEmpty) {
      throw StateError('layout_video_compose_empty');
    }

    final count = math.min(fracs.length, cellPaths.length);

    // Recorders leave a black frame (and sometimes a short black tail) on the
    // last frame of each clip. Trimming every cell to the SHORTEST clip minus a
    // small epsilon removes that trailing black frame and keeps the grid cells
    // in sync so no cell goes black while the others are still playing.
    final endTime = await _sharedEndTime(cellPaths.take(count));

    final layers = <VideoLayer>[];
    for (var i = 0; i < count; i++) {
      final f = fracs[i];
      final left = f.$1 * outW;
      final top = f.$2 * outH;
      final dw = f.$3 * outW;
      final dh = f.$4 * outH;
      layers.add(
        VideoLayer(
          clips: [
            VideoSegment(
              video: EditorVideo.file(cellPaths[i]),
              endTime: endTime,
              // Keep mic from the first cell only to avoid stacked noise.
              volume: i == 0 ? null : 0,
            ),
          ],
          transform: SegmentTransform(
            offset: Offset(left, top),
            size: Size(dw, dh),
            fit: SegmentFit.cover,
          ),
        ),
      );
    }

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/layout_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final resultPath = await ProVideoEditor.instance.renderVideoToFile(
        outPath,
        VideoRenderData(
          composition: VideoComposition(
            canvasSize: const Size(outW, outH),
            backgroundColor: const Color(0xFF000000),
            layers: layers,
          ),
          outputFormat: VideoOutputFormat.mp4,
          enableAudio: true,
        ),
      );

      final output = File(resultPath);
      if (!await output.exists() || await output.length() == 0) {
        throw StateError('layout_video_compose_failed');
      }
      return output;
    } catch (e, st) {
      debugPrint('Layout video compose failed: $e\n$st');
      rethrow;
    }
  }

  /// Returns the clean end time shared by every cell clip: the shortest clip
  /// duration minus a small black-tail epsilon. Returns null (no trim) if the
  /// durations can't be read or are too short to trim safely.
  static Future<Duration?> _sharedEndTime(Iterable<String> paths) async {
    try {
      var minMs = 1 << 62;
      for (final path in paths) {
        final meta = await ProVideoEditor.instance.getMetadata(
          EditorVideo.file(path),
        );
        final ms = meta.duration.inMilliseconds;
        if (ms <= 0) return null;
        if (ms < minMs) minMs = ms;
      }
      if (minMs == 1 << 62) return null;

      // Drop the trailing black frame(s): ~120ms, but never more than 20% of
      // the shortest clip, and only when the clip is long enough to matter.
      final epsilon = math.min(120, (minMs * 0.2).round());
      final endMs = minMs - epsilon;
      if (endMs < 300) return null;
      return Duration(milliseconds: endMs);
    } catch (e) {
      debugPrint('Layout video end-time probe failed: $e');
      return null;
    }
  }
}
