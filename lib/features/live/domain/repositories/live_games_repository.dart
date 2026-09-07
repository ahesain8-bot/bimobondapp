import '../entities/live_game.dart';

/// Official in-LIVE games (`lives/live-p3-parity.md` §3).
///
/// Every result is the server's: the wheel prize, the lucky-draw winner and
/// the moment a quiz answer is revealed.
abstract interface class LiveGamesRepository {
  /// `GET /lives/games/catalog`.
  Future<List<LiveGameCatalogEntry>> catalog();

  /// `GET /lives/:id/games/active` — null when no game is running.
  Future<LiveGame?> activeGame(String liveId);

  /// `POST /lives/:id/games` — host starts the one ACTIVE game.
  Future<LiveGame?> startGame(
    String liveId, {
    required LiveGameType type,
    String? question,
    List<String>? options,
    int? correctIndex,
    List<String>? prizes,
  });

  /// `POST /lives/:id/games/:gameId/play` — one play per viewer.
  Future<LiveGame?> play(
    String liveId, {
    required String gameId,
    int? optionIndex,
  });

  /// `POST /lives/:id/games/:gameId/end` — host closes the game.
  Future<LiveGame?> endGame(String liveId, {required String gameId});
}
