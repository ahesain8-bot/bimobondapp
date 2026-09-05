import 'live_entity.dart';

/// One intentional activation of a server-delivered feed occurrence.
///
/// The screen reuses this object for rebuilds and foreground restoration.
/// Moving to another entry and returning creates a new object. Attribution
/// is consumed BEFORE requesting join, even if the request fails or times out:
/// retry/reconnect must not repeat a possibly accounted impression. No other
/// navigation source may infer a campaign from live details.
class LiveFeedActivation {
  LiveFeedActivation.fromEntry(LiveEntity entry)
    : liveId = entry.id,
      hostId = entry.hostId,
      campaignId = entry.isPromoted ? entry.promotion?.id : null;

  final String liveId;
  final String hostId;
  final String? campaignId;
  bool _consumed = false;

  bool get isConsumed => _consumed;

  String? consume({required String joiningLiveId, String? viewerId}) {
    if (_consumed || joiningLiveId != liveId) return null;
    _consumed = true;
    // Unknown viewer identity stays organic; the server remains authoritative.
    if (viewerId == null || viewerId.isEmpty || viewerId == hostId) return null;
    final id = campaignId?.trim();
    return id == null || id.isEmpty ? null : id;
  }
}
