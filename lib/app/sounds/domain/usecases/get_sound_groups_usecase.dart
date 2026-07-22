import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetSoundGroupsUseCase
    implements UseCase<List<SoundGroupEntity>, NoParams> {
  GetSoundGroupsUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, List<SoundGroupEntity>>> call(NoParams params) {
    return repository.getGroups();
  }
}
