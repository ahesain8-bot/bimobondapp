import 'dart:async';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:flutter/material.dart';

import 'tiktok_progress_painter.dart';
import 'video_progress_controller.dart';

/// Production-ready TikTok-style video progress bar.
///
/// Behavior:
/// * Thin (3px) white bar at rest with semi-transparent buffered indicator,
///   no visible background.
/// * On user touch, smoothly grows to 8px over ~175ms (easeOut) and a
///   14px circular thumb fades in.
/// * During horizontal drag the playhead tracks the finger instantly, a
///   formatted seek-time label appears above the thumb, and automatic
///   progress updates are suspended (paused via controller).
/// * On release the bar smoothly shrinks back to 3px, the thumb fades out,
///   and playback resumes from the selected position.
///
/// Performance:
/// * Uses a single [AnimationController] (175 ms easeOut) to drive both
///   bar height and thumb opacity — no setState per frame.
/// * Only the [CustomPaint] inside its own [RepaintBoundary] is repainted
///   on progress ticks or drag-state changes. The parent page never rebuilds.
/// * [ListenableBuilder] listens to [VideoProgressController] only for
///   repainting the inner painter — outer layout is fixed.
class TikTokProgressBar extends StatefulWidget {
  const TikTokProgressBar({
    required this.controller,
    super.key,
    this.height = HomeLayoutConstants.progressBarHitHeight,
    this.playingBarHeight = HomeLayoutConstants.progressBarPlayingHeight,
    this.minBarHeight = HomeLayoutConstants.progressBarMinHeight,
    this.maxBarHeight = HomeLayoutConstants.progressBarScrubHeight,
    this.thumbSize = HomeLayoutConstants.progressBarDotScrubSize,
    this.horizontalPadding = 12.0,
    this.expandAnimationDuration = const Duration(milliseconds: 175),
    this.shrinkAnimationDuration = const Duration(milliseconds: 175),
    this.showSeekTime = true,
    this.bufferedColor = const Color(0x59FFFFFF),
    this.progressColor = Colors.white,
    this.thumbColor = Colors.white,
  }) : assert(playingBarHeight >= 0),
       assert(minBarHeight >= playingBarHeight),
       assert(maxBarHeight >= minBarHeight),
       assert(thumbSize >= 0),
       assert(expandAnimationDuration >= Duration.zero),
       assert(shrinkAnimationDuration >= Duration.zero);

  final VideoProgressController controller;

  final double height;
  final double playingBarHeight;
  final double minBarHeight;
  final double maxBarHeight;
  final double thumbSize;
  final double horizontalPadding;
  final Duration expandAnimationDuration;
  final Duration shrinkAnimationDuration;
  final bool showSeekTime;

  final Color bufferedColor;
  final Color progressColor;
  final Color thumbColor;

  @override
  State<TikTokProgressBar> createState() => _TikTokProgressBarState();
}

