import '../../domain/entities/hourly_ranking_entity.dart';

/// Maps the hourly leaderboard payloads from lives/endpoints.md §11.
///
/// `GET /lives/leaderboard/hourly` responds with:
/// ```json
/// {
///   "windowStartsAt": "2026-08-15T12:00:00.000Z",
///   "windowEndsAt": "2026-08-15T13:00:00.000Z",
///   "data": [
///     { "rank": 1, "score": 4520, "hourlyCoins": 4200,
///       "isPopular": true, "popularReason": "hourly_rank",
///       "live": { "id": "…", "title": "…", "viewers": 142,
///                 "user": { "id": "…", "username": "…",
///                           "avatarUrl": "…", "hostLeagueTier": "B2" } } }
///   ]
/// }
/// ```
///
/// `GET /lives/:id/leaderboard/hourly` responds with a flat
/// `{ liveId, rank, score, hourlyCoins, isPopular, popularReason }`.
class HourlyRankingMapper {
  const HourlyRankingMapper._();

  static HourlyLeaderboard leaderboardFromPayload(
    Map<String, dynamic> payload,
  ) {
    final rows = payload['data'];
    final entries = <HourlyRankingEntry>[];
    if (rows is List) {
      for (final row in rows) {
        final map = _asMap(row);
        if (map == null) continue;
        final entry = entryFromJson(map, fallbackRank: entries.length + 1);
        if (entry != null) entries.add(entry);
      }
    }
    return HourlyLeaderboard(
      entries: entries,
      windowStartsAt: _parseDate(payload['windowStartsAt']),
      windowEndsAt: _parseDate(payload['windowEndsAt']),
    );
  }

  /// Returns null for rows without a live id — a ranking row that cannot be
  /// keyed to a stream is not something the sheet can render or open.
  static HourlyRankingEntry? entryFromJson(
    Map<String, dynamic> json, {
    required int fallbackRank,
  }) {
    final live = _asMap(json['live']) ?? const <String, dynamic>{};
    final user = _asMap(live['user']) ?? _asMap(json['user']);

    final liveId = live['id']?.toString() ?? json['liveId']?.toString() ?? '';
    if (liveId.isEmpty) return null;

    return HourlyRankingEntry(
      rank: _asInt(json['rank'] ?? json['hourlyRank']) ?? fallbackRank,
      liveId: liveId,
      hostId:
          user?['id']?.toString() ??
          live['userId']?.toString() ??
          json['userId']?.toString() ??
          '',
      hostName: _hostName(user),
      hostAvatarUrl: _nonEmpty(user?['avatarUrl']),
      hostLeagueTier: _nonEmpty(user?['hostLeagueTier']),
      title: _nonEmpty(live['title'] ?? json['title']),
      score: _asInt(json['score'] ?? json['hourlyScore']) ?? 0,
      hourlyCoins: _asInt(json['hourlyCoins'] ?? json['coins']) ?? 0,
      viewers: _asInt(live['viewers'] ?? live['viewerCount']) ?? 0,
      isPopular: json['isPopular'] == true,
      popularReason: _nonEmpty(json['popularReason']),
    );
  }

  static LiveHourlyRank liveRankFromPayload(
    Map<String, dynamic> payload, {
    required String fallbackLiveId,
  }) {
    final json = _asMap(payload['data']) ?? payload;
    return LiveHourlyRank(
      liveId: _nonEmpty(json['liveId']) ?? fallbackLiveId,
      rank: _asInt(json['rank'] ?? json['hourlyRank']),
      score: _asInt(json['score'] ?? json['hourlyScore']),
      hourlyCoins: _asInt(json['hourlyCoins'] ?? json['coins']),
      isPopular: json['isPopular'] == true,
      popularReason: _nonEmpty(json['popularReason'] ?? json['reason']),
    );
  }

  // ── Helpers ───────────────────────────────────────────

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static String _hostName(Map<String, dynamic>? user) {
    if (user == null) return 'Host';
    final fullName = _nonEmpty(user['fullName']);
    if (fullName != null) return fullName;
    return _nonEmpty(user['username']) ?? 'Host';
  }

  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
