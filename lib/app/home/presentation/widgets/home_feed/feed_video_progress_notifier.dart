import 'dart:async';

import 'package:bimobondapp/core/widgets/video_progress/video_progress_controller.dart';
import 'package:flutter/widgets.dart';

/// Tracks playback progress, buffering, and seeking for active feed videos.
/// Built on top of [VideoProgressController] for 60fps CustomPainter rendering.
class FeedVideoProgressNotifier extends VideoProgressController {
  bool _videoLoading = false;

  bool get scrubbing => isDragging;
  bool get videoLoading => _videoLoading;

  void setVideoLoading(bool loading, {int? handoff}) {
    if (handoff != null && handoff != handoffGeneration) return;
    if (isDragging && loading) return;
    if (_videoLoading == loading) return;
    _videoLoading = loading;
    notifyListeners();
  }

  double get displayProgress => progress;

  void bindSeekHandler(Object owner, VideoSeekHandler handler) {
    bindHandlers(owner: owner, seekHandler: handler);
  }

  void unbindSeekHandler(Object owner) {
    unbindHandlers(owner);
  }

  void beginScrub(double progress) {
    beginDrag(progress);
  }

  void updateScrub(double progress) {
    updateDrag(progress);
  }

  Future<void> endScrub({required bool commit}) async {
    await endDrag(commit: commit);
  }

  Future<void> seekToProgress(
    double progress, {
    required bool resumePlayback,
  }) async {
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0) return;
    final ms = (progress.clamp(0.0, 1.0) * totalMs).round();
    await seek(Duration(milliseconds: ms));
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