class _TikTokProgressBarState extends State<TikTokProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _dragState;

  final LayerLink _thumbLink = LayerLink();
  OverlayEntry? _seekTimeOverlay;
  double _lastOverlayDx = -1;
  String _lastOverlayText = '';

  static String _formatDuration(Duration d) {
    final total = d.inMilliseconds;
    if (total < 0) return '0:00';
    final minutes = total ~/ 60000;
    final seconds = ((total % 60000) ~/ 1000);
    if (minutes == 0) return seconds.toString().padLeft(2, '0');
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: widget.expandAnimationDuration,
      reverseDuration: widget.shrinkAnimationDuration,
      value: 0.0,
    );
    _dragState = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _removeSeekTimeOverlay();
    _anim.dispose();
    super.dispose();
  }

  double _progressForDx(double dx, double width) {
    if (width <= 0) return 0.0;
    return (dx / width).clamp(0.0, 1.0);
  }

  void _showOrUpdateSeekTime({
    required BuildContext context,
    required double barWidth,
    required double progress,
  }) {
    if (!widget.showSeekTime) return;
    final position = Duration(
      milliseconds:
          (progress.clamp(0.0, 1.0) * widget.controller.duration.inMilliseconds)
              .round(),
    );
    final text = _formatDuration(position);
    final dx = (progress * barWidth).clamp(0.0, barWidth);

    if (_seekTimeOverlay == null) {
      _insertSeekTimeOverlay(text: text, dx: dx);
      _lastOverlayDx = dx;
      _lastOverlayText = text;
      return;
    }

    if ((dx - _lastOverlayDx).abs() >= 0.5 || _lastOverlayText != text) {
      _lastOverlayDx = dx;
      _lastOverlayText = text;
      _seekTimeOverlay?.markNeedsBuild();
    }
  }

  void _insertSeekTimeOverlay({required String text, required double dx}) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    Widget builder(BuildContext context) {
      return Positioned(
        width: 56,
        child: CompositedTransformFollower(
          link: _thumbLink,
          showWhenUnlinked: false,
          targetAnchor: const Alignment(0.5, -2.8),
          followerAnchor: Alignment.bottomCenter,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _dragState,
              builder: (context, child) {
                return Opacity(opacity: _dragState.value, child: child);
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    _seekTimeOverlay = OverlayEntry(builder: builder);
    overlay.insert(_seekTimeOverlay!);
  }

  void _removeSeekTimeOverlay() {
    final entry = _seekTimeOverlay;
    _seekTimeOverlay = null;
    if (entry?.mounted ?? false) {
      try {
        entry!.remove();
      } catch (_) {}
    }
  }

  void _onPointerDown(PointerDownEvent event, double barWidth) {
    if (!widget.controller.canSeek) return;
    final progress = _progressForDx(event.localPosition.dx, barWidth);
    widget.controller.beginDrag(progress);
    unawaited(_anim.forward());
    _showOrUpdateSeekTime(
      context: context,
      barWidth: barWidth,
      progress: progress,
    );
  }

  void _onPointerMove(PointerMoveEvent event, double barWidth) {
    if (!widget.controller.isDragging) return;
    final progress = _progressForDx(event.localPosition.dx, barWidth);
    widget.controller.updateDrag(progress);
    _showOrUpdateSeekTime(
      context: context,
      barWidth: barWidth,
      progress: progress,
    );
  }

  void _onPointerUp(PointerUpEvent event, double barWidth) {
    if (!widget.controller.isDragging) return;
    unawaited(widget.controller.endDrag(commit: true));
    unawaited(_anim.reverse());
    _removeSeekTimeOverlay();
  }

  void _onPointerCancel(PointerCancelEvent event, double barWidth) {
    if (!widget.controller.isDragging) return;
    unawaited(widget.controller.endDrag(commit: false));
    unawaited(_anim.reverse());
    _removeSeekTimeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final hitHeight = widget.height;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: hitHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              return Listener(
                onPointerDown: widget.controller.canSeek
                    ? (e) => _onPointerDown(e, barWidth)
                    : null,
                onPointerMove: widget.controller.canSeek
                    ? (e) => _onPointerMove(e, barWidth)
                    : null,
                onPointerUp: widget.controller.canSeek
                    ? (e) => _onPointerUp(e, barWidth)
                    : null,
                onPointerCancel: widget.controller.canSeek
                    ? (e) => _onPointerCancel(e, barWidth)
                    : null,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: barWidth,
                  height: hitHeight,
                  child: ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) {
                      return AnimatedBuilder(
                        animation: _dragState,
                        builder: (context, _) {
                          final t = _dragState.value;
                          final isPlaying =
                              widget.controller.isPlaying &&
                              !widget.controller.isDragging;
                          final double baseHeight = isPlaying
                              ? widget.playingBarHeight
                              : widget.minBarHeight;
                          final barHeight =
                              baseHeight +
                              (widget.maxBarHeight - baseHeight) * t;
                          final thumbOpacity = t;
                          return Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              RepaintBoundary(
                                child: CustomPaint(
                                  size: Size(barWidth, hitHeight),
                                  painter: TikTokProgressPainter(
                                    progress: widget.controller.progress,
                                    bufferedProgress:
                                        widget.controller.bufferedProgress,
                                    barHeight: barHeight,
                                    thumbSize: widget.thumbSize,
                                    thumbOpacity: thumbOpacity,
                                    bufferedColor: widget.bufferedColor,
                                    progressColor: widget.progressColor,
                                    thumbColor: widget.thumbColor,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                height: hitHeight,
                                child: _ThumbAnchor(
                                  link: _thumbLink,
                                  barWidth: barWidth,
                                  progress: widget.controller.progress,
                                  hitHeight: hitHeight,
                                  thumbSize: widget.thumbSize,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Paints nothing but positions the CompositedTransformTarget exactly at the
/// current playhead X position so the seek-time Overlay follows the thumb.
class _ThumbAnchor extends StatelessWidget {
  const _ThumbAnchor({
    required this.link,
    required this.barWidth,
    required this.progress,
    required this.hitHeight,
    required this.thumbSize,
  });

  final LayerLink link;
  final double barWidth;
  final double progress;
  final double hitHeight;
  final double thumbSize;

  @override
  Widget build(BuildContext context) {
    final playedWidth = progress.clamp(0.0, 1.0) * barWidth;
    final halfFull = thumbSize / 2;
    final dotLeft = (playedWidth - halfFull)
        .clamp(0.0, barWidth - thumbSize)
        .toDouble();
    final thumbCenterX = dotLeft + halfFull;
    return Stack(
      children: [
        Positioned(
          left: thumbCenterX - 28,
          top: 0,
          width: 56,
          height: hitHeight,
          child: CompositedTransformTarget(
            link: link,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
