import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_feed_promotion.dart';
import '../../domain/entities/live_feed_page_result.dart';

/// Maps Nest live JSON (lives/mobile-api.md §5) into [LiveEntity].
///
/// The backend `Live` object shape:
/// ```json
/// {
///   "id": "uuid",
///   "user": { "id": "uuid", "fullName": "…", "username": "…",
///             "avatarUrl": "…", "hostHeartCount": 1200, "hostLeagueTier": "B2" },
///   "userId": "uuid",
///   "title": "…",
///   "status": "LIVE",
///   "viewers": 41,
///   "likeCount": 121,
///   "categoryId": "…",
///   "categoryName": "…",
///   "coverUrl": "…",
///   "streamUrl": "…",
///   "hourlyRank": 5,
///   "isPopular": true,
///   "totalEarnedCoins": 1000,
///   "startedAt": "ISO-8601"
/// }
/// ```
class LiveMapper {
  const LiveMapper._();

  static LiveEntity fromJson(Map<String, dynamic> json) {
    final user = _asMap(json['user']);
    final id = json['id']?.toString() ?? '';

    final viewerCount =
        _asInt(
          json['viewers'] ??
              json['viewerCount'] ??
              json['viewer_count'] ??
              json['count'],
        ) ??
        0;
    final likeCount = _asInt(json['likeCount']) ?? 0;
    final status = _parseStatus(json['status']?.toString());
    final hourlyRank = _asInt(json['hourlyRank']);

    return LiveEntity(
      id: id,
      hostId: user?['id']?.toString() ?? json['userId']?.toString() ?? '',
      hostName: _hostName(user),
      hostAvatar: user?['avatarUrl']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      thumbnailUrl: json['coverUrl']?.toString(),
      streamUrl: json['streamUrl']?.toString(),
      category:
          json['categoryName']?.toString() ??
          json['category']?.toString() ??
          'General',
      viewerCount: viewerCount,
      likeCount: likeCount,
      startTime:
          _parseDate(json['startedAt']) ??
          _parseDate(json['createdAt']) ??
          DateTime.now(),
      endTime: _parseDate(json['endedAt']),
      status: status,
      isLive: status == LiveStatus.live,
      isFollowing: json['isFollowing'] == true,
      isPromoted: json['isPromoted'] == true,
      promotion: LiveFeedPromotion.fromJson(json['promotion']),
      metadata: _buildMetadata(json, user, hourlyRank),
    );
  }

