import '../entities/live_session.dart';
import '../repositories/live_session_repository.dart';

class UpdateLiveTitle {
  const UpdateLiveTitle(this._repository);

  final LiveSessionRepository _repository;

  Future<LiveSession> call({
    required String liveId,
    required String title,
    String? coverUrl,
    String? categoryId,
  }) {
    return _repository.updateTitle(
      liveId: liveId,
      title: title,
      coverUrl: coverUrl,
      categoryId: categoryId,
    );
  }
}
