import '../../domain/entities/live_interactive.dart';
import '../../domain/repositories/live_interactive_repository.dart';
import '../datasources/live_interactive_remote_datasource.dart';
import '../mappers/live_interactive_mapper.dart';

/// Remote interactive repository backed by the Nest `/lives/:id/*` endpoints.
class LiveInteractiveRepositoryImpl implements LiveInteractiveRepository {
  LiveInteractiveRepositoryImpl({
    required LiveInteractiveRemoteDataSource remote,
  }) : _remote = remote;

  final LiveInteractiveRemoteDataSource _remote;

  @override
  Future<LiveGiftGoal> createGiftGoal({
    required String liveId,
    String? title,
    required int target,
  }) async {
    final json = await _remote.createGiftGoal(
      liveId,
      title: title,
      target: target,
    );
    return LiveInteractiveMapper.giftGoal(json);
  }

  @override
  Future<LivePoll> createPoll({
    required String liveId,
    required String question,
    required List<String> options,
  }) async {
    final json = await _remote.createPoll(
      liveId,
      question: question,
      options: options,
    );
    return LiveInteractiveMapper.poll(json);
  }

  @override
  Future<LivePoll?> getActivePoll(String liveId) async {
    final json = await _remote.activePoll(liveId);
    final map = LiveInteractiveMapper.asMap(json);
    final raw = map['poll'] ?? map['data'] ?? (map['id'] == null ? null : map);
    if (raw is! Map || raw['id'] == null) return null;
    return LiveInteractiveMapper.poll(raw);
  }

  @override
  Future<LivePoll> votePoll({
    required String liveId,
    required String pollId,
    required int optionIndex,
  }) async {
    final json = await _remote.votePoll(
      liveId,
      pollId,
      optionIndex: optionIndex,
    );
    return LiveInteractiveMapper.poll(json);
  }

  @override
  Future<void> endPoll({
    required String liveId,
    required String pollId,
  }) async {
    await _remote.endPoll(liveId, pollId);
  }

  @override
  Future<LiveQA> createQuestion({
    required String liveId,
    required String question,
  }) async {
    final json = await _remote.createQuestion(liveId, question: question);
    return LiveInteractiveMapper.qa(json);
  }

  @override
  Future<List<LiveQA>> listQuestions(String liveId) async {
    final json = await _remote.questions(liveId);
    return LiveInteractiveMapper.listOf(json)
        .map(LiveInteractiveMapper.qa)
        .toList(growable: false);
  }

  @override
  Future<LiveQA> pinQuestion({
    required String liveId,
    required String questionId,
  }) async {
    final json = await _remote.pinQuestion(liveId, questionId);
    return LiveInteractiveMapper.qa(json);
  }

  @override
  Future<LiveQA> answerQuestion({
    required String liveId,
    required String questionId,
  }) async {
    final json = await _remote.answerQuestion(liveId, questionId);
    return LiveInteractiveMapper.qa(json);
  }

  @override
  Future<LiveTreasureBox> createTreasureBox({
    required String liveId,
    required int totalCoins,
    required int maxClaims,
    required int delaySeconds,
  }) async {
    final json = await _remote.createTreasureBox(
      liveId,
      totalCoins: totalCoins,
      maxClaims: maxClaims,
      delaySeconds: delaySeconds,
    );
    return LiveInteractiveMapper.treasureBox(json);
  }

  @override
  Future<List<LiveTreasureBox>> listTreasureBoxes(String liveId) async {
    final json = await _remote.treasureBoxes(liveId);
    return LiveInteractiveMapper.listOf(json)
        .map(LiveInteractiveMapper.treasureBox)
        .toList(growable: false);
  }

  @override
  Future<LiveTreasureClaim> claimTreasureBox({
    required String liveId,
    required String boxId,
  }) async {
    final json = await _remote.claimTreasureBox(liveId, boxId);
    final claim = LiveInteractiveMapper.treasureClaim(json);
    // A bare claim response omits `boxId`; the caller still needs to know
    // which box it belongs to in order to update the list.
    return claim.boxId.isNotEmpty
        ? claim
        : LiveTreasureClaim(
            boxId: boxId,
            coinsWon: claim.coinsWon,
            claimedCount: claim.claimedCount,
            remainingCoins: claim.remainingCoins,
          );
  }

  @override
  Future<LiveAuction> createAuction({
    required String liveId,
    required String itemName,
    required int targetPrice,
    int? startingPrice,
  }) async {
    final json = await _remote.createAuction(
      liveId,
      itemName: itemName,
      targetPrice: targetPrice,
      startingPrice: startingPrice,
    );
    return LiveInteractiveMapper.auction(json);
  }

  @override
  Future<List<LiveAuction>> listActiveAuctions(String liveId) async {
    final json = await _remote.activeAuctions(liveId);
    return LiveInteractiveMapper.listOf(json)
        .map(LiveInteractiveMapper.auction)
        .toList(growable: false);
  }

  @override
  Future<LiveAuction> pinAuction({
    required String liveId,
    required String auctionId,
    required bool pinned,
  }) async {
    final json = await _remote.pinAuction(liveId, auctionId, pinned: pinned);
    return LiveInteractiveMapper.auction(json);
  }

  @override
  Future<LiveSummary> getSummary(String liveId) async {
    final json = await _remote.summary(liveId);
    return LiveInteractiveMapper.summary(json);
  }
}
