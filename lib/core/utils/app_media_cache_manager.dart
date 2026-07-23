import 'dart:io';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for remote media (images, sounds, progressive videos).
class AppMediaCacheManager {
  AppMediaCacheManager._();

  static const _imageCacheKey = 'bimobondMediaCache';
  static const _videoCacheKey = 'bimobondVideoCache';

  static final CacheManager instance = CacheManager(
    Config(
      _imageCacheKey,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 1000,
    ),
  );

  /// Progressive videos only — kept separate so large files don't evict images.
  static final CacheManager videoCache = CacheManager(
    Config(
      _videoCacheKey,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 40,
    ),
  );

  static Future<File> getCachedFile(String url) {
    final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
    return instance.getSingleFile(resolved);
  }

  static bool isHlsUrl(String url) {
    final path = url.toLowerCase().split('?').first;
    return path.endsWith('.m3u8');
  }

  static bool canDiskCacheVideo(String url) {
    if (kIsWeb) return false;
    final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
    if (resolved.isEmpty) return false;
    return !isHlsUrl(resolved);
  }

  static Future<File?> getCachedVideoFile(String url) async {
    if (!canDiskCacheVideo(url)) return null;
    try {
      final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
      final info = await videoCache.getFileFromCache(resolved);
      final file = info?.file;
      if (file == null || !await file.exists()) return null;
      if (await file.length() < 2048) return null;
      return file;
    } catch (_) {}
    return null;
  }

  static Future<void> removeCachedVideoFile(String url) async {
    if (!canDiskCacheVideo(url)) return;
    try {
      final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
      await videoCache.removeFile(resolved);
    } catch (_) {}
  }

  static Future<File?> downloadVideoFile(String url) async {
    if (!canDiskCacheVideo(url)) return null;
    final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
    try {
      final existing = await getCachedVideoFile(resolved);
      if (existing != null) return existing;
      final info = await videoCache.downloadFile(resolved);
      final file = info.file;
      if (!await file.exists() || await file.length() < 2048) {
        await removeCachedVideoFile(resolved);
        return null;
      }
      return file;
    } catch (e) {
      debugPrint('Video download failed for $resolved: $e');
      return null;
    }
  }
}
