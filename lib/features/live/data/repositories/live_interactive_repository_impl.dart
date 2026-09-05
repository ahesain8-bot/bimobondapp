import '../../domain/entities/live_interactive.dart';
import '../../domain/repositories/live_interactive_repository.dart';
import '../datasources/live_interactive_remote_datasource.dart';

class LiveInteractiveRepositoryImpl implements LiveInteractiveRepository {
  LiveInteractiveRepositoryImpl({required LiveInteractiveRemoteDataSource remote})
    : _remote = remote;

  final LiveInteractiveRemoteDataSource _remote;

  @override
  Future<LiveGiftGoal> createGiftGoal({required String liveId, String? title, required int target}) =>
      _remote.createGiftGoal(liveId: liveId, title: title, target: target);

  @override
  Future<LivePoll> createPoll({required String liveId, required String question, required List<String> options}) =>
      _remote.createPoll(liveId: liveId, question: question, options: options);

  @override
  Future<LivePoll> votePoll({required String liveId, required String pollId, required int optionIndex}) =>
      _remote.votePoll(liveId: liveId, pollId: pollId, optionIndex: optionIndex);

  @override
  Future<LivePoll> endPoll({required String liveId, required String pollId}) =>
      _remote.endPoll(liveId: liveId, pollId: pollId);

  @override
  Future<LivePoll?> getActivePoll(String liveId) => _remote.getActivePoll(liveId);

  @override
  Future<LiveQA> createQuestion({required String liveId, required String question}) =>
      _remote.createQuestion(liveId: liveId, question: question);

  @override
  Future<List<LiveQA>> listQuestions(String liveId) => _remote.listQuestions(liveId);

  @override
  Future<LiveQA> pinQuestion({required String liveId, required String questionId}) =>
      _remote.pinQuestion(liveId: liveId, questionId: questionId);

  @override
  Future<LiveQA> answerQuestion({required String liveId, required String questionId}) =>
      _remote.answerQuestion(liveId: liveId, questionId: questionId);

  @override
  Future<LiveTreasureBox> createTreasureBox({required String liveId, required int totalCoins, required int maxClaims, int? delaySeconds}) =>
      _remote.createTreasureBox(liveId: liveId, totalCoins: totalCoins, maxClaims: maxClaims, delaySeconds: delaySeconds);

  @override
  Future<LiveTreasureClaim> claimTreasureBox({required String liveId, required String boxId}) =>
      _remote.claimTreasureBox(liveId: liveId, boxId: boxId);

  @override
  Future<List<LiveTreasureBox>> listTreasureBoxes(String liveId) => _remote.listTreasureBoxes(liveId);

  @override
  Future<LiveAuction> createAuction({required String liveId, required String itemName, required int targetPrice, String? itemImageUrl, int? startingPrice, DateTime? startedAt, DateTime? endedAt}) =>
      _remote.createAuction(liveId: liveId, itemName: itemName, targetPrice: targetPrice, itemImageUrl: itemImageUrl, startingPrice: startingPrice, startedAt: startedAt, endedAt: endedAt);

  @override
  Future<List<LiveAuction>> listAuctions(String liveId, {String status = 'ALL'}) => _remote.listAuctions(liveId, status: status);

  @override
  Future<List<LiveAuction>> listActiveAuctions(String liveId) => _remote.listActiveAuctions(liveId);

  @override
  Future<List<LiveAuction>> listGallery(String liveId) => _remote.listGallery(liveId);

  @override
  Future<LiveAuction> pinAuction({required String liveId, required String auctionId, required bool pinned}) =>
      _remote.pinAuction(liveId: liveId, auctionId: auctionId, pinned: pinned);

  @override
  Future<List<LiveAuction>> reorderAuctions({required String liveId, required List<String> auctionIds}) =>
      _remote.reorderAuctions(liveId: liveId, auctionIds: auctionIds);

  @override
  Future<List<LiveHourlyLeaderboardEntry>> getGlobalHourlyLeaderboard({int limit = 20}) =>
      _remote.getGlobalHourlyLeaderboard(limit: limit);

  @override
  Future<LiveHourlyLeaderboardEntry> getLiveHourlyRank(String liveId) => _remote.getLiveHourlyRank(liveId);

  @override
  Future<List<LiveGifterLeaderboardEntry>> getLiveGifters(String liveId, {int limit = 10, String window = 'session'}) =>
      _remote.getLiveGifters(liveId, limit: limit, window: window);

  @override
  Future<List<LiveLeagueTier>> getLeagues() => _remote.getLeagues();

  @override
  Future<LiveHostLeague> getHostLeague(String userId) => _remote.getHostLeague(userId);

  @override
  Future<FanClubStatus> getFanClub(String creatorId) => _remote.getFanClub(creatorId);

  @override
  Future<FanClubSubscription> subscribeFanClub(String creatorId) => _remote.subscribeFanClub(creatorId);

  @override
  Future<void> unsubscribeFanClub(String creatorId) => _remote.unsubscribeFanClub(creatorId);

  @override
  Future<LiveSummary> getSummary(String liveId) => _remote.getSummary(liveId);

  @override
  Future<AdminLivePage> getAdminLives({int page = 1, int limit = 20, String? status, String? userId, String? search}) =>
      _remote.getAdminLives(page: page, limit: limit, status: status, userId: userId, search: search);

  @override
  Future<Set<String>> getAdminPermissions() => _remote.getAdminPermissions();

  @override
  Future<Map<String, dynamic>> getAdminLiveDetail(String liveId) => _remote.getAdminLiveDetail(liveId);

  @override
  Future<AdminLiveInspection> inspectLive(String liveId) => _remote.inspectLive(liveId);

  @override
  Future<Map<String, dynamic>> adminEndLive(String liveId) => _remote.adminEndLive(liveId);

  @override
  Future<Map<String, dynamic>> adminBanLive({required String liveId, required String reason}) =>
      _remote.adminBanLive(liveId: liveId, reason: reason);

  @override
  Future<Map<String, dynamic>> adminKickGuest({required String liveId, required String userId}) =>
      _remote.adminKickGuest(liveId: liveId, userId: userId);

  @override
  Future<Map<String, dynamic>> adminBoostLive({required String liveId, int durationMinutes = 60}) =>
      _remote.adminBoostLive(liveId: liveId, durationMinutes: durationMinutes);
}
