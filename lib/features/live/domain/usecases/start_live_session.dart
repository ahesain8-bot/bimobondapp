import '../entities/live_session.dart';
import '../repositories/live_session_repository.dart';

/// Creates + starts a host live session on the backend.
class StartLiveSession {
  const StartLiveSession(this._repository);

  final LiveSessionRepository _repository;

  Future<LiveSession> call({required String title}) {
    return _repository.startHostSession(title: title);
  }
}
