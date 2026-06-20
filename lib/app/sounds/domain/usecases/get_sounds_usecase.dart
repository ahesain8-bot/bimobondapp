import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/domain/repositories/sounds_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetSoundsUseCase implements UseCase<SoundsPageEntity, GetSoundsParams> {
  GetSoundsUseCase(this.repository);

  final SoundsRepository repository;

  @override
  Future<Either<Failure, SoundsPageEntity>> call(GetSoundsParams params) {
    return repository.getSounds(
      page: params.page,
      limit: params.limit,
      search: params.search,
      sort: params.sort,
      creatorId: params.creatorId,
    );
  }
}

class GetSoundsParams {
  const GetSoundsParams({
    this.page = 1,
    this.limit = 20,
    this.search,
    this.sort = SoundSort.trending,
    this.creatorId,
  });

  final int page;
  final int limit;
  final String? search;
  final SoundSort sort;
  final String? creatorId;
}
