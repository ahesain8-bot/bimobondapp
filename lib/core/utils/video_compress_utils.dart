import 'dart:io';
import 'dart:math' as math;

import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/foundation.dart';

class VideoCompressUtils {
  VideoCompressUtils._();

  /// Shortest side (px) a clip may have and still be uploaded untouched.
  ///
  /// Camera recordings land at 850x1918 — a 850px short side — so they pass
  /// this and skip compression entirely. Genuinely oversized imports (4K
  /// gallery footage and the like) are still transcoded down.
  static const int _maxPassthroughShortSide = 1080;

  /// Size ceiling for skipping compression, as a backstop against a very long
  /// clip that is modest in resolution but huge on disk.
  static const int _maxPassthroughBytes = 150 * 1024 * 1024;

  static Future<File> compressIfNeeded(
    File file, {
    int crf = 28,
    String preset = 'veryfast',
    int? maxWidth,
    int? maxHeight,
  }) async {
    if (!VideoThumbnailUtils.isVideoFile(file)) return file;
    if (kIsWeb) return file;

    // Upload already-reasonable video as-is.
    //
    // Compression here is a full decode + re-encode, which on an already
    // encoded clip is pure generation loss: the source is lossy, so the second
    // pass discards detail it can never recover, and it was additionally
    // scaling the short side down to 720. Camera recordings arrive from our own
    // encoder already sized and bitrated for upload, so running them through
    // this was costing visible quality — and seconds of wall time proportional
    // to clip length — to produce a worse file. Only oversized media, which is
    // what this step actually exists for, is transcoded now.
    //
    // An explicit maxWidth/maxHeight means the caller genuinely wants a
    // specific size, so that path always transcodes.
    if (maxWidth == null && maxHeight == null) {
      if (await _isAlreadyUploadReady(file)) return file;
    }

    try {
      final compressed = await NativeVideoProcessor.compressVideo(
        file,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
      return compressed ?? file;
    } catch (e, st) {
      debugPrint('Video compression failed: $e\n$st');
      return file;
    }
  }

  static Future<bool> _isAlreadyUploadReady(File file) async {
    try {
      final size = await NativeVideoProcessor.videoResolution(file);
      if (size == null || size.width <= 0 || size.height <= 0) return false;
      final shortSide = math.min(size.width, size.height);
      if (shortSide > _maxPassthroughShortSide) return false;
      return await file.length() <= _maxPassthroughBytes;
    } catch (_) {
      // Unknown resolution — fall back to compressing, the previous behaviour.
      return false;
    }
  }
}
