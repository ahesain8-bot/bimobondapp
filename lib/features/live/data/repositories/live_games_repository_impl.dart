import '../../domain/entities/live_game.dart';
import '../../domain/repositories/live_games_repository.dart';
import '../datasources/live_games_remote_datasource.dart';
import '../mappers/live_game_mapper.dart';

/// Remote games repository backed by `/lives/:id/games`.
///
/// A mutation returns whatever the server sent back. When the response carries
/// no recognisable game the caller re-reads `active` instead of assuming a
/// local outcome.
class LiveGamesRepositoryImpl implements LiveGamesRepository {
  LiveGamesRepositoryImpl({required LiveGamesRemoteDataSource remote})
    : _remote = remote;

  final LiveGamesRemoteDataSource _remote;

  @override
  Future<List<LiveGameCatalogEntry>> catalog() async {
    return LiveGameMapper.catalogFromJson(await _remote.catalog());
  }

  @override
  Future<LiveGame?> activeGame(String liveId) async {
    if (liveId.isEmpty) return null;
    return LiveGameMapper.gameFromJson(await _remote.active(liveId));
  }

  @override
  Future<LiveGame?> startGame(
    String liveId, {
    required LiveGameType type,
    String? question,
    List<String>? options,
    int? correctIndex,
    List<String>? prizes,
  }) async {
    if (type == LiveGameType.unknown) {
      throw ArgumentError('This build does not support that game type.');
    }
    final payload = await _remote.start(
      liveId,
      type: type.wireValue,
      question: question,
      options: options,
      correctIndex: correctIndex,
      prizes: prizes,
    );
    return LiveGameMapper.gameFromJson(payload) ?? await activeGame(liveId);
  }

  @override
  Future<LiveGame?> play(
    String liveId, {
    required String gameId,
    int? optionIndex,
  }) async {
    final payload = await _remote.play(
      liveId,
      gameId,
      optionIndex: optionIndex,
    );
    return LiveGameMapper.gameFromJson(payload) ?? await activeGame(liveId);
  }

  @override
  Future<LiveGame?> endGame(String liveId, {required String gameId}) async {
    final payload = await _remote.end(liveId, gameId);
    return LiveGameMapper.gameFromJson(payload) ?? await activeGame(liveId);
  }
}
