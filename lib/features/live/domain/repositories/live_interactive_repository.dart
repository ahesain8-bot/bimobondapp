import '../entities/live_interactive.dart';

abstract class LiveInteractiveRepository {
  Future<LiveGiftGoal> createGiftGoal({
    required String liveId,
    String? title,
    required int target,
  });

  Future<LivePoll> createPoll({
    required String liveId,
    required String question,
    required List<String> options,
  });

  Future<LivePoll> votePoll({
    required String liveId,
    required String pollId,
    required int optionIndex,
  });

  Future<LivePoll> endPoll({required String liveId, required String pollId});
  Future<LivePoll?> getActivePoll(String liveId);

  Future<LiveQA> createQuestion({
    required String liveId,
    required String question,
  });
  Future<List<LiveQA>> listQuestions(String liveId);
  Future<LiveQA> pinQuestion({required String liveId, required String questionId});
  Future<LiveQA> answerQuestion({required String liveId, required String questionId});

  Future<LiveTreasureBox> createTreasureBox({
    required String liveId,
    required int totalCoins,
    required int maxClaims,
    int? delaySeconds,
  });
  Future<LiveTreasureClaim> claimTreasureBox({
    required String liveId,
    required String boxId,
  });
  Future<List<LiveTreasureBox>> listTreasureBoxes(String liveId);

  Future<LiveAuction> createAuction({
    required String liveId,
    required String itemName,
    required int targetPrice,
    String? itemImageUrl,
    int? startingPrice,
    DateTime? startedAt,
    DateTime? endedAt,
  });
  Future<List<LiveAuction>> listAuctions(String liveId, {String status = 'ALL'});
  Future<List<LiveAuction>> listActiveAuctions(String liveId);
  Future<List<LiveAuction>> listGallery(String liveId);
  Future<LiveAuction> pinAuction({
    required String liveId,
    required String auctionId,
    required bool pinned,
  });
  Future<List<LiveAuction>> reorderAuctions({
    required String liveId,
    required List<String> auctionIds,
  });

  Future<List<LiveHourlyLeaderboardEntry>> getGlobalHourlyLeaderboard({int limit = 20});
  Future<LiveHourlyLeaderboardEntry> getLiveHourlyRank(String liveId);
  Future<List<LiveGifterLeaderboardEntry>> getLiveGifters(
    String liveId, {
    int limit = 10,
    String window = 'session',
  });
  Future<List<LiveLeagueTier>> getLeagues();
  Future<LiveHostLeague> getHostLeague(String userId);

  Future<FanClubStatus> getFanClub(String creatorId);
  Future<FanClubSubscription> subscribeFanClub(String creatorId);
  Future<void> unsubscribeFanClub(String creatorId);

  Future<LiveSummary> getSummary(String liveId);

  Future<AdminLivePage> getAdminLives({
    int page = 1,
    int limit = 20,
    String? status,
    String? userId,
    String? search,
  });
  Future<Set<String>> getAdminPermissions();
  Future<Map<String, dynamic>> getAdminLiveDetail(String liveId);
  Future<AdminLiveInspection> inspectLive(String liveId);
  Future<Map<String, dynamic>> adminEndLive(String liveId);
  Future<Map<String, dynamic>> adminBanLive({
    required String liveId,
    required String reason,
  });
  Future<Map<String, dynamic>> adminKickGuest({
    required String liveId,
    required String userId,
  });
  Future<Map<String, dynamic>> adminBoostLive({
    required String liveId,
    int durationMinutes = 60,
  });
}
