import 'dart:async';

import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/services/feed_video_prewarmer.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/widgets.dart';

/// Warms caches for upcoming feed posts so the next page renders instantly
/// when the user scrolls to it.
///
/// For every upcoming post this:
/// - downloads + decodes the first image slide (or video poster) and the
///   author avatar into the image cache, and
/// - pre-initializes a paused video controller via [FeedVideoPrewarmer], so
///   [CustomVideoPlayer] adopts it and starts playback with no loading wait.
class FeedMediaPreloader {
  FeedMediaPreloader();

  /// How many posts ahead of the current one to preload.
  static const int _lookahead = 2;

  final Set<String> _preloadedIds = <String>{};

  /// Forget which posts were preloaded (e.g. after a feed refresh, since the
  /// list content changed).
  void reset() => _preloadedIds.clear();

  /// Preloads media for the posts after [currentIndex].
  void preloadAround(
    BuildContext context,
    List<FeedItemEntity> items,
    int currentIndex,
  ) {
    for (var offset = 1; offset <= _lookahead; offset++) {
      final index = currentIndex + offset;
      if (index < 0 || index >= items.length) continue;

      final item = items[index];
      if (!_preloadedIds.add(item.id)) continue;
      unawaited(_preloadPost(context, item.post));
    }
  }

  /// Feed post avatar renders at radius 24 (48px); precaching at the same
  /// size reuses the exact decoded image instead of decoding twice.
  static const double _avatarSize = 48;

  Future<void> _preloadPost(BuildContext context, PostEntity post) async {
    // Start the video download first: it is the slowest asset and the one
    // that decides whether the next post plays instantly.
    unawaited(_prefetchVideo(post));

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

  /// Pre-initializes a paused player for the next video instead of waiting
  /// for a full file download: the controller opens the stream and buffers
  /// the first seconds, so playback starts instantly regardless of length.
  Future<void> _prefetchVideo(PostEntity post) async {
    if (post.isAuctionable) return;

    final url = _firstSlideVideoUrl(post);
    if (url == null) return;
    await FeedVideoPrewarmer.instance.prewarm(url);
  }

  /// Video URL of the first slide (or the legacy post-level video), matching
  /// what [CustomVideoPlayer] will resolve when the post becomes active.
  String? _firstSlideVideoUrl(PostEntity post) {
    // Match VideoPostMediaItem: the post-level adaptive stream represents
    // the first/primary video and is preferred when the API provides it.
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

  /// Image the post shows the moment it becomes visible: the first image
  /// slide, or the poster for video/auction posts.
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

    // Media-less video post (legacy videoUrl field).
    return MediaUtils.resolveVideoPosterUrl(post);
  }
}
