import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TikTok-style filter carousel where the selected center circle is also the shutter.
/// Index 0 (Original) is the red record button; other items are filter circles.
/// Hold the selected circle to record video; tap for photo / toggle.
class ArFilterCarousel extends StatefulWidget {
  const ArFilterCarousel({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.isRecording,
    required this.isBusy,
    required this.recordProgress,
    required this.isPhotoMode,
    required this.onShutterTap,
    this.onHoldStart,
    this.onHoldEnd,
    this.height,
  });

  final List<ArFilterItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isRecording;
  final bool isBusy;
  final double recordProgress;
  final bool isPhotoMode;
  final VoidCallback onShutterTap;
  final GestureLongPressStartCallback? onHoldStart;
  final GestureLongPressEndCallback? onHoldEnd;
  final double? height;

  static const inactiveSize = 52.0;
  static const activeSize = 84.0;
  static const itemGap = 14.0;
  static const itemStride = activeSize + itemGap;

  @override
  State<ArFilterCarousel> createState() => _ArFilterCarouselState();
}

class _ArFilterCarouselState extends State<ArFilterCarousel> {
  late final ScrollController _controller;
  double _scrollOffset = 0;
  int _lastHapticIndex = 0;
  bool _programmaticScroll = false;

  List<ArFilterItem> get _filters => widget.items;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _lastHapticIndex = widget.selectedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollTo(widget.selectedIndex, animated: false);
    });
  }

  @override
  void didUpdateWidget(covariant ArFilterCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _lastHapticIndex = widget.selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollTo(widget.selectedIndex, animated: false);
      });
      return;
    }
    if (oldWidget.selectedIndex == widget.selectedIndex) return;
    if (!_controller.hasClients) return;
    final target = widget.selectedIndex * ArFilterCarousel.itemStride;
    if ((_controller.offset - target).abs() > 2) {
      _scrollTo(widget.selectedIndex, animated: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scrollTo(int index, {required bool animated}) async {
    if (!_controller.hasClients) return;
    final target = index
        .clamp(0, _filters.length - 1)
        .toDouble() *
        ArFilterCarousel.itemStride;
    _programmaticScroll = true;
    if (animated) {
      await _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(target);
    }
    if (mounted) {
      setState(() => _scrollOffset = _controller.offset);
    }
    _programmaticScroll = false;
  }

  void _emit(int index) {
    final clamped = index.clamp(0, _filters.length - 1);
    if (clamped == widget.selectedIndex) {
      _scrollTo(clamped, animated: true);
      return;
    }
    HapticFeedback.selectionClick();
    widget.onSelected(clamped);
  }

  void _onScrollEnd() {
    if (_programmaticScroll || !_controller.hasClients) return;
    final index = (_controller.offset / ArFilterCarousel.itemStride)
        .round()
        .clamp(0, _filters.length - 1);
    final target = index * ArFilterCarousel.itemStride;
    // Soft settle if physics left us slightly off-center.
    if ((_controller.offset - target).abs() > 1.5) {
      _scrollTo(index, animated: true).then((_) {
        if (mounted) _emit(index);
      });
    } else {
      _emit(index);
    }
  }

  void _onActiveTap() {
    if (widget.isBusy) return;
    widget.onShutterTap();
  }

  double _sizeForIndex(int index) {
    final center = _scrollOffset / ArFilterCarousel.itemStride;
    final distance = (index - center).abs();
    final t = (1.0 - distance).clamp(0.0, 1.0);
    // Ease the grow so neighbors visibly morph while dragging.
    final eased = Curves.easeOut.transform(t);
    return ArFilterCarousel.inactiveSize +
        (ArFilterCarousel.activeSize - ArFilterCarousel.inactiveSize) * eased;
  }

  double _opacityForIndex(int index) {
    final center = _scrollOffset / ArFilterCarousel.itemStride;
    final distance = (index - center).abs();
    return (1.0 - distance * 0.35).clamp(0.45, 1.0);
  }

  int get _visualIndex {
    if (!_controller.hasClients && _scrollOffset == 0) {
      return widget.selectedIndex;
    }
    return (_scrollOffset / ArFilterCarousel.itemStride)
        .round()
        .clamp(0, _filters.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidePadding = (screenWidth - ArFilterCarousel.itemStride) / 2;
    final visual = _visualIndex;
    final visualItem = _filters[visual];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 16,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              visualItem.isOriginal ? '' : visualItem.label,
              key: ValueKey(visualItem.id),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.1,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: widget.height ?? (ArFilterCarousel.activeSize + 8),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis != Axis.horizontal) return false;

              if (notification is ScrollUpdateNotification ||
                  notification is ScrollStartNotification) {
                final next = _controller.hasClients
                    ? _controller.offset
                    : _scrollOffset;
                final hapticIndex = (next / ArFilterCarousel.itemStride)
                    .round()
                    .clamp(0, _filters.length - 1);
                if (hapticIndex != _lastHapticIndex) {
                  _lastHapticIndex = hapticIndex;
                  HapticFeedback.selectionClick();
                }
                if ((next - _scrollOffset).abs() > 0.2) {
                  setState(() => _scrollOffset = next);
                }
              }

              if (notification is ScrollEndNotification) {
                _onScrollEnd();
              }
              return false;
            },
            child: ListView.builder(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: widget.isRecording
                  ? const NeverScrollableScrollPhysics()
                  : const _FilterSnapPhysics(
                      itemExtent: ArFilterCarousel.itemStride,
                      parent: BouncingScrollPhysics(),
                    ),
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final item = _filters[index];
                final size = _sizeForIndex(index);
                final opacity = _opacityForIndex(index);
                final isCentered = (index - _scrollOffset / ArFilterCarousel.itemStride)
                        .abs() <
                    0.35;

                return SizedBox(
                  width: ArFilterCarousel.itemStride,
                  child: Center(
                    child: Opacity(
                      opacity: opacity,
                      child: GestureDetector(
                        onTap: () {
                          if (isCentered) {
                            _onActiveTap();
                          } else {
                            _scrollTo(index, animated: true).then((_) {
                              if (mounted) _emit(index);
                            });
                          }
                        },
                        onLongPressStart: isCentered &&
                                !widget.isPhotoMode &&
                                !widget.isBusy
                            ? widget.onHoldStart
                            : null,
                        onLongPressEnd: isCentered && !widget.isPhotoMode
                            ? widget.onHoldEnd
                            : null,
                        child: item.isOriginal
                            ? _ShutterCircle(
                                size: size,
                                isActive: isCentered,
                                isRecording: widget.isRecording && isCentered,
                                isPhotoMode: widget.isPhotoMode,
                                progress: widget.recordProgress,
                              )
                            : _FilterCircle(
                                emoji: item.emoji,
                                size: size,
                                isActive: isCentered,
                                isRecording: widget.isRecording && isCentered,
                                progress: widget.recordProgress,
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Snaps to the nearest filter stride with a soft spring (visible swipe motion).
class _FilterSnapPhysics extends ScrollPhysics {
  const _FilterSnapPhysics({
    required this.itemExtent,
    super.parent,
  });

  final double itemExtent;

  @override
  _FilterSnapPhysics applyTo(ScrollPhysics? ancestor) {
    return _FilterSnapPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _targetPixels(ScrollMetrics position, double velocity) {
    final maxPage =
        (position.maxScrollExtent / itemExtent).round().clamp(0, 9999);
    var page = position.pixels / itemExtent;
    if (velocity < -toleranceFor(position).velocity) {
      page -= 0.35;
    } else if (velocity > toleranceFor(position).velocity) {
      page += 0.35;
    }
    final clamped = page.round().clamp(0, maxPage);
    return clamped * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    final target = _targetPixels(position, velocity);

    if (target == position.pixels) {
      return null;
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.9,
        stiffness: 140,
        damping: 18,
      );
}

class _ShutterCircle extends StatelessWidget {
  const _ShutterCircle({
    required this.size,
    required this.isActive,
    required this.isRecording,
    required this.isPhotoMode,
    required this.progress,
  });

  final double size;
  final bool isActive;
  final bool isRecording;
  final bool isPhotoMode;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final innerColor =
        isPhotoMode && !isRecording ? Colors.white : const Color(0xFFFE2C55);
    final ring = size;
    final outer = size * 0.90;
    final inner = isRecording ? size * 0.36 : size * 0.68;

    return SizedBox(
      width: ring,
      height: ring,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isRecording)
            SizedBox(
              width: ring,
              height: ring,
              child: CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: 3,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                width: isActive ? 4.5 : 2,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              color: innerColor,
              shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isRecording ? BorderRadius.circular(6) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterCircle extends StatelessWidget {
  const _FilterCircle({
    required this.emoji,
    required this.size,
    required this.isActive,
    required this.isRecording,
    required this.progress,
  });

  final String emoji;
  final double size;
  final bool isActive;
  final bool isRecording;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final emojiSize = 22 + (size - ArFilterCarousel.inactiveSize) /
        (ArFilterCarousel.activeSize - ArFilterCarousel.inactiveSize) *
        8;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isRecording)
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: 3,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: isActive ? 0.16 : 0.08),
              border: Border.all(
                color: isActive
                    ? const Color(0xFFFE2C55)
                    : Colors.white.withValues(alpha: 0.35),
                width: isActive ? 3 : 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFE2C55).withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isRecording
                  ? Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE2C55),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    )
                  : Text(
                      emoji,
                      style: TextStyle(fontSize: emojiSize),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
