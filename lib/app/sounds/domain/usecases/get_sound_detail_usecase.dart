import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetSoundDetailUseCase
    implements UseCase<SoundDetailEntity, GetSoundDetailParams> {
  GetSoundDetailUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, SoundDetailEntity>> call(GetSoundDetailParams params) {
    return repository.getSoundById(params.soundId);
  }
}

class GetSoundDetailParams {
  const GetSoundDetailParams({required this.soundId});

  final String soundId;
}
