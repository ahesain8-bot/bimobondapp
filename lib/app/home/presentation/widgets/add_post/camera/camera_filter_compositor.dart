import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

  static const _videoFrameFps = 15;
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

      if (isVideo) {
        final result = await _applyToVideo(input, filter).timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            debugPrint('Camera filter: video bake timed out (${input.path})');
            return input;
          },
        );
        return result ?? input;
      }
      return await _applyToImage(input, filter) ?? input;
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

    final pngData = await filteredImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    filteredImage.dispose();
    if (pngData == null) return null;

    final pngBytes = pngData.buffer.asUint8List(
      pngData.offsetInBytes,
      pngData.lengthInBytes,
    );

    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) return pngBytes;

    final jpg = img.encodeJpg(decoded, quality: 92);
    return jpg.isEmpty ? pngBytes : Uint8List.fromList(jpg);
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

  static Future<File?> _applyToVideo(File file, AwesomeFilter filter) async {
    final tempDir = await getTemporaryDirectory();
    final workId = DateTime.now().millisecondsSinceEpoch;
    final framesDir = Directory('${tempDir.path}/vf_$workId');
    await framesDir.create(recursive: true);

    final framePattern = '${framesDir.path}/frame_%06d.jpg';
    final extractOk = await _runFfmpeg([
      '-i',
      file.path,
      '-t',
      '$_maxVideoFilterSeconds',
      '-vf',
      'fps=$_videoFrameFps',
      '-q:v',
      '3',
      '-y',
      framePattern,
    ]);
    if (!extractOk) {
      await _deleteDir(framesDir);
      return null;
    }

    final frames =
        framesDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.jpg'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    if (frames.isEmpty) {
      await _deleteDir(framesDir);
      return null;
    }

    for (final frame in frames) {
      final bytes = await frame.readAsBytes();
      final filtered = await bakeMatrixFilter(bytes, filter);
      if (filtered != null) {
        await frame.writeAsBytes(filtered);
      }
    }

    final outPath = '${tempDir.path}/filter_$workId.mp4';
    final assembled = await _assembleVideo(
      framePattern: framePattern,
      sourceVideo: file,
      outputPath: outPath,
      fps: _videoFrameFps,
    );

    await _deleteDir(framesDir);
    if (!assembled) return null;

    final outFile = File(outPath);
    return await outFile.exists() ? outFile : null;
  }

  static Future<bool> _assembleVideo({
    required String framePattern,
    required File sourceVideo,
    required String outputPath,
    required int fps,
  }) async {
    final hasAudio = await _hasAudioTrack(sourceVideo);

    if (hasAudio) {
      final withAudio = await _runFfmpeg([
        '-framerate',
        '$fps',
        '-start_number',
        '1',
        '-i',
        framePattern,
        '-i',
        sourceVideo.path,
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-preset',
        'veryfast',
        '-crf',
        '23',
        '-c:a',
        'aac',
        '-b:a',
        '128k',
        '-shortest',
        '-y',
        outputPath,
      ]);
      if (withAudio) return true;
    }

    return _runFfmpeg([
      '-framerate',
      '$fps',
      '-start_number',
      '1',
      '-i',
      framePattern,
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-preset',
      'veryfast',
      '-crf',
      '23',
      '-y',
      outputPath,
    ]);
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

  static Future<void> _deleteDir(Directory dir) async {
    if (!await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }

  static String _imageExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }
}
