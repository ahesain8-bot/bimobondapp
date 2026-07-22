import 'package:bimobondapp/app/stories/domain/entities/story_entities.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class StoriesRepository {
  Future<Either<Failure, StoryEntity>> createStory(CreateStoryInput input);

  Future<Either<Failure, List<StoryRingEntity>>> getRings();

  Future<Either<Failure, StoryListPageEntity>> getMyStories({
    int page = 1,
    int limit = 20,
    String? status,
    String? privacyStatus,
    bool? activeOnly,
  });

  Future<Either<Failure, StoryListPageEntity>> getUserStories(
    String userId, {
    int page = 1,
    int limit = 20,
    String? status,
    String? privacyStatus,
    bool? activeOnly,
  });

  Future<Either<Failure, StoryEntity>> getStoryById(String storyId);

  Future<Either<Failure, StoryEntity>> updateStory(
    String storyId, {
    String? description,
    String? privacyStatus,
    bool? allowReplies,
    bool? allowSharing,
    bool? allowReactions,
    String? status,
    int? ttlHours,
  });

  Future<Either<Failure, void>> deleteStory(String storyId);

  Future<Either<Failure, StoryViewRecordResult>> recordView(
    String storyId, {
    int? watchedDuration,
  });

  Future<Either<Failure, StoryViewersPageEntity>> getViewers(
    String storyId, {
    int page = 1,
    int limit = 20,
  });
}
