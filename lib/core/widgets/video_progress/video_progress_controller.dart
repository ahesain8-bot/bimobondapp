import 'dart:async';
import 'package:flutter/foundation.dart';

typedef VideoSeekHandler =
    Future<void> Function(Duration position, {required bool resumePlayback});

enum VideoPlaybackState { idle, playing, paused, buffering, seeking, completed }

/// High-performance controller for video progress tracking, buffering, and seeking.
/// Operates independently from the video UI to prevent unnecessary screen rebuilds.
///
/// Exposes production-ready TikTok-style API:
/// - [play], [pause], [seek], [replay]
/// - [progress], [bufferedProgress] (0.0 – 1.0)
/// - [isDragging], [isBuffering], [isCompleted], [playbackState]
class VideoProgressController extends ChangeNotifier {
  double _progress = 0.0;
  double _bufferedProgress = 0.0;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isDragging = false;
  double? _dragProgress;
  double _progressBeforeDrag = 0.0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _hasDuration = false;
  int _handoffGeneration = 0;
  bool _wasPlayingBeforeDrag = false;
  Duration? _dragPosition;

  Object? _seekOwner;
  VideoSeekHandler? _seekHandler;
  VoidCallback? _playHandler;
  VoidCallback? _pauseHandler;
  VoidCallback? _replayHandler;

  int get handoffGeneration => _handoffGeneration;

  double get progress => _isDragging && _dragProgress != null
      ? _dragProgress!.clamp(0.0, 1.0)
      : _progress;

  double get bufferedProgress => _bufferedProgress.clamp(0.0, 1.0);
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isDragging => _isDragging;
  bool get hasDuration => _hasDuration;
  Duration get duration => _duration;
  Duration get position =>
      _isDragging && _dragPosition != null ? _dragPosition! : _position;
  bool get canSeek => _seekHandler != null && _hasDuration;

  bool get isCompleted =>
      _hasDuration && _progress >= 0.999 && !_isDragging && !_isPlaying;

  VideoPlaybackState get playbackState {
    if (_isDragging) return VideoPlaybackState.seeking;
    if (_isBuffering) return VideoPlaybackState.buffering;
    if (isCompleted) return VideoPlaybackState.completed;
    if (_isPlaying) return VideoPlaybackState.playing;
    if (_hasDuration || _progress > 0) return VideoPlaybackState.paused;
    return VideoPlaybackState.idle;
  }

  void bindHandlers({
    required Object owner,
    required VideoSeekHandler seekHandler,
    VoidCallback? playHandler,
    VoidCallback? pauseHandler,
    VoidCallback? replayHandler,
  }) {
    _seekOwner = owner;
    _seekHandler = seekHandler;
    _playHandler = playHandler;
    _pauseHandler = pauseHandler;
    _replayHandler = replayHandler;
  }

  void unbindHandlers(Object owner) {
    if (_seekOwner != owner) return;
    _seekOwner = null;
    _seekHandler = null;
    _playHandler = null;
    _pauseHandler = null;
    _replayHandler = null;
  }

  Future<void> play() async {
    _isPlaying = true;
    _playHandler?.call();
    notifyListeners();
  }

  Future<void> pause() async {
    _isPlaying = false;
    _pauseHandler?.call();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    final handler = _seekHandler;
    if (handler == null) return;
    await handler(position, resumePlayback: _isPlaying);
  }

  Future<void> replay() async {
    _progress = 0.0;
    _position = Duration.zero;
    _isPlaying = true;
    notifyListeners();
    final handler = _seekHandler;
    if (handler != null) {
      await handler(Duration.zero, resumePlayback: true);
    }
    _replayHandler?.call();
    _playHandler?.call();
  }

  void updateFromPlayback({
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    bool isBuffering = false,
    double bufferedProgress = 0.0,
  }) {
    if (_isDragging) return;

    final totalMs = duration.inMilliseconds;
    final nextHasDuration = totalMs > 0;
    final nextProgress = nextHasDuration
        ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final nextBuffered = bufferedProgress.clamp(0.0, 1.0);

    if (_hasDuration == nextHasDuration &&
        _duration == duration &&
        _position == position &&
        (_progress - nextProgress).abs() < 0.0005 &&
        (_bufferedProgress - nextBuffered).abs() < 0.0005 &&
        _isPlaying == isPlaying &&
        _isBuffering == isBuffering) {
      return;
    }

    _hasDuration = nextHasDuration;
    _duration = duration;
    _position = position;
    _progress = nextProgress;
    _bufferedProgress = nextBuffered;
    _isPlaying = isPlaying;
    _isBuffering = isBuffering;

    notifyListeners();
  }

  void beginDrag(double progress) {
    _progressBeforeDrag = _progress;
    _wasPlayingBeforeDrag = _isPlaying;
    _isDragging = true;
    final clamped = progress.clamp(0.0, 1.0);
    _dragProgress = clamped;
    final totalMs = _duration.inMilliseconds;
    if (totalMs > 0) {
      _dragPosition = Duration(milliseconds: (clamped * totalMs).round());
    }
    notifyListeners();
  }

  void updateDrag(double progress) {
    if (!_isDragging) return;
    final clamped = progress.clamp(0.0, 1.0);
    _dragProgress = clamped;
    final totalMs = _duration.inMilliseconds;
    if (totalMs > 0) {
      _dragPosition = Duration(milliseconds: (clamped * totalMs).round());
    }
    notifyListeners();
  }

  Future<void> endDrag({required bool commit}) async {
    final targetFraction =
        (commit ? (_dragProgress ?? _progress) : _progressBeforeDrag).clamp(
          0.0,
          1.0,
        );
    final wasPlaying = _wasPlayingBeforeDrag;
    _isDragging = false;
    _dragProgress = null;
    _dragPosition = null;
    _progress = targetFraction;
    final totalMs = _duration.inMilliseconds;
    if (totalMs > 0) {
      _position = Duration(milliseconds: (targetFraction * totalMs).round());
    }
    notifyListeners();

    if (totalMs > 0 && _seekHandler != null) {
      final ms = (targetFraction * totalMs).round();
      final seekDuration = Duration(milliseconds: ms);
      await _seekHandler!(seekDuration, resumePlayback: wasPlaying);
      if (wasPlaying) {
        _isPlaying = true;
        notifyListeners();
      }
    }
  }

  void reset() {
    _handoffGeneration++;
    _progress = 0.0;
    _bufferedProgress = 0.0;
    _isPlaying = false;
    _isBuffering = false;
    _isDragging = false;
    _dragProgress = null;
    _dragPosition = null;
    _progressBeforeDrag = 0.0;
    _wasPlayingBeforeDrag = false;
    _duration = Duration.zero;
    _position = Duration.zero;
    _hasDuration = false;
    _seekOwner = null;
    _seekHandler = null;
    _playHandler = null;
    _pauseHandler = null;
    _replayHandler = null;
    notifyListeners();
  }
}