  /// Normalizes a feed/list payload — the backend wraps in `{ data, meta }`.
  static List<LiveEntity> listFromPayload(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is List) {
      return data
          .map((e) => fromJson(_asMap(e) ?? const <String, dynamic>{}))
          .where((l) => l.id.isNotEmpty)
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final live = fromJson(data);
      return live.id.isEmpty ? const [] : [live];
    }
    return const [];
  }

  /// Parses `{ data, meta }` into a page result for finite pagination.
  static LiveFeedPageResult pageFromPayload(
    Map<String, dynamic> payload, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final lives = listFromPayload(payload);
    final meta = _asMap(payload['meta']);
    final page = _asInt(meta?['page']) ?? requestedPage;
    final limit = _asInt(meta?['limit']) ?? requestedLimit;
    final total = _asInt(meta?['total']);
    final totalPages = _asInt(meta?['totalPages']);
    return LiveFeedPageResult(
      lives: lives,
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
    );
  }

  /// Extracts distinct categories from a feed payload (fallback for
  /// `GET /lives/feed` which does not expose a dedicated categories list).
  static List<String> categoriesFromPayload(Map<String, dynamic> payload) {
    final seen = <String>{};
    final result = <String>[];
    for (final live in listFromPayload(payload)) {
      if (seen.add(live.category)) {
        result.add(live.category);
      }
    }
    return result;
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
    final fullName = user['fullName']?.toString();
    final username = user['username']?.toString();
    if (fullName != null && fullName.trim().isNotEmpty) return fullName.trim();
    return username ?? 'Host';
  }

  static LiveStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'LIVE':
        return LiveStatus.live;
      case 'PLANNED':
      case 'SCHEDULED':
        return LiveStatus.scheduled;
      case 'PAUSED':
        return LiveStatus.paused;
      case 'ENDED':
        return LiveStatus.ended;
      case 'BANNED':
        return LiveStatus.banned;
      default:
        return LiveStatus.live;
    }
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

  static Map<String, dynamic>? _buildMetadata(
    Map<String, dynamic> json,
    Map<String, dynamic>? user,
    int? hourlyRank,
  ) {
    final meta = <String, dynamic>{};

    final battleSnapshot = _asMap(json['battle']);
    final isPk =
        battleSnapshot?['status']?.toString().toUpperCase() == 'ACTIVE';
    final isMultiGrid = json['isMultiGrid'] == true;
    final isMultiGuest = json['isMultiGuest'] == true;

    meta['isPk'] = isPk;
    meta['isMultiGrid'] = isMultiGrid;
    meta['isMultiGuest'] = isMultiGuest;
    meta['layout'] = json['layout']?.toString().toUpperCase() ?? 'PANEL';
    meta['guestsEnabled'] = json['guestsEnabled'] != false;
    meta['allowGuestCamera'] = json['allowGuestCamera'] != false;
    meta['maxGuests'] = _asInt(json['maxGuests']) ?? 3;
    meta['location'] = json['location']?.toString() ?? 'Live';
    meta['hourlyRank'] = hourlyRank ?? _asInt(json['hourlyRank']);
    meta['shareCount'] = _asInt(json['shareCount']) ?? 0;
    meta['showFanClub'] =
        json['fanClub'] != null || json['showFanClub'] == true;

    final fanClub = _asMap(json['fanClub']);
    if (fanClub != null) {
      meta['fanClub'] = fanClub;
      meta['fanClubName'] = fanClub['name']?.toString() ?? 'Fan Club';
      meta['fanClubMemberCount'] = _asInt(fanClub['memberCount']) ?? 0;
      meta['fanClubEnabled'] = fanClub['enabled'] == true;
    }

    // Popular badge (TikTok parity §20).
    if (json['isPopular'] == true || hourlyRank != null) {
      meta['isPopular'] = true;
      meta['popularReason'] =
          json['popularReason']?.toString() ?? 'hourly_rank';
    }

    // Host league tier from the user object.
    if (user != null) {
      meta['hostLeagueTier'] = user['hostLeagueTier']?.toString();
      meta['hostHeartCount'] = _asInt(user['hostHeartCount']) ?? 0;
    }

    // Gift goal (gallery/auction driven).
    if (json['giftGoalCurrent'] != null || json['giftGoalTarget'] != null) {
      meta['showGiftGoal'] = true;
      meta['giftGoalCurrent'] = _asInt(json['giftGoalCurrent']) ?? 0;
      meta['giftGoalTarget'] = _asInt(json['giftGoalTarget']) ?? 0;
    }

    // Guests snapshot.
    final guests = json['guests'];
    if (guests is List) {
      meta['guests'] = guests;
    }

    final topAvatars = _avatarUrlsFrom(
      json['topViewers'] ?? json['viewersList'] ?? json['recentViewers'],
    );
    if (topAvatars.isNotEmpty) {
      meta['topViewerAvatars'] = topAvatars;
    }

    final pinned = _asMap(json['pinnedComment']);
    if (pinned != null) {
      meta['pinnedComment'] = pinned;
    }

    // PK battle snapshot.
    final battle = battleSnapshot;
    if (battle != null) {
      meta['scoreLeft'] = _asInt(battle['scoreLeft']) ?? 0;
      meta['scoreRight'] = _asInt(battle['scoreRight']) ?? 0;
      meta['guestName'] = battle['opponentName']?.toString();
      meta['guestAvatar'] = battle['opponentAvatar']?.toString();
    }

    return meta.isEmpty ? null : meta;
  }

  static List<String> _avatarUrlsFrom(dynamic raw) {
    if (raw is! List) return const [];
    final urls = <String>[];
    for (final item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        urls.add(item.trim());
        continue;
      }
      final map = _asMap(item);
      if (map == null) continue;
      final user = _asMap(map['user']) ?? map;
      final url = user['avatarUrl']?.toString() ?? user['avatar']?.toString();
      if (url != null && url.trim().isNotEmpty) urls.add(url.trim());
    }
    return urls.take(3).toList();
  }
}
