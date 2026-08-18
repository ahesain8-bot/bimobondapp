import 'package:flutter/foundation.dart';

/// Minimal signal bus: notifies the LIVE feed screen when a host ends a live
/// so it can be removed from the feed immediately (no re-entering the page).
class LiveFeedRefreshBus extends ChangeNotifier {
  LiveFeedRefreshBus._();

  static final LiveFeedRefreshBus instance = LiveFeedRefreshBus._();

  String? _lastEndedLiveId;

  String? get lastEndedLiveId => _lastEndedLiveId;

  /// A live session ended → the feed should remove it immediately.
  void notifyLiveEnded(String liveId) {
    _lastEndedLiveId = liveId;
    notifyListeners();
  }
}
