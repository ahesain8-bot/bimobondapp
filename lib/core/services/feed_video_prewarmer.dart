import 'dart:async';
import 'dart:collection';

import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:video_player/video_player.dart';

/// Parks up to 2 ready controllers so scroll up/down can [take] instantly.
class FeedVideoPrewarmer {
  FeedVideoPrewarmer._();

  static final FeedVideoPrewarmer instance = FeedVideoPrewarmer._();

  static const int _maxReady = 2;

  final LinkedHashMap<String, VideoPlayerController> _ready =
      LinkedHashMap<String, VideoPlayerController>();
  final Set<String> _inFlight = <String>{};
  Set<String> _retainUrls = <String>{};

  void retainOnly(Set<String> urls) {
    // Keep any currently parked URLs that are still in the ±2 window.
    _retainUrls = Set<String>.from(urls);
    final toDrop = _ready.keys.where((u) => !urls.contains(u)).toList();
    for (final url in toDrop) {
      final controller = _ready.remove(url);
      if (controller != null) unawaited(_disposeQuietly(controller));
    }
    _evictIfNeeded();
  }

  Future<void> prewarm(String url) async {
    if (url.isEmpty) return;
    if (_ready.containsKey(url) || _inFlight.contains(url)) return;
    if (_ready.length >= _maxReady) return;
    if (_retainUrls.isNotEmpty && !_retainUrls.contains(url)) return;
    if (!_inFlight.add(url)) return;

    VideoPlayerController? controller;
    try {
      final file = await AppMediaCacheManager.getCachedVideoFile(url);
      if (file == null) return;
      if (_retainUrls.isNotEmpty && !_retainUrls.contains(url)) return;
      if (_ready.length >= _maxReady) return;

      controller = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);

      if (_retainUrls.isNotEmpty && !_retainUrls.contains(url)) {
        await _disposeQuietly(controller);
        controller = null;
        return;
      }

      _ready[url] = controller;
      controller = null;
      _evictIfNeeded();
    } catch (_) {
    } finally {
      if (controller != null) {
        try {
          await controller.dispose();
        } catch (_) {}
      }
      _inFlight.remove(url);
    }
  }

  VideoPlayerController? take(String url) => _ready.remove(url);

  /// Always accept a just-left player for scroll-back (do not require retain).
  /// [retainOnly] cleans up once the window moves past ±2.
  void offer(String url, VideoPlayerController controller) {
    if (url.isEmpty) {
      unawaited(_disposeQuietly(controller));
      return;
    }
    try {
      if (!controller.value.isInitialized || controller.value.hasError) {
        unawaited(_disposeQuietly(controller));
        return;
      }
    } catch (_) {
      unawaited(_disposeQuietly(controller));
      return;
    }

    // Ensure the parked URL survives the next retainOnly until out of window.
    _retainUrls = {..._retainUrls, url};

    final existing = _ready.remove(url);
    if (existing != null && !identical(existing, controller)) {
      unawaited(_disposeQuietly(existing));
    }
    // Most-recently parked should be preferred (insert as newest).
    _ready[url] = controller;
    _evictIfNeeded();
  }

  void clear() {
    _retainUrls = <String>{};
    final controllers = _ready.values.toList();
    _ready.clear();
    _inFlight.clear();
    for (final controller in controllers) {
      unawaited(_disposeQuietly(controller));
    }
  }

  void _evictIfNeeded() {
    while (_ready.length > _maxReady) {
      // Evict oldest (first) — LinkedHashMap preserves insertion order.
      final victim = _ready.keys.first;
      final controller = _ready.remove(victim);
      if (controller != null) unawaited(_disposeQuietly(controller));
    }
  }

  Future<void> _disposeQuietly(VideoPlayerController controller) async {
    try {
      await controller.pause();
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }
}
