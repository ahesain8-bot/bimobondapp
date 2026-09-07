import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';

/// HTTP access to the official LIVE games (`lives/live-p3-parity.md` §3).
///
/// Request bodies are exactly the documented ones. The wheel and lucky draw
/// send no play body at all — the server picks.
class LiveGamesRemoteDataSource {
  LiveGamesRemoteDataSource({LiveApiClient? apiClient})
    : _api = apiClient ?? LiveApiClient();

  final LiveApiClient _api;

  /// The server rejects JSON requests with no body, so parameterless POSTs
  /// still send an empty object.
  static const Map<String, dynamic> _emptyBody = <String, dynamic>{};

  /// `GET /lives/games/catalog`.
  Future<Map<String, dynamic>> catalog() {
    return _api.get(ApiEndpoints.liveGamesCatalog);
  }

  /// `GET /lives/:id/games/active` — current game; a quiz answer stays hidden
  /// until the host ends it.
  Future<Map<String, dynamic>> active(String liveId) {
    return _api.get(ApiEndpoints.liveGamesActive(liveId));
  }

  /// `POST /lives/:id/games` — starts the one ACTIVE game.
  ///
  /// QUIZ needs `question`, `options[]` and `correctIndex`; WHEEL needs at
  /// least two `prizes[]`; LUCKY_DRAW needs neither.
  Future<Map<String, dynamic>> start(
    String liveId, {
    required String type,
    String? question,
    List<String>? options,
    int? correctIndex,
    List<String>? prizes,
  }) {
    final wire = type.trim().toUpperCase();
    if (liveId.isEmpty || wire.isEmpty) {
      throw ArgumentError('A live id and a game type are required.');
    }
    if (wire == 'QUIZ') {
      final trimmed =
          options?.map((o) => o.trim()).where((o) => o.isNotEmpty).toList() ??
          const <String>[];
      if (question == null ||
          question.trim().isEmpty ||
          trimmed.length < 2 ||
          correctIndex == null ||
          correctIndex < 0 ||
          correctIndex >= trimmed.length) {
        throw ArgumentError(
          'A quiz needs a question, at least two options and a valid answer.',
        );
      }
      return _api.post(
        ApiEndpoints.liveGames(liveId),
        body: {
          'type': wire,
          'question': question.trim(),
          'options': trimmed,
          'correctIndex': correctIndex,
        },
      );
    }
    if (wire == 'WHEEL') {
      final trimmed =
          prizes?.map((p) => p.trim()).where((p) => p.isNotEmpty).toList() ??
          const <String>[];
      if (trimmed.length < 2) {
        throw ArgumentError('A wheel needs at least two prizes.');
      }
      return _api.post(
        ApiEndpoints.liveGames(liveId),
        body: {'type': wire, 'prizes': trimmed},
      );
    }
    return _api.post(ApiEndpoints.liveGames(liveId), body: {'type': wire});
  }

  /// `POST /lives/:id/games/:gameId/play` — one play per viewer.
  /// [optionIndex] belongs to QUIZ only; the other types send no body.
  Future<Map<String, dynamic>> play(
    String liveId,
    String gameId, {
    int? optionIndex,
  }) {
    if (liveId.isEmpty || gameId.isEmpty) {
      throw ArgumentError('A live id and a game id are required.');
    }
    return _api.post(
      ApiEndpoints.liveGamePlay(liveId, gameId),
      body: optionIndex == null ? _emptyBody : {'optionIndex': optionIndex},
    );
  }

  /// `POST /lives/:id/games/:gameId/end` — host closes the game; the server
  /// reveals the quiz answer and the lucky-draw winner.
  Future<Map<String, dynamic>> end(String liveId, String gameId) {
    if (liveId.isEmpty || gameId.isEmpty) {
      throw ArgumentError('A live id and a game id are required.');
    }
    return _api.post(
      ApiEndpoints.liveGameEnd(liveId, gameId),
      body: _emptyBody,
    );
  }
}
