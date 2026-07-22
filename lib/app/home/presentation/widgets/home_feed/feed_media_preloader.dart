import 'dart:async';

import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/services/feed_video_prewarmer.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/widgets.dart';

/// Warms caches for nearby feed/profile posts so scrolling feels instant.
///
/// Window: [currentIndex - lookbehind, currentIndex + lookahead] (excl. current
/// for video warm — current is already playing). Images/avatars for the whole
/// window are precached; videos are pre-initialized via [FeedVideoPrewarmer].
class FeedMediaPreloader {
  FeedMediaPreloader();

  /// Posts ahead of the current index to preload when scrolling down.
  static const int lookahead = 2;

  /// Posts behind the current index to keep warm when scrolling back up.
  static const int lookbehind = 2;

  final Set<String> _preloadedIds = <String>{};

  /// Forget which posts were preloaded (e.g. after a feed refresh).
  void reset() => _preloadedIds.clear();

  /// Preloads media for feed items around [currentIndex] (±2).
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

  /// Preloads media for a flat [PostEntity] list (profile viewer).
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

    final keepVideoUrls = <String>{};
    final windowIds = <String>{};

    for (var index = start; index <= end; index++) {
      final post = posts[index];
      final id = idFor?.call(index) ?? post.id;
      windowIds.add(id);

      final videoUrl = _firstSlideVideoUrl(post);
      if (videoUrl != null) keepVideoUrls.add(videoUrl);

      // Always refresh video keep-set; skip duplicate image work via id set.
      if (!_preloadedIds.add(id)) {
        // Still ensure video is warm (may have been evicted).
        if (videoUrl != null && index != currentIndex) {
          unawaited(FeedVideoPrewarmer.instance.prewarm(videoUrl));
        }
        continue;
      }

      unawaited(_preloadPost(context, post, warmVideo: index != currentIndex));
    }

    // Drop tracked ids outside the window so far scrolls can re-warm later.
    _preloadedIds.removeWhere((id) => !windowIds.contains(id));
    FeedVideoPrewarmer.instance.retainOnly(keepVideoUrls);
  }

  /// Feed post avatar renders at radius 24 (48px); precaching at the same
  /// size reuses the exact decoded image instead of decoding twice.
  static const double _avatarSize = 48;

  Future<void> _preloadPost(
    BuildContext context,
    PostEntity post, {
    required bool warmVideo,
  }) async {
    if (warmVideo) {
      unawaited(_prefetchVideo(post));
    }

    final firstSlide = _firstSlideImageUrl(post);
    if (firstSlide != null && context.mounted) {
      try {
        await precacheSafeNetworkImage(context, firstSlide);
      } catch (_) {
        // Best-effort: the post still loads normally when displayed.
      }
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

  Future<void> _prefetchVideo(PostEntity post) async {
    if (post.isAuctionable) return;

    final url = _firstSlideVideoUrl(post);
    if (url == null) return;
    await FeedVideoPrewarmer.instance.prewarm(url);
  }

  String? _firstSlideVideoUrl(PostEntity post) {
    final hlsUrl = post.hlsUrl;
    if (hlsUrl != null && hlsUrl.isNotEmpty) {
      return MediaUtils.resolveAbsoluteUrl(hlsUrl);
    }

    final media = post.media;
    if (media.isNotEmpty) {
      final first = media.first;
      final url = MediaUtils.resolveAbsoluteUrl(first.url);
      final isVideo =
          MediaUtils.isVideo(url, mediaType: first.mediaType) ||
          post.type == 'VIDEO';
      return isVideo && url.isNotEmpty ? url : null;
    }

    final videoUrl = post.videoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      return MediaUtils.resolveAbsoluteUrl(videoUrl);
    }
    return null;
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
