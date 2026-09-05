import '../entities/live_interactive.dart';

/// Host and viewer actions for the interactive live-room features.
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
  Future<LivePoll?> getActivePoll(String liveId);
  Future<LivePoll> votePoll({
    required String liveId,
    required String pollId,
    required int optionIndex,
  });
  Future<void> endPoll({required String liveId, required String pollId});

  Future<LiveQA> createQuestion({
    required String liveId,
    required String question,
  });
  Future<List<LiveQA>> listQuestions(String liveId);
  Future<LiveQA> pinQuestion({
    required String liveId,
    required String questionId,
  });
  Future<LiveQA> answerQuestion({
    required String liveId,
    required String questionId,
  });

  Future<LiveTreasureBox> createTreasureBox({
    required String liveId,
    required int totalCoins,
    required int maxClaims,
    required int delaySeconds,
  });
  Future<List<LiveTreasureBox>> listTreasureBoxes(String liveId);
  Future<LiveTreasureClaim> claimTreasureBox({
    required String liveId,
    required String boxId,
  });

  Future<LiveAuction> createAuction({
    required String liveId,
    required String itemName,
    required int targetPrice,
    int? startingPrice,
  });
  Future<List<LiveAuction>> listActiveAuctions(String liveId);
  Future<LiveAuction> pinAuction({
    required String liveId,
    required String auctionId,
    required bool pinned,
  });

  Future<LiveSummary> getSummary(String liveId);
}
