import 'package:dartz/dartz.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../entities/live_entity.dart';
import '../repositories/live_repository.dart';

class GetLiveFeedUseCase {
  final LiveRepository repository;

  GetLiveFeedUseCase(this.repository);

  Future<Either<Failure, List<LiveEntity>>> call({
    int page = 1,
    int limit = 20,
    String? category,
    bool followingOnly = false,
  }) {
    return repository.getLiveFeed(
      page: page,
      limit: limit,
      category: category,
      followingOnly: followingOnly,
    );
  }
}
