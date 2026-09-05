/// Domain models for the server-backed live room features: gift goals, polls,
/// Q&A, treasure boxes, auctions and the end-of-live summary
/// (lives/mobile-api.md §14–§22).
library;

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
  });

  final String id;
  final String liveId;
  final String question;
  final List<LivePollOption> options;
  final int totalVotes;
  final String status;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}

class LiveQA {
  const LiveQA({
    required this.id,
    required this.liveId,
    required this.username,
    required this.question,
    required this.isPinned,
    required this.isAnswered,
  });

  final String id;
  final String liveId;
  final String username;
  final String question;
  final bool isPinned;
  final bool isAnswered;
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

  bool get isExhausted => claimedCount >= maxClaims || remainingCoins <= 0;
  bool get isOpen {
    final normalized = status.toUpperCase();
    return normalized != 'ENDED' && normalized != 'EXPIRED';
  }

  /// Seconds left before the box may be claimed, derived from [unlocksAt] when
  /// the server sends it and from [createdAt] + [delaySeconds] otherwise.
  int secondsUntilUnlock(DateTime now) {
    final unlock = unlocksAt ?? createdAt?.add(Duration(seconds: delaySeconds));
    if (unlock == null) return 0;
    final remaining = unlock.difference(now).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  LiveTreasureBox copyWith({int? remainingCoins, int? claimedCount}) {
    return LiveTreasureBox(
      id: id,
      liveId: liveId,
      totalCoins: totalCoins,
      remainingCoins: remainingCoins ?? this.remainingCoins,
      maxClaims: maxClaims,
      delaySeconds: delaySeconds,
      claimedCount: claimedCount ?? this.claimedCount,
      status: status,
      createdAt: createdAt,
      unlocksAt: unlocksAt,
    );
  }
}

class LiveTreasureClaim {
  const LiveTreasureClaim({
    required this.boxId,
    required this.coinsWon,
    required this.claimedCount,
    required this.remainingCoins,
  });

  final String boxId;
  final int coinsWon;
  final int claimedCount;
  final int remainingCoins;
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
    this.startingPrice,
  });

  final String id;
  final String liveId;
  final String itemName;
  final int currentPrice;
  final int targetPrice;
  final String status;
  final bool isPinned;
  final int? startingPrice;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}

class LiveSummaryTopGifter {
  const LiveSummaryTopGifter({
    required this.displayName,
    required this.totalCoins,
  });

  final String displayName;
  final int totalCoins;
}

class LiveSummary {
  const LiveSummary({
    required this.liveId,
    required this.title,
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
  final int durationSeconds;
  final int peakViewers;
  final int totalViewerSessions;
  final int totalLikes;
  final int totalComments;
  final int totalEarnedCoins;
  final List<LiveSummaryTopGifter> topGifters;
}

/// A server push for one of the interactive room features, normalized so both
/// the host and viewer socket adapters can feed the same BLoC.
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
