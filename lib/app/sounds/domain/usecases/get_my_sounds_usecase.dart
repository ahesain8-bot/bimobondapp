import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetMySoundsUseCase
    implements UseCase<SoundsPageEntity, GetMySoundsParams> {
  GetMySoundsUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, SoundsPageEntity>> call(GetMySoundsParams params) {
    return repository.getMySounds(page: params.page, limit: params.limit);
  }
}

class GetMySoundsParams {
  const GetMySoundsParams({this.page = 1, this.limit = 20});

  final int page;
  final int limit;
}
