/// Domain models for the live features introduced in mobile-api.md §§14–22.

class LiveGiftGoal {
  const LiveGiftGoal({
    required this.id,
    required this.title,
    required this.target,
    required this.current,
  });

  final String id;
  final String? title;
  final int target;
  final int current;

  double get progress => target <= 0
      ? 0
      : (current / target).clamp(0.0, 1.0).toDouble();
  bool get isReached => target > 0 && current >= target;
}

class LivePollOption {
  const LivePollOption({
    required this.text,
    required this.votes,
    required this.percentage,
  });

  final String text;
  final int votes;
  final double percentage;
}

class LivePoll {
  const LivePoll({
    required this.id,
    required this.liveId,
    required this.question,
    required this.options,
    required this.totalVotes,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String liveId;
  final String question;
  final List<LivePollOption> options;
  final int totalVotes;
  final String status;
  final DateTime? createdAt;
}

class LiveQA {
  const LiveQA({
    required this.id,
    required this.liveId,
    required this.userId,
    required this.username,
    required this.question,
    required this.isPinned,
    required this.isAnswered,
    this.answer,
    this.createdAt,
  });

  final String id;
  final String liveId;
  final String userId;
  final String username;
  final String question;
  final bool isPinned;
  final bool isAnswered;
  final String? answer;
  final DateTime? createdAt;
}

class LiveTreasureBox {
  const LiveTreasureBox({
    required this.id,
    required this.liveId,
    required this.totalCoins,
    required this.remainingCoins,
    required this.maxClaims,
    required this.delaySeconds,
    required this.claimedCount,
    required this.status,
    this.createdAt,
    this.unlocksAt,
  });

  final String id;
  final String liveId;
  final int totalCoins;
  final int remainingCoins;
  final int maxClaims;
  final int delaySeconds;
  final int claimedCount;
  final String status;
  final DateTime? createdAt;
  final DateTime? unlocksAt;
}

class LiveTreasureClaim {
  const LiveTreasureClaim({
    required this.id,
    required this.boxId,
    required this.userId,
    required this.coinsWon,
    required this.claimedCount,
    required this.maxClaims,
    required this.box,
  });

  final String id;
  final String boxId;
  final String userId;
  final int coinsWon;
  final int claimedCount;
  final int maxClaims;
  final LiveTreasureBox box;
}

class LiveAuction {
  const LiveAuction({
    required this.id,
    required this.liveId,
    required this.itemName,
    required this.currentPrice,
    required this.targetPrice,
    required this.status,
    required this.isPinned,
    required this.pinOrder,
    this.itemImageUrl,
    this.startingPrice,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String liveId;
  final String itemName;
  final String? itemImageUrl;
  final int currentPrice;
  final int targetPrice;
  final String status;
  final bool isPinned;
  final int? pinOrder;
  final int? startingPrice;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

class LiveHourlyLeaderboardEntry {
  const LiveHourlyLeaderboardEntry({
    required this.rank,
    required this.score,
    required this.hourlyCoins,
    required this.isPopular,
    this.popularReason,
    required this.live,
  });

  final int rank;
  final int score;
  final int hourlyCoins;
  final bool isPopular;
  final String? popularReason;
  final Map<String, dynamic> live;
}

class LiveGifterLeaderboardEntry {
  const LiveGifterLeaderboardEntry({
    required this.rank,
    required this.totalCoins,
    required this.user,
  });

  final int rank;
  final int totalCoins;
  final Map<String, dynamic> user;
}

class LiveLeagueTier {
  const LiveLeagueTier({
    required this.tier,
    required this.minCoins,
    required this.minFollowers,
  });

  final String tier;
  final int minCoins;
  final int minFollowers;
}

class LiveHostLeague {
  const LiveHostLeague({
    required this.userId,
    required this.username,
    required this.hostLeagueTier,
    required this.totalLiveEarnedCoins,
    required this.followerCount,
    this.nextTier,
    required this.progressPercentage,
  });

  final String userId;
  final String username;
  final String hostLeagueTier;
  final int totalLiveEarnedCoins;
  final int followerCount;
  final String? nextTier;
  final double progressPercentage;
}

class LiveUserLevelUp {
  const LiveUserLevelUp({
    required this.userId,
    required this.newLevel,
    required this.currentXp,
    required this.nextLevelXp,
    required this.progressPercentage,
    required this.liveId,
  });

  final String userId;
  final int newLevel;
  final int currentXp;
  final int nextLevelXp;
  final double progressPercentage;
  final String liveId;
}

class LiveSummaryTopGifter {
  const LiveSummaryTopGifter({
    required this.user,
    required this.totalCoins,
  });

  final Map<String, dynamic> user;
  final int totalCoins;
}

class LiveSummary {
  const LiveSummary({
    required this.liveId,
    required this.title,
    this.coverUrl,
    this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.peakViewers,
    required this.totalViewerSessions,
    required this.totalLikes,
    required this.totalComments,
    required this.totalEarnedCoins,
    required this.topGifters,
  });

  final String liveId;
  final String title;
  final String? coverUrl;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final int peakViewers;
  final int totalViewerSessions;
  final int totalLikes;
  final int totalComments;
  final int totalEarnedCoins;
  final List<LiveSummaryTopGifter> topGifters;
}

class AdminLive {
  const AdminLive({
    required this.id,
    required this.userId,
    required this.title,
    required this.status,
    required this.viewers,
    required this.likeCount,
    required this.totalEarnedCoins,
    this.roomName,
    this.streamUrl,
    this.coverUrl,
    this.categoryId,
    this.banReason,
    this.feedBoostUntil,
    this.guestsEnabled,
    this.guestRequestMode,
    this.maxGuests,
    this.layout,
    this.allowGuestCamera,
    this.moderatorsCanManageGuests,
    this.user,
    this.category,
    this.activeAuctions = const [],
    this.pinnedComment,
    this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String status;
  final int viewers;
  final int likeCount;
  final int totalEarnedCoins;
  final String? roomName;
  final String? streamUrl;
  final String? coverUrl;
  final String? categoryId;
  final String? banReason;
  final DateTime? feedBoostUntil;
  final bool? guestsEnabled;
  final String? guestRequestMode;
  final int? maxGuests;
  final String? layout;
  final bool? allowGuestCamera;
  final bool? moderatorsCanManageGuests;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? category;
  final List<LiveAuction> activeAuctions;
  final Map<String, dynamic>? pinnedComment;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

class AdminLivePage {
  const AdminLivePage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<AdminLive> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
}

class AdminLiveInspection {
  const AdminLiveInspection({
    required this.live,
    required this.guests,
    required this.comments,
    this.battle,
    this.poll,
    this.questions = const [],
    this.treasureBoxes = const [],
    this.hourlyRank,
    this.gifters = const [],
    this.auctions = const [],
  });

  final AdminLive live;
  final List<Map<String, dynamic>> guests;
  final List<Map<String, dynamic>> comments;
  final Map<String, dynamic>? battle;
  final LivePoll? poll;
  final List<LiveQA> questions;
  final List<LiveTreasureBox> treasureBoxes;
  final LiveHourlyLeaderboardEntry? hourlyRank;
  final List<LiveGifterLeaderboardEntry> gifters;
  final List<LiveAuction> auctions;
}

class FanClubStatus {
  const FanClubStatus({
    required this.enabled,
    this.name,
    required this.isMember,
  });

  final bool enabled;
  final String? name;
  final bool isMember;
}

class FanClubSubscription {
  const FanClubSubscription({
    required this.id,
    required this.subscriberId,
    required this.creatorId,
    required this.status,
    this.startDate,
  });

  final String id;
  final String subscriberId;
  final String creatorId;
  final String status;
  final DateTime? startDate;
}

/// A normalized payload used by both host and viewer Socket.IO adapters.
class LiveInteractiveSocketPayload {
  const LiveInteractiveSocketPayload({
    required this.event,
    required this.liveId,
    required this.payload,
  });

  final String event;
  final String liveId;
  final Map<String, dynamic> payload;
}
