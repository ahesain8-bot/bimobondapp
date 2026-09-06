/// `trafficSource` buckets for `POST /lives/:id/join`
/// (`lives/live-p0-parity.md` §5). These feed the host's
/// `trafficSourceBreakdown` in `GET /lives/:id/summary`.
///
/// Distinct from `TrafficSource` in `traffic_source.dart`, which belongs to
/// `POST /posts/:id/view` and uses a different vocabulary. Never mix them.
class LiveTrafficSource {
  const LiveTrafficSource._();

  static const String forYou = 'FOR_YOU';
  static const String following = 'FOLLOWING';
  static const String profile = 'PROFILE';
  static const String search = 'SEARCH';
  static const String shares = 'SHARES';
  static const String notification = 'NOTIFICATION';
  static const String chat = 'CHAT';

  /// Sent by the server when a `campaignId` arrives without a bucket, so the
  /// client does not need to send it — and must not send it for organic opens.
  static const String promote = 'PROMOTE';
  static const String other = 'OTHER';

  static const Set<String> values = {
    forYou,
    following,
    profile,
    search,
    shares,
    notification,
    chat,
    promote,
    other,
  };

  /// Returns the value only when it is one of the documented buckets.
  ///
  /// An unrecognised screen sends nothing rather than inventing a bucket: the
  /// server then applies its own default, and the gap is visible as a wiring
  /// task instead of silently polluting the host's report.
  static String? normalise(String? source) {
    final upper = source?.trim().toUpperCase();
    if (upper == null || upper.isEmpty) return null;
    return values.contains(upper) ? upper : null;
  }
}
