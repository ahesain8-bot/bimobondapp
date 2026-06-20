import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetTrendingSoundsUseCase
    implements UseCase<List<SoundEntity>, GetTrendingSoundsParams> {
  GetTrendingSoundsUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, List<SoundEntity>>> call(
    GetTrendingSoundsParams params,
  ) {
    return repository.getTrending(limit: params.limit);
  }
}

class GetTrendingSoundsParams {
  const GetTrendingSoundsParams({this.limit = 30});

  final int limit;
}
