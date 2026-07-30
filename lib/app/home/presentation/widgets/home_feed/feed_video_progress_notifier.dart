import 'dart:async';

import 'package:flutter/widgets.dart';

typedef FeedVideoSeekHandler =
    Future<void> Function(Duration position, {required bool resumePlayback});

/// Tracks playback progress for the active feed video (0.0–1.0).
class FeedVideoProgressNotifier extends ChangeNotifier {
  double _progress = 0;
  bool _isPlaying = false;
  bool _hasDuration = false;
  Duration _duration = Duration.zero;
  bool _scrubbing = false;
  double? _scrubProgress;
  double _progressBeforeScrub = 0;
  bool _videoLoading = false;

  /// Bumped on each feed page change so stale players ignore loading updates.
  int _handoffGeneration = 0;

  Object? _seekOwner;
  FeedVideoSeekHandler? _seekHandler;

  int get handoffGeneration => _handoffGeneration;

  double get progress => _progress;
  bool get isPlaying => _isPlaying;
  bool get hasDuration => _hasDuration;
  Duration get duration => _duration;
  bool get scrubbing => _scrubbing;
  bool get canSeek => _seekHandler != null && _hasDuration;
  bool get videoLoading => _videoLoading;

  void setVideoLoading(bool loading, {int? handoff}) {
    if (handoff != null && handoff != _handoffGeneration) return;
    // Keep the scrub track visible while the finger is down — buffering from
    // in-progress seeks must not flash the loading line over the bar.
    if (_scrubbing && loading) return;
    if (_videoLoading == loading) return;
    _videoLoading = loading;
    if (hasListeners) notifyListeners();
  }

  /// Progress shown in the bar (follows finger while dragging).
  double get displayProgress {
    if (_scrubbing && _scrubProgress != null) {
      return _scrubProgress!.clamp(0.0, 1.0);
    }
    return _progress;
  }

  void bindSeekHandler(Object owner, FeedVideoSeekHandler handler) {
    _seekOwner = owner;
    _seekHandler = handler;
  }

  void unbindSeekHandler(Object owner) {
    if (_seekOwner != owner) return;
    _seekOwner = null;
    _seekHandler = null;
  }

  void updateFromPlayback({
    required Duration position,
    required Duration duration,
    required bool isPlaying,
  }) {
    if (_scrubbing) return;

    final totalMs = duration.inMilliseconds;
    final nextHasDuration = totalMs > 0;
    final nextProgress = nextHasDuration
        ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;

    if (_hasDuration == nextHasDuration &&
        _duration == duration &&
        (_progress - nextProgress).abs() < 0.001 &&
        _isPlaying == isPlaying) {
      return;
    }

    _hasDuration = nextHasDuration;
    _duration = duration;
    _progress = nextProgress;
    _isPlaying = isPlaying;
    if (hasListeners) notifyListeners();
  }

  void beginScrub(double progress) {
    _progressBeforeScrub = _progress;
    _scrubbing = true;
    _scrubProgress = progress.clamp(0.0, 1.0);
    if (hasListeners) notifyListeners();
    unawaited(seekToProgress(_scrubProgress!, resumePlayback: false));
  }

  void updateScrub(double progress) {
    if (!_scrubbing) return;
    _scrubProgress = progress.clamp(0.0, 1.0);
    if (hasListeners) notifyListeners();
    unawaited(seekToProgress(_scrubProgress!, resumePlayback: false));
  }

  Future<void> endScrub({required bool commit}) async {
    final target =
        (commit ? (_scrubProgress ?? _progress) : _progressBeforeScrub).clamp(
          0.0,
          1.0,
        );
    _scrubbing = false;
    _scrubProgress = null;
    _progress = target;
    if (hasListeners) notifyListeners();
    await seekToProgress(target, resumePlayback: true);
  }

  Future<void> seekToProgress(
    double progress, {
    required bool resumePlayback,
  }) async {
    final handler = _seekHandler;
    final totalMs = _duration.inMilliseconds;
    if (handler == null || totalMs <= 0) return;
    final ms = (progress.clamp(0.0, 1.0) * totalMs).round();
    await handler(Duration(milliseconds: ms), resumePlayback: resumePlayback);
  }

  void reset() {
    _handoffGeneration++;

    final dirty = _progress != 0 ||
        _isPlaying ||
        _hasDuration ||
        _scrubbing ||
        _videoLoading ||
        _duration != Duration.zero ||
        _seekOwner != null;

    _progress = 0;
    _isPlaying = false;
    _hasDuration = false;
    _duration = Duration.zero;
    _scrubbing = false;
    _scrubProgress = null;
    _progressBeforeScrub = 0;
    _videoLoading = false;
    _seekOwner = null;
    _seekHandler = null;

    if (dirty && hasListeners) notifyListeners();
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
