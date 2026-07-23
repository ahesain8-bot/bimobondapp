import 'dart:async';
import 'dart:collection';

import 'package:bimobondapp/core/services/feed_video_prewarmer.dart';
import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:flutter/foundation.dart';

/// Disk-caches progressive videos for the ±2 feed window.
///
/// Neighbor downloads start immediately (so scroll is ready). The playing URL
/// is only downloaded after playback has started.
class FeedVideoDiskPrefetcher {
  FeedVideoDiskPrefetcher._();

  static final FeedVideoDiskPrefetcher instance = FeedVideoDiskPrefetcher._();

  static const int _maxConcurrent = 2;
  static const int _maxQueued = 4; // ±2

  final LinkedHashSet<String> _queue = LinkedHashSet<String>();
  final Set<String> _inFlight = <String>{};
  Set<String> _retainUrls = <String>{};
  Set<String> _warmUrls = <String>{};
  String? _playingUrl;
  bool _cachePlaying = false;

  void setPlayingUrl(String? url) {
    _playingUrl = (url != null && url.isNotEmpty) ? url : null;
    _cachePlaying = false;
  }

  void markPlaybackSettled() {
    _cachePlaying = true;
    final playing = _playingUrl;
    if (playing != null && AppMediaCacheManager.canDiskCacheVideo(playing)) {
      _retainUrls = {..._retainUrls, playing};
      _queue.remove(playing);
      final rest = _queue.toList(growable: false);
      _queue
        ..clear()
        ..add(playing)
        ..addAll(rest.where((u) => u != playing));
      while (_queue.length > _maxQueued) {
        _queue.remove(_queue.last);
      }
    }
    _pump();
  }

  void setWarmUrls(Set<String> urls) {
    _warmUrls = {
      for (final u in urls)
        if (AppMediaCacheManager.canDiskCacheVideo(u)) u,
    };
  }

  void retainOnly(Set<String> urls) {
    _retainUrls = {
      for (final u in urls)
        if (AppMediaCacheManager.canDiskCacheVideo(u)) u,
    };
    if (_playingUrl != null && _cachePlaying) {
      _retainUrls = {..._retainUrls, _playingUrl!};
    }
    _queue.removeWhere((u) {
      if (u == _playingUrl && _cachePlaying) return false;
      return !_retainUrls.contains(u);
    });
  }

  void enqueueAll(Iterable<String> urls) {
    for (final url in urls) {
      if (!_accept(url)) continue;
      if (_queue.contains(url) || _inFlight.contains(url)) continue;
      _queue.add(url);
    }
    while (_queue.length > _maxQueued) {
      _queue.remove(_queue.last);
    }
    _pump();
  }

  void enqueueAfterWatch(String url) {
    if (kIsWeb || !AppMediaCacheManager.canDiskCacheVideo(url)) return;
    if (_inFlight.contains(url)) return;
    _retainUrls = {..._retainUrls, url};
    _queue.remove(url);
    final rest = _queue.toList(growable: false);
    _queue
      ..clear()
      ..add(url)
      ..addAll(rest.where((u) => u != url));
    while (_queue.length > _maxQueued) {
      _queue.remove(_queue.last);
    }
    _pump();
  }

  void clear() {
    _retainUrls = <String>{};
    _warmUrls = <String>{};
    _queue.clear();
    _playingUrl = null;
    _cachePlaying = false;
  }

  bool _accept(String url) {
    if (kIsWeb || !AppMediaCacheManager.canDiskCacheVideo(url)) return false;
    if (url == _playingUrl && !_cachePlaying) return false;
    if (_retainUrls.isNotEmpty && !_retainUrls.contains(url)) return false;
    return true;
  }

  void _pump() {
    while (_inFlight.length < _maxConcurrent && _queue.isNotEmpty) {
      final url = _queue.first;
      _queue.remove(url);
      if (url == _playingUrl && !_cachePlaying) continue;
      if (_retainUrls.isNotEmpty && !_retainUrls.contains(url)) continue;
      if (!_inFlight.add(url)) continue;
      unawaited(_download(url));
    }
  }

  Future<void> _download(String url) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (url == _playingUrl && !_cachePlaying) return;
      if (_retainUrls.isNotEmpty && !_retainUrls.contains(url)) return;

      final existing = await AppMediaCacheManager.getCachedVideoFile(url);
      if (existing == null) {
        await AppMediaCacheManager.downloadVideoFile(url);
      }

      if (_warmUrls.contains(url) && url != _playingUrl) {
        unawaited(FeedVideoPrewarmer.instance.prewarm(url));
      }
    } catch (e) {
      debugPrint('Video disk prefetch failed: $e');
    } finally {
      _inFlight.remove(url);
      _pump();
    }
  }
}
