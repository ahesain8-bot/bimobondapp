import '../../domain/entities/live_gallery_item.dart';
import '../../domain/entities/live_guest.dart';
import '../../domain/entities/live_host.dart';
import '../../domain/entities/live_host_league.dart';
import '../../domain/entities/live_replay.dart';
import '../../domain/entities/live_leaderboard_entry.dart';
import '../../domain/entities/live_viewer.dart';

/// Maps guest / leaderboard / gallery JSON from lives/mobile-api.md.
class LiveHostExtrasMapper {
  const LiveHostExtrasMapper._();

  static LiveGuest guestFromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return LiveGuest(
      id: json['id']?.toString() ?? '',
      liveId: json['liveId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? user?['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'GUEST',
      status: json['status']?.toString() ?? '',
      mutedByHost: json['mutedByHost'] == true,
      cameraOffByHost: json['cameraOffByHost'] == true,
      displayName: user?['fullName']?.toString() ??
          user?['username']?.toString() ??
          'Guest',
      avatarUrl: user?['avatarUrl']?.toString(),
      username: user?['username']?.toString(),
    );
  }

  /// `GET /lives/leagues` → `{ "tiers": [ { tier, minCoins, minFollowers } ] }`.
  static List<LiveLeagueTier> leagueTiersFromJson(Map<String, dynamic> json) {
    final raw = json['tiers'] ?? json['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['tier']?.toString() ?? '').isNotEmpty)
        .map(
          (e) => LiveLeagueTier(
            tier: e['tier'].toString(),
            // Absent thresholds stay unknown rather than becoming zero.
            minCoins: _asInt(e['minCoins']),
            minFollowers: _asInt(e['minFollowers']),
          ),
        )
        .toList(growable: false);
  }

  /// `GET /lives/host-league/:userId`. Returns null without a usable user id.
  static LiveHostLeague? hostLeagueFromJson(Map<String, dynamic> json) {
    final source = json['hostLeague'] is Map
        ? Map<String, dynamic>.from(json['hostLeague'] as Map)
        : json;
    final userId = source['userId']?.toString() ?? '';
    if (userId.isEmpty) return null;
    return LiveHostLeague(
      userId: userId,
      username: source['username']?.toString(),
      tier: source['hostLeagueTier']?.toString() ?? source['tier']?.toString(),
      totalLiveEarnedCoins: _asInt(source['totalLiveEarnedCoins']),
      followerCount: _asInt(source['followerCount']),
      nextTier: source['nextTier']?.toString(),
      progressPercentage: _asInt(source['progressPercentage']),
    );
  }

  /// The `replay` object on `GET /lives/:id`, or the `GET .../replay` payload.
  /// An absent object means the live has no replay - not an error.
  static LiveReplay replayFromJson(Map<String, dynamic>? json) {
    if (json == null) return LiveReplay.none;
    final nested = json['replay'];
    final source = nested is Map
        ? Map<String, dynamic>.from(nested)
        : json;
    return LiveReplay(
      status: LiveReplayStatus.parse(source['status']?.toString()),
      enabled: source['enabled'] as bool?,
      available: source['available'] as bool?,
      url: (source['url'] ?? source['replayUrl'])?.toString(),
      expiresAt: DateTime.tryParse(source['expiresAt']?.toString() ?? ''),
      viewCount: _asInt(source['viewCount']),
    );
  }

  /// One clip from `GET /lives/:id/clips` or a create/post response.
  static LiveClip clipFromJson(Map<String, dynamic> json) {
    final nested = json['clip'];
    final source = nested is Map ? Map<String, dynamic>.from(nested) : json;
    return LiveClip(
      id: source['id']?.toString() ?? source['clipId']?.toString() ?? '',
      status: LiveClipStatus.parse(source['status']?.toString()),
      liveId: source['liveId']?.toString(),
      title: source['title']?.toString(),
      // Missing bounds stay unknown; they are never defaulted to zero.
      startSeconds: _asNum(source['startSeconds']),
      endSeconds: _asNum(source['endSeconds']),
      clipUrl: source['clipUrl']?.toString(),
      postId: (source['postId'] ?? source['post']?['id'])?.toString(),
      alreadyPosted: (json['alreadyPosted'] ?? source['alreadyPosted'])
          as bool?,
    );
  }

  static List<LiveClip> clipsFromJson(Map<String, dynamic> json) {
    final raw = json['data'] ?? json['items'] ?? json['clips'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => clipFromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
  }

  static LiveLeaderboardEntry leaderboardEntryFromJson(
    Map<String, dynamic> json, {
    int? fallbackRank,
  }) {
    // `GET /lives/leaderboard/hourly` nests the stream under `live`, while
    // `GET /lives/:id/leaderboard/gifters` puts `user` at the top level.
    // Reading only the top level dropped the host, title and liveId.
    final nested = json['live'];
    final live = nested is Map
        ? Map<String, dynamic>.from(nested)
        : const <String, dynamic>{};
    final rawUser = json['user'] ?? live['user'];
    final user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : null;
    final host = user == null
        ? null
        : LiveHost(
            id: user['id']?.toString() ?? '',
            displayName: user['fullName']?.toString() ??
                user['username']?.toString() ??
                'Host',
            avatarUrl: user['avatarUrl']?.toString(),
            username: user['username']?.toString(),
            isVerified: user['isVerified'] == true,
          );
    return LiveLeaderboardEntry(
      rank: _asInt(json['hourlyRank'] ?? json['rank']) ?? fallbackRank,
      score: _asInt(json['hourlyScore'] ?? json['score']),
      coins: _asInt(json['hourlyCoins'] ?? json['coins'] ?? json['totalCoins']),
      liveId:
          json['liveId']?.toString() ??
          live['id']?.toString() ??
          json['id']?.toString(),
      title: json['title']?.toString() ?? live['title']?.toString(),
      viewers: _asInt(json['viewers'] ?? live['viewers']),
      host: host,
      userId: json['userId']?.toString() ?? user?['id']?.toString(),
      displayName: host?.displayName ??
          json['username']?.toString() ??
          json['fullName']?.toString(),
      avatarUrl: host?.avatarUrl ?? json['avatarUrl']?.toString(),
      isPopular: (json['isPopular'] ?? live['isPopular']) as bool?,
      popularReason:
          (json['popularReason'] ?? live['popularReason'])?.toString(),
      hostLeagueTier: user?['hostLeagueTier']?.toString(),
      gifterLevel: _asInt(user?['gifterLevel']),
    );
  }

  static LiveGalleryItem galleryItemFromJson(Map<String, dynamic> json) {
    return LiveGalleryItem(
      id: json['id']?.toString() ??
          json['auctionId']?.toString() ??
          '',
      itemName: json['itemName']?.toString() ??
          json['title']?.toString() ??
          'عنصر',
      itemImageUrl:
          json['itemImageUrl']?.toString() ?? json['imageUrl']?.toString(),
      pinned: json['pinned'] == true,
      pinOrder: _asInt(json['pinOrder']),
      status: json['status']?.toString(),
      targetPrice: _asNum(json['targetPrice']),
      currentPrice: _asNum(json['currentPrice'] ?? json['startingPrice']),
    );
  }

  static LiveViewer viewerFromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final fullName = user?['fullName']?.toString();
    final handle = user?['username']?.toString();
    return LiveViewer(
      userId: user?['id']?.toString() ?? json['userId']?.toString() ?? '',
      displayName: (fullName != null && fullName.trim().isNotEmpty)
          ? fullName.trim()
          : (handle ?? 'مشاهد'),
      username: handle,
      avatarUrl: user?['avatarUrl']?.toString(),
      isVerified: user?['isVerified'] == true,
      gifterLevel: _asInt(user?['gifterLevel']),
      isActive: json['leftAt'] == null,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}
