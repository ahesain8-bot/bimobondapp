import 'package:dartz/dartz.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../entities/hourly_ranking_entity.dart';
import '../repositories/ranking_repository.dart';

class GetHourlyLeaderboardUseCase {
  final RankingRepository repository;

  GetHourlyLeaderboardUseCase(this.repository);

  Future<Either<Failure, HourlyLeaderboard>> call({int limit = 20}) {
    return repository.getHourlyLeaderboard(limit: limit);
  }
}
