import 'dart:async';

import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/services/feed_video_disk_prefetcher.dart';
import 'package:bimobondapp/core/services/feed_video_prewarmer.dart';
import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/widgets.dart';

/// Caches media for [currentIndex] ±2 so scroll up/down does not reload.
class FeedMediaPreloader {
  FeedMediaPreloader();

  /// Exactly ±2 around the current post.
  static const int lookahead = 2;
  static const int lookbehind = 2;

  final Set<String> _preloadedIds = <String>{};

  void reset() => _preloadedIds.clear();

  void preloadAround(
    BuildContext context,
    List<FeedItemEntity> items,
    int currentIndex,
  ) {
    preloadPostsAround(
      context,
      items.map((e) => e.post).toList(growable: false),
      currentIndex,
      idFor: (i) => items[i].id,
    );
  }

  void preloadPostsAround(
    BuildContext context,
    List<PostEntity> posts,
    int currentIndex, {
    String Function(int index)? idFor,
  }) {
    if (posts.isEmpty || currentIndex < 0 || currentIndex >= posts.length) {
      return;
    }

    final start = (currentIndex - lookbehind).clamp(0, posts.length - 1);
    final end = (currentIndex + lookahead).clamp(0, posts.length - 1);

    final windowIds = <String>{};
    final diskUrlsOrdered = <String>[];
    final warmUrls = <String>{};

    void consider(int index, {required bool preferFirst}) {
      if (index < 0 || index >= posts.length || index == currentIndex) return;
      final post = posts[index];
      if (post.isAuctionable) return;
      final url = _firstSlideVideoUrl(post);
      if (url == null || !AppMediaCacheManager.canDiskCacheVideo(url)) return;
      warmUrls.add(url);
      if (preferFirst) {
        diskUrlsOrdered.remove(url);
        diskUrlsOrdered.insert(0, url);
      } else if (!diskUrlsOrdered.contains(url)) {
        diskUrlsOrdered.add(url);
      }
    }

    // Download priority: ±1 first, then ±2. Include current so park/retain
    // keeps the just-left clip until it falls out of the window.
    final currentUrl = _firstSlideVideoUrl(posts[currentIndex]);
    if (currentUrl != null &&
        AppMediaCacheManager.canDiskCacheVideo(currentUrl)) {
      warmUrls.add(currentUrl);
    }
    consider(currentIndex + 1, preferFirst: true);
    consider(currentIndex - 1, preferFirst: true);
    consider(currentIndex + 2, preferFirst: false);
    consider(currentIndex - 2, preferFirst: false);

    for (var index = start; index <= end; index++) {
      final post = posts[index];
      final id = idFor?.call(index) ?? post.id;
      windowIds.add(id);

      final videoUrl = _firstSlideVideoUrl(post);
      final shouldWarmDecoder =
          index != currentIndex &&
          videoUrl != null &&
          warmUrls.contains(videoUrl);

      if (!_preloadedIds.add(id)) {
        if (shouldWarmDecoder) {
          unawaited(FeedVideoPrewarmer.instance.prewarm(videoUrl));
        }
        continue;
      }

      unawaited(
        _preloadPost(
          context,
          post,
          warmDecoder: shouldWarmDecoder,
        ),
      );
    }

    _preloadedIds.removeWhere((id) => !windowIds.contains(id));

    FeedVideoPrewarmer.instance.retainOnly(warmUrls);
    FeedVideoDiskPrefetcher.instance.setWarmUrls(warmUrls);
    FeedVideoDiskPrefetcher.instance.retainOnly(warmUrls);
    FeedVideoDiskPrefetcher.instance.enqueueAll(diskUrlsOrdered);

    for (final url in diskUrlsOrdered) {
      unawaited(FeedVideoPrewarmer.instance.prewarm(url));
    }
  }

  static const double _avatarSize = 48;

  Future<void> _preloadPost(
    BuildContext context,
    PostEntity post, {
    required bool warmDecoder,
  }) async {
    if (warmDecoder) {
      final url = _firstSlideVideoUrl(post);
      if (url != null) unawaited(FeedVideoPrewarmer.instance.prewarm(url));
    }

    final firstSlide = _firstSlideImageUrl(post);
    if (firstSlide != null && context.mounted) {
      try {
        await precacheSafeNetworkImage(context, firstSlide);
      } catch (_) {}
    }

    final avatar = post.user?.avatarUrl;
    if (avatar != null && avatar.isNotEmpty && context.mounted) {
      try {
        await precacheSafeNetworkImage(
          context,
          avatar,
          width: _avatarSize,
          height: _avatarSize,
        );
      } catch (_) {}
    }
  }

  String? _firstSlideVideoUrl(PostEntity post) {
    return MediaUtils.resolveCacheableFeedVideoUrl(post);
  }

  String? _firstSlideImageUrl(PostEntity post) {
    if (post.isAuctionable) {
      return MediaUtils.resolvePostCoverUrl(post);
    }

    final media = post.media;
    if (media.isNotEmpty) {
      final first = media.first;
      final url = MediaUtils.resolveAbsoluteUrl(first.url);
      final isVideo =
          MediaUtils.isVideo(url, mediaType: first.mediaType) ||
          post.type == 'VIDEO';
      if (!isVideo && url.isNotEmpty) return url;
      return MediaUtils.resolveVideoPosterUrl(post);
    }

    return MediaUtils.resolveVideoPosterUrl(post);
  }
}
