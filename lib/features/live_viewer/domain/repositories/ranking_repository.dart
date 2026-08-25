import 'package:dartz/dartz.dart';

import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../entities/hourly_ranking_entity.dart';

/// Hourly ranking contract (lives/mobile-api.md §19).
abstract class RankingRepository {
  /// `GET /lives/leaderboard/hourly?limit=` — global host ranking for the
  /// current UTC hour. [limit] is the only paging control the backend offers;
  /// there is no page or cursor parameter.
  Future<Either<Failure, HourlyLeaderboard>> getHourlyLeaderboard({
    int limit = 20,
  });

  /// `GET /lives/:id/leaderboard/hourly` — one stream's standing this hour.
  Future<Either<Failure, LiveHourlyRank>> getLiveHourlyRank(String liveId);

  /// Socket `liveHourlyRankUpdated` for [liveId], emitted when gifts move the
  /// stream's position inside the current hour.
  Stream<LiveHourlyRank> watchLiveHourlyRank(String liveId);
}
