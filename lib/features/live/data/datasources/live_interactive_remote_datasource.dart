import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';

/// HTTP access to the interactive live-room endpoints: gift goal, polls, Q&A,
/// treasure boxes, auctions and the session summary (lives/mobile-api.md).
///
/// Failures surface as [LiveApiClient] exceptions so the BLoC can show a real
/// error state instead of a fabricated empty result.
class LiveInteractiveRemoteDataSource {
  LiveInteractiveRemoteDataSource({LiveApiClient? apiClient})
    : _api = apiClient ?? LiveApiClient();

  final LiveApiClient _api;

  /// The server rejects `Content-Type: application/json` requests that carry
  /// no body, so parameterless POSTs still send an empty object.
  static const Map<String, dynamic> _emptyBody = <String, dynamic>{};

  Future<Map<String, dynamic>> createGiftGoal(
    String liveId, {
    String? title,
    required int target,
  }) {
    return _api.post(
      ApiEndpoints.liveGiftGoal(liveId),
      body: {
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        'target': target,
      },
    );
  }

  Future<Map<String, dynamic>> createPoll(
    String liveId, {
    required String question,
    required List<String> options,
  }) {
    return _api.post(
      ApiEndpoints.livePolls(liveId),
      body: {'question': question, 'options': options},
    );
  }

  Future<Map<String, dynamic>> activePoll(String liveId) {
    return _api.get(ApiEndpoints.livePollsActive(liveId));
  }

  Future<Map<String, dynamic>> votePoll(
    String liveId,
    String pollId, {
    required int optionIndex,
  }) {
    return _api.post(
      ApiEndpoints.livePollVote(liveId, pollId),
      body: {'optionIndex': optionIndex},
    );
  }

  Future<Map<String, dynamic>> endPoll(String liveId, String pollId) {
    return _api.post(
      ApiEndpoints.livePollEnd(liveId, pollId),
      body: _emptyBody,
    );
  }

  Future<Map<String, dynamic>> createQuestion(
    String liveId, {
    required String question,
  }) {
    return _api.post(
      ApiEndpoints.liveQuestions(liveId),
      body: {'question': question},
    );
  }

  Future<Map<String, dynamic>> questions(String liveId) {
    return _api.get(ApiEndpoints.liveQuestions(liveId));
  }

  Future<Map<String, dynamic>> pinQuestion(String liveId, String questionId) {
    return _api.post(
      ApiEndpoints.liveQuestionPin(liveId, questionId),
      body: _emptyBody,
    );
  }

  Future<Map<String, dynamic>> answerQuestion(
    String liveId,
    String questionId,
  ) {
    return _api.post(
      ApiEndpoints.liveQuestionAnswer(liveId, questionId),
      body: _emptyBody,
    );
  }

  Future<Map<String, dynamic>> createTreasureBox(
    String liveId, {
    required int totalCoins,
    required int maxClaims,
    required int delaySeconds,
  }) {
    return _api.post(
      ApiEndpoints.liveTreasureBoxes(liveId),
      body: {
        'totalCoins': totalCoins,
        'maxClaims': maxClaims,
        'delaySeconds': delaySeconds,
      },
    );
  }

  Future<Map<String, dynamic>> treasureBoxes(String liveId) {
    return _api.get(ApiEndpoints.liveTreasureBoxes(liveId));
  }

  Future<Map<String, dynamic>> claimTreasureBox(String liveId, String boxId) {
    return _api.post(
      ApiEndpoints.liveTreasureBoxClaim(liveId, boxId),
      body: _emptyBody,
    );
  }

  Future<Map<String, dynamic>> createAuction(
    String liveId, {
    required String itemName,
    required int targetPrice,
    int? startingPrice,
  }) {
    return _api.post(
      ApiEndpoints.liveAuctions(liveId),
      body: {
        'itemName': itemName,
        'targetPrice': targetPrice,
        'startingPrice': ?startingPrice,
      },
    );
  }

  Future<Map<String, dynamic>> activeAuctions(String liveId) {
    return _api.get(ApiEndpoints.liveActiveAuctions(liveId));
  }

  Future<Map<String, dynamic>> pinAuction(
    String liveId,
    String auctionId, {
    required bool pinned,
  }) {
    return _api.patch(
      ApiEndpoints.liveAuctionPin(liveId, auctionId),
      body: {'pinned': pinned},
    );
  }

  Future<Map<String, dynamic>> summary(String liveId) {
    return _api.get(ApiEndpoints.liveSummary(liveId));
  }
}
