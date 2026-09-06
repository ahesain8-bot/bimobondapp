import '../repositories/live_session_repository.dart';

/// Host pause / resume (`POST /lives/:id/pause` and `/resume`).
///
/// Status stays `LIVE`; LiveKit is not torn down. The returned value is the
/// server `paused` flag from `{ paused, pausedAt }`.
class PauseLiveSession {
  const PauseLiveSession(this._repository);

  final LiveSessionRepository _repository;

  Future<bool> pause(String liveId) => _repository.pauseLive(liveId);

  Future<bool> resume(String liveId) => _repository.resumeLive(liveId);
}
