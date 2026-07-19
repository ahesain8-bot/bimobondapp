import 'dart:io';

import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads a remote sound track to a local file so it can be muxed into
/// exported media by the native video processor.
///
/// The file is first pulled through [AppMediaCacheManager] (disk-cached so the
/// same track isn't re-downloaded), then copied into the temp directory with a
/// real audio extension. A concrete extension keeps the native muxer's media
/// extractor happy on both Android and iOS.
class SoundLocalFile {
  SoundLocalFile._();

  static Future<File?> resolve(String audioUrl) async {
    final url = audioUrl.trim();
    if (url.isEmpty) return null;

    try {
      final cached = await AppMediaCacheManager.getCachedFile(url);
      if (!await cached.exists() || await cached.length() == 0) return null;

      final ext = _extensionFor(url);
      final tempDir = await getTemporaryDirectory();
      final out = File(
        '${tempDir.path}/sound_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await cached.copy(out.path);
      return out;
    } catch (e, st) {
      debugPrint('Sound download failed: $e\n$st');
      return null;
    }
  }

  static String _extensionFor(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.mp3';
    final ext = path.substring(dot).toLowerCase();
    const known = {'.mp3', '.m4a', '.aac', '.wav', '.ogg', '.opus', '.flac'};
    return known.contains(ext) ? ext : '.mp3';
  }
}
