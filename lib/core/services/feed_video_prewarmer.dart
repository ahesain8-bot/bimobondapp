import 'dart:async';
import 'dart:collection';

import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:video_player/video_player.dart';

/// Keeps fully initialized, paused [VideoPlayerController]s for upcoming feed
/// videos.
///
/// Initializing a network video (open connection, read metadata, buffer the
/// first seconds) is what makes scrolling to the next post feel slow. This
/// pool does that work while the user is still on the previous post, so the
/// player can adopt a ready controller and start playback instantly.
class FeedVideoPrewarmer {
  FeedVideoPrewarmer._();

  static final FeedVideoPrewarmer instance = FeedVideoPrewarmer._();

  /// Max controllers kept ready. Each one holds a platform decoder, so keep
  /// this small: it matches the feed's two-post lookahead.
  static const int _maxReady = 2;

  final LinkedHashMap<String, VideoPlayerController> _ready =
      LinkedHashMap<String, VideoPlayerController>();
  final Set<String> _inFlight = <String>{};

  /// Initializes a paused, muted controller for [url] and keeps it ready.
  Future<void> prewarm(String url) async {
    if (url.isEmpty) return;
    if (_ready.containsKey(url) || !_inFlight.add(url)) return;

    VideoPlayerController? controller;
    try {
      final options = VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      );

      final isHls = url.toLowerCase().split('?').first.endsWith('.m3u8');
      // HLS consists of a playlist plus segments, so it cannot be represented
      // by one cached file. Pre-initialize its network controller directly.
      final cached = isHls
          ? null
          : await AppMediaCacheManager.instance.getFileFromCache(url);
      final file = cached?.file;
      controller = (file != null && await file.exists())
          ? VideoPlayerController.file(file, videoPlayerOptions: options)
          : VideoPlayerController.networkUrl(
              Uri.parse(url),
              videoPlayerOptions: options,
            );

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);

      _ready[url] = controller;
      controller = null;
      _evictIfNeeded();
    } catch (_) {
      // Best-effort: the player falls back to its normal init path.
    } finally {
      if (controller != null) {
        try {
          await controller.dispose();
        } catch (_) {}
      }
      _inFlight.remove(url);
    }
  }

  /// Hands over the ready controller for [url], or null when none exists.
  /// The caller becomes the owner and must dispose it.
  VideoPlayerController? take(String url) => _ready.remove(url);

  /// Disposes all pooled controllers (e.g. when leaving the feed).
  void clear() {
    final controllers = _ready.values.toList();
    _ready.clear();
    for (final controller in controllers) {
      unawaited(_disposeQuietly(controller));
    }
  }

  void _evictIfNeeded() {
    while (_ready.length > _maxReady) {
      final oldestUrl = _ready.keys.first;
      final controller = _ready.remove(oldestUrl);
      if (controller != null) unawaited(_disposeQuietly(controller));
    }
  }

  Future<void> _disposeQuietly(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (_) {}
  }
}
