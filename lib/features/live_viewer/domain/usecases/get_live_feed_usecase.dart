import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/live_entity.dart';
import '../repositories/live_repository.dart';

class GetLiveFeedUseCase {
  final LiveRepository repository;

  GetLiveFeedUseCase(this.repository);

  Future<Either<Failure, List<LiveEntity>>> call({
    int page = 1,
    int limit = 10,
    String? category,
  }) {
    return repository.getLiveFeed(
      page: page,
      limit: limit,
      category: category,
    );
  }
}
