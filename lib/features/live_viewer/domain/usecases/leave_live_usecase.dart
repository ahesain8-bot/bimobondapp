import 'package:dartz/dartz.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../repositories/live_repository.dart';

class LeaveLiveUseCase {
  final LiveRepository repository;

  LeaveLiveUseCase(this.repository);

  Future<Either<Failure, void>> call(String liveId) {
    return repository.leaveLive(liveId);
  }
}
