import 'package:dartz/dartz.dart';

import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../repositories/live_repository.dart';

class UnbanViewerUseCase {
  final LiveRepository _repository;

  UnbanViewerUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required String liveId,
    required String userId,
  }) {
    return _repository.unbanViewer(liveId: liveId, userId: userId);
  }
}
