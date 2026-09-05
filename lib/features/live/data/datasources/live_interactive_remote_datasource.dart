import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import '../../domain/entities/live_interactive.dart';
import '../mappers/live_interactive_mapper.dart';

/// REST contract for the remaining live-room features.
///
/// Every method maps one endpoint documented in `lives/mobile-api.md`; the
/// datasource intentionally does not manufacture fallback data when a request
/// fails, so BLoCs can show the real loading/error state.
class LiveInteractiveRemoteDataSource {
  LiveInteractiveRemoteDataSource({required LiveApiClient apiClient})
    : _api = apiClient;

  final LiveApiClient _api;

  Future<LiveGiftGoal> createGiftGoal({
    required String liveId,
    String? title,
    required int target,
  }) async {
    final response = await _api.post(
      ApiEndpoints.liveGiftGoal(liveId),
      body: {
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        'target': target,
      },
    );
    return LiveInteractiveMapper.giftGoal(response);
  }

  Future<LivePoll> createPoll({
    required String liveId,
    required String question,
    required List<String> options,
  }) async {
    final response = await _api.post(
      ApiEndpoints.livePolls(liveId),
      body: {'question': question, 'options': options},
    );
    return LiveInteractiveMapper.poll(response);
  }

  Future<LivePoll> votePoll({
    required String liveId,
    required String pollId,
    required int optionIndex,
  }) async {
    final response = await _api.post(
      ApiEndpoints.livePollVote(liveId, pollId),
      body: {'optionIndex': optionIndex},
    );
    return LiveInteractiveMapper.poll(response);
  }

  Future<LivePoll> endPoll({
    required String liveId,
    required String pollId,
  }) async {
    final response = await _api.post(ApiEndpoints.livePollEnd(liveId, pollId));
    return LiveInteractiveMapper.poll(response);
  }

  Future<LivePoll?> getActivePoll(String liveId) async {
    final response = await _api.get(ApiEndpoints.livePollsActive(liveId));
    final map = LiveInteractiveMapper.map(response);
    final raw = map['poll'] ??
        map['data'] ??
        (map['id'] == null ? null : map);
    if (raw == null || raw is! Map || raw['id'] == null) return null;
    return LiveInteractiveMapper.poll(raw);
  }

  Future<LiveQA> createQuestion({
    required String liveId,
    required String question,
  }) async {
    final response = await _api.post(
      ApiEndpoints.liveQuestions(liveId),
      body: {'question': question},
    );
    return LiveInteractiveMapper.qa(response);
  }

  Future<List<LiveQA>> listQuestions(String liveId) async {
    final response = await _api.get(ApiEndpoints.liveQuestions(liveId));
    return LiveInteractiveMapper.list(response)
        .map(LiveInteractiveMapper.qa)
        .toList(growable: false);
  }

  Future<LiveQA> pinQuestion({
    required String liveId,
    required String questionId,
  }) async {
    final response = await _api.post(
      ApiEndpoints.liveQuestionPin(liveId, questionId),
    );
    return LiveInteractiveMapper.qa(response);
  }

  Future<LiveQA> answerQuestion({
    required String liveId,
    required String questionId,
  }) async {
    final response = await _api.post(
      ApiEndpoints.liveQuestionAnswer(liveId, questionId),
    );
    return LiveInteractiveMapper.qa(response);
  }

  Future<LiveTreasureBox> createTreasureBox({
    required String liveId,
    required int totalCoins,
    required int maxClaims,
    int? delaySeconds,
  }) async {
    final response = await _api.post(
      ApiEndpoints.liveTreasureBoxes(liveId),
      body: {
        'totalCoins': totalCoins,
        'maxClaims': maxClaims,
        if (delaySeconds != null) 'delaySeconds': delaySeconds,
      },
    );
    return LiveInteractiveMapper.treasureBox(response);
  }

  Future<LiveTreasureClaim> claimTreasureBox({
    required String liveId,
    required String boxId,
  }) async {
    final response = await _api.post(
      ApiEndpoints.liveTreasureBoxClaim(liveId, boxId),
    );
    return LiveInteractiveMapper.treasureClaim(response);
  }

  Future<List<LiveTreasureBox>> listTreasureBoxes(String liveId) async {
    final response = await _api.get(ApiEndpoints.liveTreasureBoxes(liveId));
    return LiveInteractiveMapper.list(response)
        .map(LiveInteractiveMapper.treasureBox)
        .toList(growable: false);
  }

