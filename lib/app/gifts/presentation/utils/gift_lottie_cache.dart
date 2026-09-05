import 'dart:async';

import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:lottie/lottie.dart';

/// In-memory preload cache for gift Lottie animations (faster send/replay).
///
/// Supports classic `.json` Lottie and `.lottie` (dotLottie zip) archives.
/// Prefers disk bytes from [AppMediaCacheManager] so live gift spam does not
/// re-download and re-decode the same composition until OOM.
class GiftLottieCache {
  GiftLottieCache._() {
    // Keep memory modest — compositions are large and live already holds
    // LiveKit / AR textures. Disk cache covers cold reloads.
    Lottie.cache.maximumSize = 24;
  }

  static final GiftLottieCache instance = GiftLottieCache._();

  final Map<String, Future<LottieComposition?>> _loads = {};

  static bool looksLikeDotLottieUrl(String url) {
    final lower = url.toLowerCase().split('?').first.trim();
    return lower.endsWith('.lottie');
  }

  static bool looksLikeLottieUrl(String url) {
    final lower = url.toLowerCase().split('?').first.trim();
    if (lower.isEmpty) return false;
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return false;
    }
    // Only real Lottie payloads — `/gifts/` / `animation` alone pulled in MP4
    // posters and burned memory during live gift spam.
    return lower.endsWith('.json') ||
        lower.endsWith('.lottie') ||
        lower.contains('lottie');
  }

  static bool looksLikeVideoUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  /// Decodes `.lottie` zip packages (and gzip `.tgs`); returns null for raw JSON
  /// so [LottieComposition.fromBytes] can parse it normally.
  static Future<LottieComposition?> giftDecoder(List<int> bytes) async {
    if (bytes.length < 2) return null;

    // PK zip → `.lottie` / dotLottie
    if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return LottieComposition.decodeZip(
        bytes,
        filePicker: (files) {
          // Prefer real animation JSON inside the .lottie archive.
          for (final file in files) {
            final name = file.name.replaceAll('\\', '/');
            if (name.startsWith('animations/') && name.endsWith('.json')) {
              return file;
            }
          }
          for (final file in files) {
            final name = file.name.replaceAll('\\', '/').toLowerCase();
            if (name.endsWith('.json') && !name.endsWith('manifest.json')) {
              return file;
            }
          }
          return null;
        },
      );
    }

    // gzip → Telegram stickers / compressed Lottie
    if (bytes[0] == 31 && bytes[1] == 139) {
      return LottieComposition.decodeGZip(bytes);
    }

    return null;
  }

  Future<LottieComposition?> load(String url) {
    final resolved = MediaUtils.resolveAbsoluteUrl(url).trim();
    if (resolved.isEmpty) return Future<LottieComposition?>.value(null);

    return _loads.putIfAbsent(resolved, () async {
      try {
        final fromDisk = await _loadFromDisk(resolved);
        if (fromDisk != null) return fromDisk;

        // Always use giftDecoder so `.lottie` archives pick the real animation
        // JSON (not manifest.json). Plain `.json` still works via fallback.
        final composition = await NetworkLottie(
          resolved,
          backgroundLoading: true,
          decoder: giftDecoder,
        ).load();
        // Pin bytes on disk for the next receive without another network hit.
        unawaited(AppMediaCacheManager.instance.downloadFile(resolved));
        return composition;
      } catch (_) {
        _loads.remove(resolved);
        return null;
      }
    });
  }

  Future<LottieComposition?> _loadFromDisk(String resolved) async {
    try {
      final cached =
          await AppMediaCacheManager.instance.getFileFromCache(resolved);
      final file = cached?.file;
      if (file == null || !await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final decoded = await giftDecoder(bytes);
      if (decoded != null) return decoded;
      return await LottieComposition.fromBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Warm cache when the gift catalog / sheet opens.
  ///
  /// Caps how many URLs are kicked off at once so opening the sheet mid-live
  /// does not decode dozens of compositions on the UI isolate.
  void prefetch(Iterable<String?> urls, {int limit = 8}) {
    var started = 0;
    for (final url in urls) {
      if (started >= limit) break;
      final value = url?.trim();
      if (value == null || value.isEmpty) continue;
      if (!looksLikeLottieUrl(value)) continue;
      _evictIfNeeded();
      unawaited(load(value));
      started++;
    }
  }

  static const int _maxTrackedLoads = 24;

  void _evictIfNeeded() {
    if (_loads.length < _maxTrackedLoads) return;
    final overflow = _loads.length - (_maxTrackedLoads ~/ 2);
    final keys = _loads.keys.take(overflow).toList(growable: false);
    for (final key in keys) {
      _loads.remove(key);
    }
  }
}
