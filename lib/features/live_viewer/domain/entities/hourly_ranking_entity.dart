import 'package:equatable/equatable.dart';

/// One row of `GET /lives/leaderboard/hourly` (lives/endpoints.md §11).
///
/// The backend ranks every currently-live stream for the running UTC hour using
/// `hourlyCoins × 1 + viewers × 0.5 + likeCount × 0.05`, so every entry refers
/// to a stream that is live right now.
class HourlyRankingEntry extends Equatable {
  const HourlyRankingEntry({
    required this.rank,
    required this.liveId,
    required this.hostId,
    required this.hostName,
    this.hostAvatarUrl,
    this.hostLeagueTier,
    this.title,
    this.score = 0,
    this.hourlyCoins = 0,
    this.viewers = 0,
    this.isPopular = false,
    this.popularReason,
  });

  final int rank;
  final String liveId;
  final String hostId;
  final String hostName;
  final String? hostAvatarUrl;

  /// Host league tier such as `B2`, from `live.user.hostLeagueTier`.
  final String? hostLeagueTier;
  final String? title;
  final int score;
  final int hourlyCoins;
  final int viewers;

  /// Whether the backend awarded this stream the POPULAR badge this hour.
  final bool isPopular;

  /// `admin_boost` | `hourly_rank` | `engagement` | `viewers`.
  final String? popularReason;

  @override
  List<Object?> get props => [
    rank,
    liveId,
    hostId,
    hostName,
    hostAvatarUrl,
    hostLeagueTier,
    title,
    score,
    hourlyCoins,
    viewers,
    isPopular,
    popularReason,
  ];
}

/// `GET /lives/leaderboard/hourly` envelope — the ranking window plus its rows.
class HourlyLeaderboard extends Equatable {
  const HourlyLeaderboard({
    this.entries = const [],
    this.windowStartsAt,
    this.windowEndsAt,
  });

  final List<HourlyRankingEntry> entries;

  /// Start of the UTC hour being ranked. Null when the backend omits it.
  final DateTime? windowStartsAt;

  /// End of the UTC hour being ranked — when the ranking resets.
  final DateTime? windowEndsAt;

  /// Hosts the backend flagged as popular for this window.
  List<HourlyRankingEntry> get trending =>
      entries.where((e) => e.isPopular).toList(growable: false);

  @override
  List<Object?> get props => [entries, windowStartsAt, windowEndsAt];
}

/// `GET /lives/:id/leaderboard/hourly` — where one stream sits this hour.
class LiveHourlyRank extends Equatable {
  const LiveHourlyRank({
    required this.liveId,
    this.rank,
    this.score,
    this.hourlyCoins,
    this.isPopular = false,
    this.popularReason,
  });

  final String liveId;

  /// Null when the stream has not scored this hour, so it is unranked.
  final int? rank;
  final int? score;
  final int? hourlyCoins;
  final bool isPopular;
  final String? popularReason;

  @override
  List<Object?> get props => [
    liveId,
    rank,
    score,
    hourlyCoins,
    isPopular,
    popularReason,
  ];
}
