import '../repositories/live_session_repository.dart';

class LikeLiveSession {
  const LikeLiveSession(this._repository);

  final LiveSessionRepository _repository;

  Future<int> call(String liveId) => _repository.like(liveId);
}
