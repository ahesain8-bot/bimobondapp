import 'dart:io';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for remote media (videos and large files).
class AppMediaCacheManager {
  AppMediaCacheManager._();

  static const _cacheKey = 'bimobondMediaCache';

  // Images also load through this cache (SafeNetworkImage), so the object
  // limit must comfortably hold feed images + avatars + covers, not just a
  // handful of videos.
  static final CacheManager instance = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 1000,
    ),
  );

  static Future<File> getCachedFile(String url) {
    final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
    return instance.getSingleFile(resolved);
  }
}
