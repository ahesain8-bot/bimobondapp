import 'dart:async';
import 'dart:collection';

import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:video_player/video_player.dart';

/// Keeps fully initialized, paused [VideoPlayerController]s for nearby feed
/// videos (lookahead + lookbehind window).
///
/// Initializing a network video is what makes scrolling feel slow. This pool
/// does that work while the user is still on another post, so the player can
/// adopt a ready controller and start playback instantly.
class FeedVideoPrewarmer {
  FeedVideoPrewarmer._();

  static final FeedVideoPrewarmer instance = FeedVideoPrewarmer._();

  /// Max controllers kept ready: 2 ahead + 2 behind.
  /// Each holds a platform decoder — keep this small.
  static const int _maxReady = 4;

  final LinkedHashMap<String, VideoPlayerController> _ready =
      LinkedHashMap<String, VideoPlayerController>();
  final Set<String> _inFlight = <String>{};
  Set<String> _retainUrls = <String>{};

  /// Restrict the pool to [urls] (current ±2 window). Controllers for other
  /// URLs are disposed. Call after each [FeedMediaPreloader.preloadAround].
  void retainOnly(Set<String> urls) {
    _retainUrls = Set<String>.from(urls);
    final toDrop = _ready.keys.where((u) => !urls.contains(u)).toList();
    for (final url in toDrop) {
      final controller = _ready.remove(url);
      if (controller != null) unawaited(_disposeQuietly(controller));
    }
    _evictIfNeeded();
  }

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

      // Window may have moved while we were initializing.
      if (_retainUrls.isNotEmpty && !_retainUrls.contains(url)) {
        await _disposeQuietly(controller);
        controller = null;
        return;
      }

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
    _retainUrls = <String>{};
    final controllers = _ready.values.toList();
    _ready.clear();
    for (final controller in controllers) {
      unawaited(_disposeQuietly(controller));
    }
  }

  void _evictIfNeeded() {
    while (_ready.length > _maxReady) {
      // Prefer evicting URLs outside the retain window first.
      String? victim;
      if (_retainUrls.isNotEmpty) {
        for (final url in _ready.keys) {
          if (!_retainUrls.contains(url)) {
            victim = url;
            break;
          }
        }
      }
      victim ??= _ready.keys.first;
      final controller = _ready.remove(victim);
      if (controller != null) unawaited(_disposeQuietly(controller));
    }
  }

  Future<void> _disposeQuietly(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (_) {}
  }
}
