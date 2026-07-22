import 'package:bimobondapp/app/stories/data/datasources/stories_remote_data_source.dart';
import 'package:bimobondapp/app/stories/domain/entities/story_entities.dart';
import 'package:bimobondapp/app/stories/domain/repositories/stories_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class StoriesRepositoryImpl implements StoriesRepository {
  StoriesRepositoryImpl({required this.remoteDataSource});

  final StoriesRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, StoryEntity>> createStory(CreateStoryInput input) async {
    try {
      return Right(await remoteDataSource.createStory(input));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, List<StoryRingEntity>>> getRings() async {
    try {
      return Right(await remoteDataSource.getRings());
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, StoryListPageEntity>> getMyStories({
    int page = 1,
    int limit = 20,
    String? status,
    String? privacyStatus,
    bool? activeOnly,
  }) async {
    try {
      return Right(
        await remoteDataSource.getMyStories(
          page: page,
          limit: limit,
          status: status,
          privacyStatus: privacyStatus,
          activeOnly: activeOnly,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, StoryListPageEntity>> getUserStories(
    String userId, {
    int page = 1,
    int limit = 20,
    String? status,
    String? privacyStatus,
    bool? activeOnly,
  }) async {
    try {
      return Right(
        await remoteDataSource.getUserStories(
          userId,
          page: page,
          limit: limit,
          status: status,
          privacyStatus: privacyStatus,
          activeOnly: activeOnly,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, StoryEntity>> getStoryById(String storyId) async {
    try {
      return Right(await remoteDataSource.getStoryById(storyId));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, StoryEntity>> updateStory(
    String storyId, {
    String? description,
    String? privacyStatus,
    bool? allowReplies,
    bool? allowSharing,
    bool? allowReactions,
    String? status,
    int? ttlHours,
  }) async {
    try {
      final body = <String, dynamic>{
        if (description != null) 'description': description,
        if (privacyStatus != null) 'privacyStatus': privacyStatus,
        if (allowReplies != null) 'allowReplies': allowReplies,
        if (allowSharing != null) 'allowSharing': allowSharing,
        if (allowReactions != null) 'allowReactions': allowReactions,
        if (status != null) 'status': status,
        if (ttlHours != null) 'ttlHours': ttlHours,
      };
      return Right(await remoteDataSource.updateStory(storyId, body));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteStory(String storyId) async {
    try {
      await remoteDataSource.deleteStory(storyId);
      return const Right(null);
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, StoryViewRecordResult>> recordView(
    String storyId, {
    int? watchedDuration,
  }) async {
    try {
      return Right(
        await remoteDataSource.recordView(
          storyId,
          watchedDuration: watchedDuration,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, StoryViewersPageEntity>> getViewers(
    String storyId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      return Right(
        await remoteDataSource.getViewers(
          storyId,
          page: page,
          limit: limit,
        ),
      );
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
