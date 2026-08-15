import '../repositories/live_session_repository.dart';

/// Ends an active live broadcasting session.
class EndLiveSession {
  const EndLiveSession(this._repository);

  final LiveSessionRepository _repository;

  Future<void> call(String sessionId) {
    return _repository.endSession(sessionId);
  }
}
