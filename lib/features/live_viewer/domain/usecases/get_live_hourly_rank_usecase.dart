import 'package:dartz/dartz.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../entities/hourly_ranking_entity.dart';
import '../repositories/ranking_repository.dart';

class GetLiveHourlyRankUseCase {
  final RankingRepository repository;

  GetLiveHourlyRankUseCase(this.repository);

  Future<Either<Failure, LiveHourlyRank>> call(String liveId) {
    return repository.getLiveHourlyRank(liveId);
  }
}
