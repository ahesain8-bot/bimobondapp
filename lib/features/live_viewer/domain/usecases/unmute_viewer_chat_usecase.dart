import 'package:dartz/dartz.dart';

import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../repositories/live_repository.dart';

class UnmuteViewerChatUseCase {
  final LiveRepository _repository;

  UnmuteViewerChatUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required String liveId,
    required String userId,
  }) {
    return _repository.unmuteViewerChat(liveId: liveId, userId: userId);
  }
}
