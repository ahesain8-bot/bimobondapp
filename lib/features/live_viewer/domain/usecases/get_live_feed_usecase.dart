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
    String surface = 'feed',
    String? topic,
    double? latitude,
    double? longitude,
    bool audioOnly = false,
  }) {
    if (surface == 'nearby') {
      if (latitude == null || longitude == null) {
        return Future.value(
          const Left(ValidationFailure('Location is required.')),
        );
      }
      return repository.getNearbyFeed(
        page: page,
        limit: limit,
        latitude: latitude,
        longitude: longitude,
        forceRefresh: forceRefresh,
      );
    }
    if (surface == 'audio' || audioOnly) {
      return repository.getAudioFeed(
        page: page,
        limit: limit,
        topic: topic,
        forceRefresh: forceRefresh,
      );
    }
    return repository.getLiveFeed(
      page: page,
      limit: limit,
      category: category,
      followingOnly: followingOnly,
      topic: topic,
      forceRefresh: forceRefresh,
    );
  }
}
