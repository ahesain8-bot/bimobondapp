import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/home/presentation/utils/camera_capture_utils.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_temp_utils.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Bakes the same [AwesomeFilter.preview] color matrix shown in the editor UI.
class CameraFilterCompositor {
  CameraFilterCompositor._();

  static const _maxVideoFilterSeconds = 60;

  static bool isActiveFilter(AwesomeFilter filter) {
    return filter.name != AwesomeFilter.None.name;
  }

  static Future<File> applyIfNeeded({
    required File input,
    required AwesomeFilter filter,
    required bool isVideo,
  }) async {
    if (!isActiveFilter(filter)) return input;

    try {
      if (!await _ensureFileReady(input)) {
        debugPrint('Camera filter: file not ready (${input.path})');
        return input;
      }

      final File? result;
      if (isVideo) {
        result = await _applyToVideo(input, filter).timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            debugPrint('Camera filter: video bake timed out (${input.path})');
            return null;
          },
        );
      } else {
        result = await _applyToImage(input, filter);
      }

      if (result == null) return input;
      return MediaTempUtils.replaceKeepingOutput(input: input, output: result);
    } catch (e, st) {
      debugPrint('Camera filter compositing failed: $e\n$st');
      return input;
    }
  }

  /// Gallery files are already complete; camera captures may still be flushing.
  static Future<bool> _ensureFileReady(File file) async {
    if (!await file.exists()) return false;

    final initialSize = await file.length();
    if (initialSize <= 0) {
      return waitForCaptureFile(file);
    }

    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (await file.length() == initialSize) return true;

    return waitForCaptureFile(file);
  }

  static Future<bool> waitForCaptureFile(File file) async {
    var lastSize = -1;
    var stableReads = 0;

    for (var attempt = 0; attempt < 80; attempt++) {
      if (!await file.exists()) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }

      final size = await file.length();
      if (size > 0 && size == lastSize) {
        stableReads++;
        if (stableReads >= 3) return true;
      } else {
        stableReads = 0;
      }
      lastSize = size;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    return await file.exists() && await file.length() > 0;
  }

  /// Renders [filter.preview] onto image bytes — matches [ColorFiltered] preview.
  static Future<Uint8List?> bakeMatrixFilter(
    Uint8List bytes,
    AwesomeFilter filter,
  ) async {
    if (!isActiveFilter(filter)) return bytes;

    final normalized = CameraCaptureUtils.normalizeImageBytes(bytes);
    final working = normalized ?? bytes;

    final codec = await ui.instantiateImageCodec(working);
    final frame = await codec.getNextFrame();
    final source = frame.image;
    final width = source.width;
    final height = source.height;

    final paint = ui.Paint()..colorFilter = filter.preview;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(source, ui.Offset.zero, paint);
    source.dispose();

    final picture = recorder.endRecording();
    final filteredImage = await picture.toImage(width, height);
    picture.dispose();

    final raw = await filteredImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    filteredImage.dispose();
    if (raw == null) return null;

    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: raw.buffer,
      numChannels: 4,
    );
    final jpg = img.encodeJpg(image, quality: 92);
    return jpg.isEmpty ? null : Uint8List.fromList(jpg);
  }

  static Future<File?> _applyToImage(File file, AwesomeFilter filter) async {
    final bytes = await file.readAsBytes();
    final filtered = await bakeMatrixFilter(bytes, filter);
    if (filtered == null) {
      debugPrint('Camera filter: matrix bake failed (${file.path})');
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final ext = _imageExtension(file.path);
    final outPath =
        '${tempDir.path}/filter_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final outFile = File(outPath);
    await outFile.writeAsBytes(filtered);
    return outFile;
  }

  /// Applies the color matrix using native video processing.
  static Future<File?> _applyToVideo(File file, AwesomeFilter filter) async {
    return NativeVideoProcessor.applyColorMatrix(
      input: file,
      matrix: filter.matrix,
      maxDuration: const Duration(seconds: _maxVideoFilterSeconds),
    );
  }

  static String _imageExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }
}
