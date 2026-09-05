import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/presentation/utils/gift_lottie_cache.dart';
import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

/// Disk + memory warm cache for gift animations received during LIVE.
///
/// Streaming a fresh MP4/Lottie over the network while LiveKit / AR textures
/// are active routinely OOMs Android. Prefetching onto disk and preferring
/// local playback keeps the process alive across rapid gift spam.
class GiftMediaCache {
  GiftMediaCache._();

  static final GiftMediaCache instance = GiftMediaCache._();

  static const int _maxConcurrentDownloads = 2;
  int _inflight = 0;
  final List<String> _queue = <String>[];
  final Set<String> _queuedOrLoading = <String>{};

  /// Warm cache as soon as a gift combo / catalog entry is known.
  void prefetchGiftUrls({
    String? animationUrl,
    String? thumbnailUrl,
  }) {
    final anim = animationUrl?.trim();
    if (anim != null && anim.isNotEmpty) {
      _enqueue(anim);
    }
    final thumb = thumbnailUrl?.trim();
    if (thumb != null &&
        thumb.isNotEmpty &&
        thumb != anim &&
        !GiftLottieCache.looksLikeVideoUrl(thumb)) {
      // Thumbnails are light; only Lottie thumbs need decode warm-up.
      if (GiftLottieCache.looksLikeLottieUrl(thumb)) {
        unawaited(GiftLottieCache.instance.load(thumb));
      }
    }
  }

  /// Prefetch media fields from a hydrated socket gift map.
  void prefetchFromGiftMap(Map<String, dynamic>? gift) {
    if (gift == null) return;
    prefetchGiftUrls(
      animationUrl: (gift['animationUrl'] ?? gift['animation_url'])?.toString(),
      thumbnailUrl: (gift['thumbnailUrl'] ??
              gift['thumbnail_url'] ??
              gift['imageUrl'])
          ?.toString(),
    );
  }

  /// Prefetch a slice of the catalog (medium/large first) when it loads.
  void prefetchCatalog(Iterable<GiftEntity> gifts, {int limit = 12}) {
    final prioritized = gifts.toList(growable: false)
      ..sort((a, b) => _sizeRank(b.size).compareTo(_sizeRank(a.size)));
    var started = 0;
    for (final gift in prioritized) {
      if (started >= limit) break;
      if (gift.isAudioGift) continue;
      final url = gift.animationUrl?.trim();
      if (url == null || url.isEmpty) continue;
      _enqueue(url);
      started++;
    }
  }

  /// Local file for a gift video when already on disk (or after a short wait).
  Future<File?> resolveVideoFile(
    String url, {
    Duration downloadBudget = const Duration(seconds: 4),
  }) async {
    final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
    if (resolved.isEmpty) return null;

    final existing = await AppMediaCacheManager.getCachedVideoFile(resolved);
    if (existing != null) return existing;

    // Kick a download and wait briefly — long enough for small gifts, short
    // enough that LARGE occasion MP4s still fall back to network play.
    _enqueue(resolved);
    try {
      return await AppMediaCacheManager.downloadVideoFile(resolved)
          .timeout(downloadBudget, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  void _enqueue(String url) {
    final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
    if (resolved.isEmpty) return;
    if (!_queuedOrLoading.add(resolved)) return;
    _queue.add(resolved);
    _pump();
  }

  void _pump() {
    while (_inflight < _maxConcurrentDownloads && _queue.isNotEmpty) {
      final url = _queue.removeAt(0);
      _inflight++;
      unawaited(() async {
        try {
          if (GiftLottieCache.looksLikeVideoUrl(url)) {
            await AppMediaCacheManager.downloadVideoFile(url);
          } else if (GiftLottieCache.looksLikeLottieUrl(url)) {
            // Decode into memory and pin bytes on disk for cold restarts.
            await GiftLottieCache.instance.load(url);
            try {
              await AppMediaCacheManager.instance.downloadFile(url);
            } catch (_) {}
          } else {
            try {
              await AppMediaCacheManager.instance.downloadFile(url);
            } catch (_) {}
          }
        } finally {
          _inflight--;
          _queuedOrLoading.remove(url);
          _pump();
        }
      }());
    }
  }

  static int _sizeRank(GiftCatalogSize size) {
    switch (size) {
      case GiftCatalogSize.large:
        return 3;
      case GiftCatalogSize.medium:
        return 2;
      case GiftCatalogSize.small:
        return 1;
    }
  }
}
