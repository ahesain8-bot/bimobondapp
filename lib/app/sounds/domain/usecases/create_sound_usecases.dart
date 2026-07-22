import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class CreateSoundFromUrlUseCase
    implements UseCase<SoundDetailEntity, CreateSoundFromUrlParams> {
  CreateSoundFromUrlUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, SoundDetailEntity>> call(
    CreateSoundFromUrlParams params,
  ) {
    return repository.createSoundFromUrl(
      audioUrl: params.audioUrl,
      duration: params.duration,
      name: params.name,
      coverUrl: params.coverUrl,
      waveformPeaks: params.waveformPeaks,
    );
  }
}

class CreateSoundFromUrlParams {
  const CreateSoundFromUrlParams({
    required this.audioUrl,
    required this.duration,
    this.name,
    this.coverUrl,
    this.waveformPeaks,
  });

  final String audioUrl;
  final int duration;
  final String? name;
  final String? coverUrl;
  final List<double>? waveformPeaks;
}

class CreateSoundFromOriginalUseCase
    implements UseCase<SoundDetailEntity, CreateSoundFromOriginalParams> {
  CreateSoundFromOriginalUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, SoundDetailEntity>> call(
    CreateSoundFromOriginalParams params,
  ) {
    return repository.createFromOriginal(
      originalSoundId: params.originalSoundId,
      audioUrl: params.audioUrl,
      duration: params.duration,
      name: params.name,
      coverUrl: params.coverUrl,
      waveformPeaks: params.waveformPeaks,
    );
  }
}

class CreateSoundFromOriginalParams {
  const CreateSoundFromOriginalParams({
    required this.originalSoundId,
    required this.audioUrl,
    required this.duration,
    this.name,
    this.coverUrl,
    this.waveformPeaks,
  });

  final String originalSoundId;
  final String audioUrl;
  final int duration;
  final String? name;
  final String? coverUrl;
  final List<double>? waveformPeaks;
}
