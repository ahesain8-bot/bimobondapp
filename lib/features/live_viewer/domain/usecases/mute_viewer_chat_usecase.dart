import 'package:dartz/dartz.dart';

import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../repositories/live_repository.dart';

class MuteViewerChatUseCase {
  final LiveRepository _repository;

  MuteViewerChatUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required String liveId,
    required String userId,
    String? reason,
  }) {
    return _repository.muteViewerChat(
      liveId: liveId,
      userId: userId,
      reason: reason,
    );
  }
}
