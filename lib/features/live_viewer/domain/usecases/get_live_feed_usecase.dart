import 'package:dartz/dartz.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../entities/live_feed_page_result.dart';
import '../repositories/live_repository.dart';

class GetLiveFeedUseCase {
  final LiveRepository repository;

  GetLiveFeedUseCase(this.repository);

  Future<Either<Failure, LiveFeedPageResult>> call({
    int page = 1,
    int limit = 10,
    String? category,
    bool followingOnly = false,
    bool forceRefresh = false,
  }) {
    return repository.getLiveFeed(
      page: page,
      limit: limit,
      category: category,
      followingOnly: followingOnly,
      forceRefresh: forceRefresh,
    );
  }
}
