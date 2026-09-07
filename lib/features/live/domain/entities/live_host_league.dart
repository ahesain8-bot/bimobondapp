/// Host league tiers and progress (`lives/mobile-api.md` §19, `lives/endpoints.md`
/// `GET /lives/leagues` and `GET /lives/host-league/:userId`).
///
/// Every value is read from the server. Tier promotion and progress are never
/// computed on the client.
library;

class LiveLeagueTier {
  const LiveLeagueTier({required this.tier, this.minCoins, this.minFollowers});

  final String tier;

  /// Nullable on purpose: a missing threshold is unknown, not zero.
  final int? minCoins;
  final int? minFollowers;
}

class LiveHostLeague {
  const LiveHostLeague({
    required this.userId,
    this.username,
    this.tier,
    this.totalLiveEarnedCoins,
    this.followerCount,
    this.nextTier,
    this.progressPercentage,
  });

  final String userId;
  final String? username;

  /// `hostLeagueTier`, e.g. `D5` … `S`. Null when the server did not report
  /// one; the UI shows an unknown tier rather than inventing a default.
  final String? tier;
  final int? totalLiveEarnedCoins;
  final int? followerCount;
  final String? nextTier;

  /// 0–100 as sent by the server, or null when absent.
  final int? progressPercentage;

  bool get hasTier => tier != null && tier!.isNotEmpty;
}
