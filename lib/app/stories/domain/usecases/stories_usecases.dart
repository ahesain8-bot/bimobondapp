import 'package:bimobondapp/app/stories/domain/entities/story_entities.dart';
import 'package:bimobondapp/app/stories/domain/repositories/stories_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class CreateStoryUseCase implements UseCase<StoryEntity, CreateStoryInput> {
  CreateStoryUseCase(this.repository);
  final StoriesRepository repository;

  @override
  Future<Either<Failure, StoryEntity>> call(CreateStoryInput params) {
    return repository.createStory(params);
  }
}

class GetStoryRingsUseCase
    implements UseCase<List<StoryRingEntity>, NoParams> {
  GetStoryRingsUseCase(this.repository);
  final StoriesRepository repository;

  @override
  Future<Either<Failure, List<StoryRingEntity>>> call(NoParams params) {
    return repository.getRings();
  }
}

class GetMyStoriesParams extends Equatable {
  const GetMyStoriesParams({
    this.page = 1,
    this.limit = 20,
    this.status,
    this.privacyStatus,
    this.activeOnly,
  });

  final int page;
  final int limit;
  final String? status;
  final String? privacyStatus;
  final bool? activeOnly;

  @override
  List<Object?> get props => [page, limit, status, privacyStatus, activeOnly];
}

class GetMyStoriesUseCase
    implements UseCase<StoryListPageEntity, GetMyStoriesParams> {
  GetMyStoriesUseCase(this.repository);
  final StoriesRepository repository;

  @override
  Future<Either<Failure, StoryListPageEntity>> call(GetMyStoriesParams params) {
    return repository.getMyStories(
      page: params.page,
      limit: params.limit,
      status: params.status,
      privacyStatus: params.privacyStatus,
      activeOnly: params.activeOnly,
    );
  }
}

class GetUserStoriesParams extends Equatable {
  const GetUserStoriesParams({
    required this.userId,
    this.page = 1,
    this.limit = 20,
    this.status,
    this.privacyStatus,
    this.activeOnly = true,
  });

  final String userId;
  final int page;
  final int limit;
  final String? status;
  final String? privacyStatus;
  final bool? activeOnly;

  @override
  List<Object?> get props =>
      [userId, page, limit, status, privacyStatus, activeOnly];
}

class GetUserStoriesUseCase
    implements UseCase<StoryListPageEntity, GetUserStoriesParams> {
  GetUserStoriesUseCase(this.repository);
  final StoriesRepository repository;

  @override
  Future<Either<Failure, StoryListPageEntity>> call(
    GetUserStoriesParams params,
  ) {
    return repository.getUserStories(
      params.userId,
      page: params.page,
      limit: params.limit,
      status: params.status,
      privacyStatus: params.privacyStatus,
      activeOnly: params.activeOnly,
    );
  }
}

class GetStoryByIdUseCase implements UseCase<StoryEntity, String> {
  GetStoryByIdUseCase(this.repository);
  final StoriesRepository repository;

  @override
  Future<Either<Failure, StoryEntity>> call(String params) {
    return repository.getStoryById(params);
  }
}

class DeleteStoryUseCase implements UseCase<void, String> {
  DeleteStoryUseCase(this.repository);
  final StoriesRepository repository;

  @override
  Future<Either<Failure, void>> call(String params) {
    return repository.deleteStory(params);
  }
}

class RecordStoryViewParams extends Equatable {
  const RecordStoryViewParams({
    required this.storyId,
    this.watchedDuration,
  });

  final String storyId;
  final int? watchedDuration;

  @override
  List<Object?> get props => [storyId, watchedDuration];
}

class RecordStoryViewUseCase
    implements UseCase<StoryViewRecordResult, RecordStoryViewParams> {
  RecordStoryViewUseCase(this.repository);
  final StoriesRepository repository;

  @override
  Future<Either<Failure, StoryViewRecordResult>> call(
    RecordStoryViewParams params,
  ) {
    return repository.recordView(
      params.storyId,
      watchedDuration: params.watchedDuration,
    );
  }
}

class GetStoryViewersParams extends Equatable {
  const GetStoryViewersParams({
    required this.storyId,
    this.page = 1,
    this.limit = 20,
  });

  final String storyId;
  final int page;
  final int limit;

  @override
  List<Object?> get props => [storyId, page, limit];
}

class GetStoryViewersUseCase
    implements UseCase<StoryViewersPageEntity, GetStoryViewersParams> {
  GetStoryViewersUseCase(this.repository);
  final StoriesRepository repository;

  @override
  Future<Either<Failure, StoryViewersPageEntity>> call(
    GetStoryViewersParams params,
  ) {
    return repository.getViewers(
      params.storyId,
      page: params.page,
      limit: params.limit,
    );
  }
}
