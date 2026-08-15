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
}
