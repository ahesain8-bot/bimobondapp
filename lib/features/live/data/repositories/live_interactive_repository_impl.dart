import 'dart:convert';
import '../../../../core/services/live_operation_guard.dart';
import '../../domain/entities/live_interactive.dart';
import '../../domain/repositories/live_interactive_repository.dart';
import '../datasources/live_interactive_remote_datasource.dart';
import '../mappers/live_interactive_mapper.dart';

/// Remote interactive repository backed by the Nest `/lives/:id/*` endpoints.
class LiveInteractiveRepositoryImpl implements LiveInteractiveRepository {
  LiveInteractiveRepositoryImpl({
    required LiveInteractiveRemoteDataSource remote,
    String Function()? userIdProvider,
    LiveOperationGuard? operationGuard,
  }) : _remote = remote,
       _userId = userIdProvider ?? (() => ''),
       _operations = operationGuard ?? LiveOperationGuard.shared;

  final LiveInteractiveRemoteDataSource _remote;
  final String Function() _userId;
  final LiveOperationGuard _operations;

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
  Future<void> endPoll({required String liveId, required String pollId}) async {
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
    return LiveInteractiveMapper.listOf(
      json,
    ).map(LiveInteractiveMapper.qa).toList(growable: false);
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
    return _operations.run(
      userId: _userId,
      liveId: liveId,
      operation: 'treasure-create',
      entityId: jsonEncode([totalCoins, maxClaims, delaySeconds]),
      retainSuccess: false,
      send: () async {
        final json = await _remote.createTreasureBox(
          liveId,
          totalCoins: totalCoins,
          maxClaims: maxClaims,
          delaySeconds: delaySeconds,
        );
        final box = LiveInteractiveMapper.treasureBox(json);
        if (box.id.isEmpty || box.liveId != liveId) {
          throw const FormatException('Unrecognized treasure box response.');
        }
        return box;
      },
    );
  }

  @override
  Future<List<LiveTreasureBox>> listTreasureBoxes(String liveId) async {
    final json = await _remote.treasureBoxes(liveId);
    return LiveInteractiveMapper.listOf(
      json,
    ).map(LiveInteractiveMapper.treasureBox).toList(growable: false);
  }

  @override
  Future<LiveTreasureClaim> claimTreasureBox({
    required String liveId,
    required String boxId,
  }) async {
    return _operations.run(
      userId: _userId,
      liveId: liveId,
      operation: 'treasure-claim',
      entityId: boxId,
      send: () async {
        final json = await _remote.claimTreasureBox(liveId, boxId);
        if (json['boxId'] != boxId ||
            json['coinsWon'] is! int ||
            (json['coinsWon'] as int) < 0) {
          throw const FormatException('Unrecognized treasure claim response.');
        }
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
      },
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
    return LiveInteractiveMapper.listOf(
      json,
    ).map(LiveInteractiveMapper.auction).toList(growable: false);
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