  Future<LiveAuction> createAuction({
    required String liveId,
    required String itemName,
    required int targetPrice,
    String? itemImageUrl,
    int? startingPrice,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    final response = await _api.post(
      ApiEndpoints.liveAuctions(liveId),
      body: {
        'itemName': itemName,
        'targetPrice': targetPrice,
        if (itemImageUrl != null) 'itemImageUrl': itemImageUrl,
        if (startingPrice != null) 'startingPrice': startingPrice,
        if (startedAt != null) 'startedAt': startedAt.toUtc().toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt.toUtc().toIso8601String(),
      },
    );
    return LiveInteractiveMapper.auction(response);
  }

  Future<List<LiveAuction>> listAuctions(
    String liveId, {
    String status = 'ALL',
  }) async {
    final response = await _api.get(
      ApiEndpoints.liveAuctions(liveId),
      query: {'status': status},
    );
    return LiveInteractiveMapper.list(response)
        .map(LiveInteractiveMapper.auction)
        .toList(growable: false);
  }

  Future<List<LiveAuction>> listActiveAuctions(String liveId) async {
    final response = await _api.get(ApiEndpoints.liveActiveAuctions(liveId));
    return LiveInteractiveMapper.list(response)
        .map(LiveInteractiveMapper.auction)
        .toList(growable: false);
  }

  Future<List<LiveAuction>> listGallery(String liveId) async {
    final response = await _api.get(ApiEndpoints.liveGallery(liveId));
    return LiveInteractiveMapper.list(response)
        .map(LiveInteractiveMapper.auction)
        .toList(growable: false);
  }

  Future<LiveAuction> pinAuction({
    required String liveId,
    required String auctionId,
    required bool pinned,
  }) async {
    final response = await _api.patch(
      ApiEndpoints.liveAuctionPin(liveId, auctionId),
      body: {'pinned': pinned},
    );
    return LiveInteractiveMapper.auction(response);
  }

  Future<List<LiveAuction>> reorderAuctions({
    required String liveId,
    required List<String> auctionIds,
  }) async {
    final response = await _api.patch(
      ApiEndpoints.liveAuctionsReorder(liveId),
      body: {'auctionIds': auctionIds},
    );
    return LiveInteractiveMapper.list(response)
        .map(LiveInteractiveMapper.auction)
        .toList(growable: false);
  }

  Future<List<LiveHourlyLeaderboardEntry>> getGlobalHourlyLeaderboard({
    int limit = 20,
  }) async {
    final response = await _api.get(
      ApiEndpoints.livesHourlyLeaderboard,
      query: {'limit': '$limit'},
    );
    return LiveInteractiveMapper.list(response)
        .map(LiveInteractiveMapper.hourlyEntry)
        .toList(growable: false);
  }

  Future<LiveHourlyLeaderboardEntry> getLiveHourlyRank(String liveId) async {
    final response = await _api.get(ApiEndpoints.liveHourlyLeaderboard(liveId));
    return LiveInteractiveMapper.hourlyEntry(response);
  }

  Future<List<LiveGifterLeaderboardEntry>> getLiveGifters(
    String liveId, {
    int limit = 10,
    String window = 'session',
  }) async {
    final response = await _api.get(
      ApiEndpoints.liveGiftersLeaderboard(liveId),
      query: {'limit': '$limit', 'window': window},
    );
    return LiveInteractiveMapper.list(response)
        .map(LiveInteractiveMapper.gifterEntry)
        .toList(growable: false);
  }

  Future<List<LiveLeagueTier>> getLeagues() async {
    final response = await _api.get(ApiEndpoints.livesLeagues);
    final map = LiveInteractiveMapper.map(response);
    final raw = map['tiers'] ?? map['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(LiveInteractiveMapper.leagueTier)
        .toList(growable: false);
  }

  Future<LiveHostLeague> getHostLeague(String userId) async {
    final response = await _api.get(ApiEndpoints.liveHostLeague(userId));
    return LiveInteractiveMapper.hostLeague(response);
  }

  Future<FanClubStatus> getFanClub(String creatorId) async {
    final response = await _api.get(ApiEndpoints.creatorsFanClub(creatorId));
    return FanClubStatus(
      enabled: LiveInteractiveMapper.boolean(response['enabled']),
      name: response['name']?.toString(),
      isMember: LiveInteractiveMapper.boolean(response['isMember']),
    );
  }

  Future<FanClubSubscription> subscribeFanClub(String creatorId) async {
    final response = await _api.post(
      ApiEndpoints.creatorsFanClubSubscribe(creatorId),
    );
    return _subscription(response);
  }

  Future<void> unsubscribeFanClub(String creatorId) async {
    await _api.delete(ApiEndpoints.creatorsFanClubSubscribe(creatorId));
  }

  Future<LiveSummary> getSummary(String liveId) async {
    final response = await _api.get(ApiEndpoints.liveSummary(liveId));
    return LiveInteractiveMapper.summary(response);
  }

  Future<AdminLivePage> getAdminLives({
    int page = 1,
    int limit = 20,
    String? status,
    String? userId,
    String? search,
  }) async {
    final response = await _api.get(
      ApiEndpoints.adminLives,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final map = LiveInteractiveMapper.map(response);
    final meta = LiveInteractiveMapper.map(map['meta']);
    return AdminLivePage(
      items: LiveInteractiveMapper.list(response)
          .map(LiveInteractiveMapper.adminLive)
          .toList(growable: false),
      total: LiveInteractiveMapper.integer(meta['total']),
      page: LiveInteractiveMapper.integer(meta['page'], page),
      limit: LiveInteractiveMapper.integer(meta['limit'], limit),
      totalPages: LiveInteractiveMapper.integer(meta['totalPages']),
    );
  }

  Future<Set<String>> getAdminPermissions() async {
    final response = await _api.get(ApiEndpoints.rbacMe);
    final raw = response['permissions'];
    if (raw is! List) return const <String>{};
    return raw.map((permission) => permission.toString()).toSet();
  }

  Future<Map<String, dynamic>> getAdminLiveDetail(String liveId) {
    return _api.get(ApiEndpoints.liveById(liveId));
  }

  Future<AdminLiveInspection> inspectLive(String liveId) async {
    final responses = await Future.wait<dynamic>([
      getAdminLiveDetail(liveId),
      _api.get(ApiEndpoints.liveGuests(liveId)),
      _api.get(
        ApiEndpoints.liveComments(liveId),
        query: const {'page': '1', 'limit': '100'},
      ),
      _optional(getActivePoll(liveId)),
      _optional(listQuestions(liveId)),
      _optional(listTreasureBoxes(liveId)),
      _optional(getLiveHourlyRank(liveId)),
      _optional(getLiveGifters(liveId)),
      _optional(listAuctions(liveId)),
      _optional(_api.get(ApiEndpoints.liveBattle(liveId))),
    ]);
    final detail = responses[0] as Map<String, dynamic>;
    final rawLive = detail['live'] is Map
        ? LiveInteractiveMapper.map(detail['live'])
        : detail;
    final rawBattle = responses[9] as Map<String, dynamic>?;
    final battle = rawBattle == null ||
            (rawBattle.containsKey('battle') && rawBattle['battle'] == null)
        ? null
        : rawBattle;
    return AdminLiveInspection(
      live: LiveInteractiveMapper.adminLive(rawLive),
      guests: LiveInteractiveMapper.list(responses[1]),
      comments: LiveInteractiveMapper.list(responses[2]),
      poll: responses[3] as LivePoll?,
      questions: (responses[4] as List<LiveQA>?) ?? const [],
      treasureBoxes: (responses[5] as List<LiveTreasureBox>?) ?? const [],
      hourlyRank: responses[6] as LiveHourlyLeaderboardEntry?,
      gifters: (responses[7] as List<LiveGifterLeaderboardEntry>?) ?? const [],
      auctions: (responses[8] as List<LiveAuction>?) ?? const [],
      battle: battle,
    );
  }

  Future<T?> _optional<T>(Future<T> request) async {
    try {
      return await request;
    } catch (_) {
      // The admin contract marks the secondary inspection resources as
      // optional. A missing optional resource must not hide the live itself.
      return null;
    }
  }

  Future<Map<String, dynamic>> adminEndLive(String liveId) {
    return _api.post(ApiEndpoints.adminLiveEnd(liveId));
  }

  Future<Map<String, dynamic>> adminBanLive({
    required String liveId,
    required String reason,
  }) {
    return _api.post(
      ApiEndpoints.adminLiveBan(liveId),
      body: {'reason': reason},
    );
  }

  Future<Map<String, dynamic>> adminKickGuest({
    required String liveId,
    required String userId,
  }) {
    return _api.post(ApiEndpoints.adminLiveKickGuest(liveId, userId));
  }

  Future<Map<String, dynamic>> adminBoostLive({
    required String liveId,
    int durationMinutes = 60,
  }) {
    return _api.post(
      ApiEndpoints.adminLiveBoost(liveId),
      body: {'durationMinutes': durationMinutes},
    );
  }

  FanClubSubscription _subscription(Map<String, dynamic> response) {
    return FanClubSubscription(
      id: response['id']?.toString() ?? '',
      subscriberId: response['subscriberId']?.toString() ?? '',
      creatorId: response['creatorId']?.toString() ?? '',
      status: response['status']?.toString() ?? '',
      startDate: LiveInteractiveMapper.date(response['startDate']),
    );
  }
}
