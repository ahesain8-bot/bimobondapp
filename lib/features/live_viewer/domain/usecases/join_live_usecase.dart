import 'package:dartz/dartz.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../entities/live_session_entity.dart';
import '../repositories/live_repository.dart';

class JoinLiveUseCase {
  final LiveRepository repository;

  JoinLiveUseCase(this.repository);

  Future<Either<Failure, JoinLiveResult>> call(String liveId) {
    return repository.joinLive(liveId);
  }
}
