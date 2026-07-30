/// In-memory follow state for feed post authors (avoids badge flash on scroll).
class FeedAuthorFollowCache {
  FeedAuthorFollowCache._();

  static final FeedAuthorFollowCache instance = FeedAuthorFollowCache._();

  final Map<String, bool> _values = {};
  final Map<String, Future<bool>> _inFlight = {};

  bool? lookup(String userId) {
    if (userId.isEmpty) return null;
    return _values[userId];
  }

  void put(String userId, bool isFollowing) {
    if (userId.isEmpty) return;
    _values[userId] = isFollowing;
  }

  Future<bool>? inFlightFor(String userId) {
    if (userId.isEmpty) return null;
    return _inFlight[userId];
  }

  Future<bool> trackInFlight(String userId, Future<bool> future) {
    _inFlight[userId] = future;
    return future.whenComplete(() => _inFlight.remove(userId));
  }

  void clear() => _values.clear();
}
