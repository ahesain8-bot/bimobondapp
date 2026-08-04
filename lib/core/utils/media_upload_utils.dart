import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/core/utils/image_compress_utils.dart';
import 'package:bimobondapp/core/utils/video_compress_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';

class MediaUploadUtils {
  MediaUploadUtils._();

  /// Prepared-file futures started ahead of the upload by [prewarm], keyed by
  /// the source file's path.
  ///
  /// Video preparation is a full decode/re-encode, so it costs roughly in
  /// proportion to clip length — a 15s recording took seconds. Run at upload
  /// time that lands entirely on the user's "Post" tap. Started when the
  /// composer opens instead, it overlaps the time the user spends writing a
  /// caption and is usually finished before they ever tap Post.
  ///
  /// Entries are consumed (removed) by [prepareForUpload], so a cached result is
  /// handed out once and a later re-post recomputes rather than reusing a
  /// temp file that [deleteIfTemp] may since have removed.
  static final Map<String, Future<File>> _prepared = {};

  /// Starts preparing [file] now so [prepareForUpload] can return immediately.
  ///
  /// Safe to call repeatedly and safe to never consume: a dropped entry only
  /// leaves a temp file behind, the same as any other abandoned upload.
  /// Failures are swallowed here and rediscovered by [prepareForUpload], which
  /// falls back to preparing the file itself.
  static void prewarm(File file) {
    final key = file.path;
    if (_prepared.containsKey(key)) return;
    final future = _prepare(file);
    _prepared[key] = future;
    // Without this an early failure surfaces as an unhandled async error long
    // before anything awaits the future.
    unawaited(future.catchError((_) => file));
  }

  static void prewarmAll(Iterable<File> files) {
    for (final file in files) {
      prewarm(file);
    }
  }

  /// Prepares images and videos for export/upload. Compresses images and videos
  /// if needed before sending to remote storage.
  ///
  /// Uses the result [prewarm] started earlier when one is available, so the
  /// cost is not paid again at upload time.
  static Future<File> prepareForUpload(File file) async {
    final pending = _prepared.remove(file.path);
    if (pending != null) {
      try {
        final prepared = await pending;
        // A prewarmed temp can be gone by now (temp-dir cleanup, an earlier
        // deleteIfTemp); preparing again is cheaper than uploading nothing.
        if (prepared.path == file.path || await prepared.exists()) {
          return prepared;
        }
      } catch (_) {
        // Fall through and prepare normally.
      }
    }
    return _prepare(file);
  }

  static Future<File> _prepare(File file) async {
    if (VideoThumbnailUtils.isVideoFile(file)) {
      return VideoCompressUtils.compressIfNeeded(file);
    }
    if (ImageCompressUtils.isImageFile(file)) {
      return ImageCompressUtils.compressIfNeeded(file);
    }
    return file;
  }

  static Future<void> deleteIfTemp(File original, File prepared) async {
    if (prepared.path == original.path) return;
    try {
      if (await prepared.exists()) await prepared.delete();
    } catch (_) {}
  }
}
