import '../entities/hourly_ranking_entity.dart';
import '../repositories/ranking_repository.dart';

class WatchLiveHourlyRankUseCase {
  final RankingRepository repository;

  WatchLiveHourlyRankUseCase(this.repository);

  Stream<LiveHourlyRank> call(String liveId) {
    return repository.watchLiveHourlyRank(liveId);
  }
}
