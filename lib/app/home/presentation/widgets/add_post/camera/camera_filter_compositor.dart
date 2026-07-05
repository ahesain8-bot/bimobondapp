import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/home/presentation/utils/media_temp_utils.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/return_code.dart';
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

    final codec = await ui.instantiateImageCodec(bytes);
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

  /// Applies the color matrix in one FFmpeg pass — no per-frame JPEG extraction.
  static Future<File?> _applyToVideo(File file, AwesomeFilter filter) async {
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/filter_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final matrixFilter = _colorMatrixVideoFilter(filter.matrix);
    final hasAudio = await _hasAudioTrack(file);

    final args = <String>[
      '-i',
      file.path,
      '-t',
      '$_maxVideoFilterSeconds',
      '-vf',
      matrixFilter,
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-preset',
      'veryfast',
      '-crf',
      '23',
      if (hasAudio) ...['-c:a', 'copy'],
      '-y',
      outPath,
    ];

    final ok = await _runFfmpeg(args);
    if (!ok) return null;

    final outFile = File(outPath);
    return await outFile.exists() ? outFile : null;
  }

  /// Maps Flutter's 4×5 [ColorFilter.matrix] to FFmpeg `geq` (same math as preview).
  static String _colorMatrixVideoFilter(List<double> matrix) {
    String channel(int row) {
      final o = matrix[row + 4];
      final offset = o.abs() < 0.0001 ? '' : '+${_formatCoeff(o)}';
      return "clip(${_formatCoeff(matrix[row])}*r(X,Y)"
          '+${_formatCoeff(matrix[row + 1])}*g(X,Y)'
          '+${_formatCoeff(matrix[row + 2])}*b(X,Y)'
          '+${_formatCoeff(matrix[row + 3])}*a(X,Y)'
          '$offset,0,255)';
    }

    return "geq=r='${channel(0)}':g='${channel(5)}':b='${channel(10)}':"
        "a='${channel(15)}'";
  }

  static String _formatCoeff(double value) {
    if (value == 0) return '0';
    if (value == value.roundToDouble()) return value.round().toString();
    return value
        .toStringAsFixed(6)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  static Future<bool> _hasAudioTrack(File file) async {
    final session = await FFprobeKit.getMediaInformation(file.path);
    final streams = session.getMediaInformation()?.getStreams() ?? const [];
    return streams.any((stream) => stream.getType() == 'audio');
  }

  static Future<bool> _runFfmpeg(List<String> args) async {
    if (await _tryFfmpeg(args)) return true;

    if (args.contains('libx264')) {
      final fallback = [...args];
      fallback[fallback.indexOf('libx264')] = 'mpeg4';
      return _tryFfmpeg(fallback);
    }
    return false;
  }

  static Future<bool> _tryFfmpeg(List<String> args) async {
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) return true;

    final logs = await session.getAllLogsAsString();
    debugPrint('FFmpeg filter failed: $logs');
    return false;
  }

  static String _imageExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }
}
