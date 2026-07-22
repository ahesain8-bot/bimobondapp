import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetSoundSegmentsUseCase
    implements UseCase<SoundsSegmentsPageEntity, GetSoundSegmentsParams> {
  GetSoundSegmentsUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, SoundsSegmentsPageEntity>> call(
    GetSoundSegmentsParams params,
  ) {
    return repository.getSoundSegments(
      soundId: params.soundId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetSoundSegmentsParams {
  const GetSoundSegmentsParams({
    required this.soundId,
    this.page = 1,
    this.limit = 20,
  });

  final String soundId;
  final int page;
  final int limit;
}

class CreateSoundSegmentUseCase
    implements UseCase<SoundSegmentEntity, CreateSoundSegmentParams> {
  CreateSoundSegmentUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, SoundSegmentEntity>> call(
    CreateSoundSegmentParams params,
  ) {
    return repository.createSoundSegment(
      soundId: params.soundId,
      startMs: params.startMs,
      endMs: params.endMs,
      label: params.label,
    );
  }
}

class CreateSoundSegmentParams {
  const CreateSoundSegmentParams({
    required this.soundId,
    required this.startMs,
    required this.endMs,
    this.label,
  });

  final String soundId;
  final int startMs;
  final int endMs;
  final String? label;
}

class GetSoundSegmentDetailUseCase
    implements UseCase<SoundSegmentDetailEntity, GetSoundSegmentDetailParams> {
  GetSoundSegmentDetailUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, SoundSegmentDetailEntity>> call(
    GetSoundSegmentDetailParams params,
  ) {
    return repository.getSegmentById(params.segmentId);
  }
}

class GetSoundSegmentDetailParams {
  const GetSoundSegmentDetailParams({required this.segmentId});

  final String segmentId;
}
