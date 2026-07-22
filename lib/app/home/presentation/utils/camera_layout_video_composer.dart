import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Size;

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';
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

    // Equalize + strip recorder black tails in Kotlin BEFORE compose.
    // Do NOT use VideoSegment.endTime here — pro_video_editor appends a ~120ms
    // transparent flush tail when clips end before their source, which becomes
    // a full-screen black blink on every preview loop.
    final maxMs = await _sharedMaxDurationMs(cellPaths.take(count));
    final normalized = <String>[];
    for (var i = 0; i < count; i++) {
      final path = cellPaths[i];
      if (maxMs == null) {
        normalized.add(path);
        continue;
      }
      final out = await ArCameraBridge.trimVideoTail(
        path,
        maxDurationMs: maxMs,
      );
      normalized.add((out != null && out.isNotEmpty) ? out : path);
    }

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
              video: EditorVideo.file(normalized[i]),
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

      // Safety: drop any residual end flash (orientation preserved in Kotlin).
      final trimmedPath = await ArCameraBridge.trimVideoTail(
        output.path,
        trimMs: 80,
      );
      if (trimmedPath != null && trimmedPath.isNotEmpty) {
        final trimmed = File(trimmedPath);
        if (await trimmed.exists() && await trimmed.length() > 0) {
          return trimmed;
        }
      }
      return output;
    } catch (e, st) {
      debugPrint('Layout video compose failed: $e\n$st');
      rethrow;
    }
  }

  /// Shortest clip duration minus a black-tail epsilon (ms).
  static Future<int?> _sharedMaxDurationMs(Iterable<String> paths) async {
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

      // Drop trailing black frame(s) from recorder (~200ms), never more than
      // 20% of the shortest clip.
      final epsilon = math.min(200, (minMs * 0.2).round());
      final endMs = minMs - epsilon;
      if (endMs < 300) return null;
      return endMs;
    } catch (e) {
      debugPrint('Layout video duration probe failed: $e');
      return null;
    }
  }
}
