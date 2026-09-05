import '../entities/live_interactive.dart';
import '../repositories/live_interactive_repository.dart';

/// Application-facing use-case facade for the documented live interactions.
/// Keeping the BLoCs dependent on this facade makes the REST contract
/// replaceable without moving networking into presentation code.
class LiveInteractiveUseCases {
  const LiveInteractiveUseCases(this.repository);

  final LiveInteractiveRepository repository;

  Future<LiveGiftGoal> createGiftGoal({required String liveId, String? title, required int target}) =>
      repository.createGiftGoal(liveId: liveId, title: title, target: target);
  Future<LivePoll> createPoll({required String liveId, required String question, required List<String> options}) =>
      repository.createPoll(liveId: liveId, question: question, options: options);
  Future<LivePoll> votePoll({required String liveId, required String pollId, required int optionIndex}) =>
      repository.votePoll(liveId: liveId, pollId: pollId, optionIndex: optionIndex);
  Future<LivePoll> endPoll({required String liveId, required String pollId}) =>
      repository.endPoll(liveId: liveId, pollId: pollId);
  Future<LivePoll?> getActivePoll(String liveId) => repository.getActivePoll(liveId);
  Future<LiveQA> createQuestion({required String liveId, required String question}) =>
      repository.createQuestion(liveId: liveId, question: question);
  Future<List<LiveQA>> listQuestions(String liveId) => repository.listQuestions(liveId);
  Future<LiveQA> pinQuestion({required String liveId, required String questionId}) =>
      repository.pinQuestion(liveId: liveId, questionId: questionId);
  Future<LiveQA> answerQuestion({required String liveId, required String questionId}) =>
      repository.answerQuestion(liveId: liveId, questionId: questionId);
  Future<LiveTreasureBox> createTreasureBox({required String liveId, required int totalCoins, required int maxClaims, int? delaySeconds}) =>
      repository.createTreasureBox(liveId: liveId, totalCoins: totalCoins, maxClaims: maxClaims, delaySeconds: delaySeconds);
  Future<LiveTreasureClaim> claimTreasureBox({required String liveId, required String boxId}) =>
      repository.claimTreasureBox(liveId: liveId, boxId: boxId);
  Future<List<LiveTreasureBox>> listTreasureBoxes(String liveId) => repository.listTreasureBoxes(liveId);
  Future<LiveAuction> createAuction({required String liveId, required String itemName, required int targetPrice, String? itemImageUrl, int? startingPrice, DateTime? startedAt, DateTime? endedAt}) =>
      repository.createAuction(liveId: liveId, itemName: itemName, targetPrice: targetPrice, itemImageUrl: itemImageUrl, startingPrice: startingPrice, startedAt: startedAt, endedAt: endedAt);
  Future<List<LiveAuction>> listAuctions(String liveId, {String status = 'ALL'}) => repository.listAuctions(liveId, status: status);
  Future<List<LiveAuction>> listActiveAuctions(String liveId) => repository.listActiveAuctions(liveId);
  Future<List<LiveAuction>> listGallery(String liveId) => repository.listGallery(liveId);
  Future<LiveAuction> pinAuction({required String liveId, required String auctionId, required bool pinned}) =>
      repository.pinAuction(liveId: liveId, auctionId: auctionId, pinned: pinned);
  Future<List<LiveAuction>> reorderAuctions({required String liveId, required List<String> auctionIds}) =>
      repository.reorderAuctions(liveId: liveId, auctionIds: auctionIds);
  Future<List<LiveHourlyLeaderboardEntry>> getGlobalHourlyLeaderboard({int limit = 20}) => repository.getGlobalHourlyLeaderboard(limit: limit);
  Future<LiveHourlyLeaderboardEntry> getLiveHourlyRank(String liveId) => repository.getLiveHourlyRank(liveId);
  Future<List<LiveGifterLeaderboardEntry>> getLiveGifters(String liveId, {int limit = 10, String window = 'session'}) =>
      repository.getLiveGifters(liveId, limit: limit, window: window);
  Future<List<LiveLeagueTier>> getLeagues() => repository.getLeagues();
  Future<LiveHostLeague> getHostLeague(String userId) => repository.getHostLeague(userId);
  Future<FanClubStatus> getFanClub(String creatorId) => repository.getFanClub(creatorId);
  Future<FanClubSubscription> subscribeFanClub(String creatorId) => repository.subscribeFanClub(creatorId);
  Future<void> unsubscribeFanClub(String creatorId) => repository.unsubscribeFanClub(creatorId);
  Future<LiveSummary> getSummary(String liveId) => repository.getSummary(liveId);
  Future<AdminLivePage> getAdminLives({int page = 1, int limit = 20, String? status, String? userId, String? search}) =>
      repository.getAdminLives(page: page, limit: limit, status: status, userId: userId, search: search);
  Future<Set<String>> getAdminPermissions() => repository.getAdminPermissions();
  Future<Map<String, dynamic>> getAdminLiveDetail(String liveId) => repository.getAdminLiveDetail(liveId);
  Future<AdminLiveInspection> inspectLive(String liveId) => repository.inspectLive(liveId);
  Future<Map<String, dynamic>> adminEndLive(String liveId) => repository.adminEndLive(liveId);
  Future<Map<String, dynamic>> adminBanLive({required String liveId, required String reason}) => repository.adminBanLive(liveId: liveId, reason: reason);
  Future<Map<String, dynamic>> adminKickGuest({required String liveId, required String userId}) => repository.adminKickGuest(liveId: liveId, userId: userId);
  Future<Map<String, dynamic>> adminBoostLive({required String liveId, int durationMinutes = 60}) => repository.adminBoostLive(liveId: liveId, durationMinutes: durationMinutes);
}
