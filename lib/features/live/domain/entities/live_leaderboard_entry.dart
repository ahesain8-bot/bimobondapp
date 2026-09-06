import 'live_host.dart';

/// Entry from hourly host leaderboard or gifters leaderboard.
class LiveLeaderboardEntry {
  const LiveLeaderboardEntry({
    this.rank,
    this.score,
    this.coins,
    this.liveId,
    this.title,
    this.viewers,
    this.host,
    this.userId,
    this.displayName,
    this.avatarUrl,
    this.isPopular,
    this.popularReason,
    this.hostLeagueTier,
    this.gifterLevel,
  });

  final int? rank;
  final int? score;
  final int? coins;
  final String? liveId;
  final String? title;
  final int? viewers;
  final LiveHost? host;
  final String? userId;
  final String? displayName;
  final String? avatarUrl;

  /// Popular badge exactly as the server reported it. Never derived from
  /// viewer counts on the client.
  final bool? isPopular;
  final String? popularReason;

  /// Host league tier (`GET /lives/leaderboard/hourly` → `live.user`).
  final String? hostLeagueTier;

  /// Gifter level (`GET /lives/:id/leaderboard/gifters` → `user`).
  final int? gifterLevel;
}
