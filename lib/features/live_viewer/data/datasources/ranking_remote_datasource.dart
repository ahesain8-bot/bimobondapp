import '../../domain/entities/hourly_ranking_entity.dart';

/// Remote contract for the hourly ranking endpoints (lives/endpoints.md §11).
///
/// Implementations throw the `ApiException` family from
/// `core/network/api_exceptions.dart`; the repository turns those into
/// `Failure`s.
abstract class RankingRemoteDataSource {
  /// `GET /lives/leaderboard/hourly?limit=`
  Future<HourlyLeaderboard> getHourlyLeaderboard({int limit = 20});

  /// `GET /lives/:id/leaderboard/hourly`
  Future<LiveHourlyRank> getLiveHourlyRank(String liveId);
}
