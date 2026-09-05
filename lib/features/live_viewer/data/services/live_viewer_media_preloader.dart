import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/app_media_cache_manager.dart';
import '../../domain/entities/live_entity.dart';

/// Warms the same disk cache used by post media before live/PK UI needs it.
///
/// LiveKit tracks themselves cannot be cached. Their equivalent of preload is
/// connecting/subscribing before revealing the two-person layout; this class
/// handles the HTTP images shown while a room connects, during a reconnect, or
/// whenever the host's camera is off.
///
/// Preload exists to make swipes feel instant, so it must never compete with
/// the room the viewer is actually watching. Three properties enforce that:
///
/// * **Bounded concurrency.** Warming a ±2 neighbour window is up to five
///   lives with several images each. Issued at once on a mobile uplink those
///   requests share the same bottleneck as ICE and the first video frames.
///   [_maxConcurrent] keeps the queue from ever becoming that burst.
/// * **Cancellation.** [cancelPending] drops everything still queued. A swipe
///   invalidates the previous neighbour window entirely; finishing it would
///   spend bandwidth on pages the viewer has already left behind.
/// * **Prioritisation.** The live being activated is enqueued at the front, so
///   its poster is fetched before any neighbour's.
class LiveViewerMediaPreloader {
  LiveViewerMediaPreloader._();

  static final LiveViewerMediaPreloader instance = LiveViewerMediaPreloader._();

  /// Two at a time keeps the disk cache warming steadily without producing a
  /// request burst that shares the uplink with a room negotiating media.
  static const int _maxConcurrent = 2;

  final _queue = <_PreloadRequest>[];
  final _inFlight = <String, Future<void>>{};
  final _ready = <String>{};
  var _active = 0;

  /// Warms one live's images. [urgent] puts it ahead of queued neighbours,
  /// which is what the live currently being activated always wants.
  Future<void> prefetchLive(LiveEntity live, {bool urgent = false}) {
    return prefetchUrls(<String?>[
      live.hostAvatar,
      live.thumbnailUrl,
      live.metadata?['guestAvatar']?.toString(),
      ..._stringList(live.metadata?['pkContributorsLeft']),
      ..._stringList(live.metadata?['pkContributorsRight']),
    ], urgent: urgent);
  }

  Future<void> prefetchUrls(
    Iterable<String?> urls, {
    bool urgent = false,
  }) async {
    final futures = <Future<void>>[];
    final queued = <_PreloadRequest>[];
    for (final raw in urls) {
      final url = raw?.trim() ?? '';
      if (url.isEmpty || _ready.contains(url)) continue;
      final existing = _inFlight[url];
      if (existing != null) {
        futures.add(existing);
        continue;
      }
      final request = _PreloadRequest(url);
      _inFlight[url] = request.completer.future;
      queued.add(request);
      futures.add(request.completer.future);
    }
    if (queued.isEmpty) return;
    if (urgent) {
      _queue.insertAll(0, queued);
    } else {
      _queue.addAll(queued);
    }
    _pump();
    await Future.wait(futures);
  }

  /// Abandons work that has not started yet. In-flight requests are left to
  /// finish: they are single cache-manager GETs, already counted against
  /// [_maxConcurrent], and cancelling them mid-write would leave partial
  /// entries in the shared disk cache.
  void cancelPending() {
    if (_queue.isEmpty) return;
    final dropped = _queue.toList(growable: false);
    _queue.clear();
    for (final request in dropped) {
      _inFlight.remove(request.url);
      if (!request.completer.isCompleted) request.completer.complete();
    }
  }

  void _pump() {
    while (_active < _maxConcurrent && _queue.isNotEmpty) {
      final request = _queue.removeAt(0);
      _active++;
      unawaited(
        _download(request.url).whenComplete(() {
          _active--;
          _inFlight.remove(request.url);
          if (!request.completer.isCompleted) request.completer.complete();
          _pump();
        }),
      );
    }
  }

  Future<void> _download(String url) async {
    try {
      final file = await AppMediaCacheManager.getCachedFile(url);
      if (await file.exists() && await file.length() > 0) {
        _ready.add(url);
      }
    } catch (error) {
      // A missing avatar must never delay or fail the LiveKit connection.
      debugPrint('Live media preload skipped: $error');
    }
  }

  List<String> _stringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class _PreloadRequest {
  _PreloadRequest(this.url);

  final String url;
  final completer = Completer<void>();
}
