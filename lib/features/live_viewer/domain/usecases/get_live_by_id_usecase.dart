import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/live_entity.dart';
import '../repositories/live_repository.dart';

class GetLiveByIdUseCase {
  const GetLiveByIdUseCase(this.repository);

  final LiveRepository repository;

  Future<Either<Failure, LiveEntity>> call(String liveId) {
    return repository.getLiveById(liveId);
  }
}
