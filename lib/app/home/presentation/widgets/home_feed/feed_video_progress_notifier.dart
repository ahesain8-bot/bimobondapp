import 'package:flutter/widgets.dart';

/// Tracks playback progress for the active feed video (0.0–1.0).
class FeedVideoProgressNotifier extends ChangeNotifier {
  double _progress = 0;
  bool _isPlaying = false;
  bool _hasDuration = false;

  double get progress => _progress;
  bool get isPlaying => _isPlaying;
  bool get hasDuration => _hasDuration;

  void updateFromPlayback({
    required Duration position,
    required Duration duration,
    required bool isPlaying,
  }) {
    final totalMs = duration.inMilliseconds;
    final nextHasDuration = totalMs > 0;
    final nextProgress = nextHasDuration
        ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;

    if (_hasDuration == nextHasDuration &&
        (_progress - nextProgress).abs() < 0.001 &&
        _isPlaying == isPlaying) {
      return;
    }

    _hasDuration = nextHasDuration;
    _progress = nextProgress;
    _isPlaying = isPlaying;
    if (hasListeners) notifyListeners();
  }

  void reset() {
    if (_progress == 0 && !_isPlaying && !_hasDuration) return;
    _progress = 0;
    _isPlaying = false;
    _hasDuration = false;
    if (hasListeners) notifyListeners();
  }
}

class FeedVideoProgressScope extends InheritedWidget {
  const FeedVideoProgressScope({
    required this.notifier,
    required super.child,
    super.key,
  });

  final FeedVideoProgressNotifier notifier;

  static FeedVideoProgressNotifier? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FeedVideoProgressScope>()
        ?.notifier;
  }

  @override
  bool updateShouldNotify(FeedVideoProgressScope oldWidget) {
    return notifier != oldWidget.notifier;
  }
}
