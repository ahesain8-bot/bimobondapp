import '../../../live/data/mappers/live_host_extras_mapper.dart';
import '../../../live/domain/entities/live_host_league.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import '../../domain/entities/hourly_ranking_entity.dart';
import '../mappers/hourly_ranking_mapper.dart';
import 'ranking_remote_datasource.dart';

/// Real REST implementation of [RankingRemoteDataSource].
///
/// Both endpoints are auth-optional (lives/mobile-api.md §19), so the bearer
/// token is sent when the viewer is signed in but a missing token is not an
/// error — the ranking is public.
class HttpRankingRemoteDataSource implements RankingRemoteDataSource {
  HttpRankingRemoteDataSource({required LiveApiClient apiClient})
    : _api = apiClient;

  final LiveApiClient _api;

  @override
  Future<List<LiveLeagueTier>> loadLeagueTiers() async =>
      LiveHostExtrasMapper.leagueTiersFromJson(await _api.get(ApiEndpoints.livesLeagues));

  @override
  Future<LiveHostLeague?> loadHostLeague(String userId) async {
    final league = LiveHostExtrasMapper.hostLeagueFromJson(await _api.get(ApiEndpoints.liveHostLeague(userId)));
    if (league?.userId != userId) throw const FormatException('Invalid host league identity.');
    return league;
  }

  @override
  Future<HourlyLeaderboard> getHourlyLeaderboard({int limit = 20}) async {
    final payload = await _api.get(
      ApiEndpoints.livesHourlyLeaderboard,
      query: {'limit': '$limit'},
    );
    return HourlyRankingMapper.leaderboardFromPayload(payload);
  }

  @override
  Future<LiveHourlyRank> getLiveHourlyRank(String liveId) async {
    final payload = await _api.get(ApiEndpoints.liveHourlyLeaderboard(liveId));
    return HourlyRankingMapper.liveRankFromPayload(
      payload,
      fallbackLiveId: liveId,
    );
  }
}
