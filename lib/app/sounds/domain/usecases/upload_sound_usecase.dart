import 'dart:io';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class UploadSoundUseCase implements UseCase<SoundEntity, UploadSoundParams> {
  UploadSoundUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, SoundEntity>> call(UploadSoundParams params) {
    return repository.uploadSound(
      audio: params.audio,
      duration: params.duration,
      name: params.name,
      cover: params.cover,
    );
  }
}

class UploadSoundParams {
  const UploadSoundParams({
    required this.audio,
    required this.duration,
    this.name,
    this.cover,
  });

  final File audio;
  final int duration;
  final String? name;
  final File? cover;
}
