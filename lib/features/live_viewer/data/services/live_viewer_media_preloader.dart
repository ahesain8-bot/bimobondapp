import '../../../../core/utils/app_media_cache_manager.dart';
import '../../domain/entities/live_entity.dart';

/// Warms the same disk cache used by post media before live/PK UI needs it.
///
/// LiveKit tracks themselves cannot be cached. Their equivalent of preload is
/// connecting/subscribing before revealing the two-person layout; this class
/// handles the HTTP images shown during a later reconnect or camera-off state.
class LiveViewerMediaPreloader {
  LiveViewerMediaPreloader._();

  static final LiveViewerMediaPreloader instance = LiveViewerMediaPreloader._();

  final Map<String, Future<void>> _inFlight = <String, Future<void>>{};
  final Set<String> _ready = <String>{};

  Future<void> prefetchLive(LiveEntity live) {
    final urls = <String?>[
      live.hostAvatar,
      live.thumbnailUrl,
      live.metadata?['guestAvatar']?.toString(),
      ..._stringList(live.metadata?['pkContributorsLeft']),
      ..._stringList(live.metadata?['pkContributorsRight']),
    ];
    return prefetchUrls(urls);
  }

  Future<void> prefetchUrls(Iterable<String?> urls) async {
    final futures = <Future<void>>[];
    for (final raw in urls) {
      final url = raw?.trim() ?? '';
      if (url.isEmpty || _ready.contains(url)) continue;
      futures.add(_inFlight.putIfAbsent(url, () => _download(url)));
    }
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  Future<void> _download(String url) async {
    try {
      final file = await AppMediaCacheManager.getCachedFile(url);
      if (await file.exists() && await file.length() > 0) {
        _ready.add(url);
      }
    } catch (_) {
      // A missing avatar must never delay or fail the LiveKit connection.
    } finally {
      _inFlight.remove(url);
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
