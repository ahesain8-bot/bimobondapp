import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../repositories/like_repository.dart';

class LikeLiveUseCase {
  final LikeRepository repository;

  LikeLiveUseCase(this.repository);

  Future<Either<Failure, void>> call(String liveId, {int burst = 1}) {
    if (burst > 1) {
      return repository.sendBurstLikes(liveId, burst);
    }
    return repository.likeLive(liveId);
  }
}
