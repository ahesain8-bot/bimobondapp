import 'package:dartz/dartz.dart';

import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../repositories/live_repository.dart';

class BanViewerUseCase {
  final LiveRepository _repository;

  BanViewerUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required String liveId,
    required String userId,
    String? reason,
  }) {
    return _repository.banViewer(
      liveId: liveId,
      userId: userId,
      reason: reason,
    );
  }
}
