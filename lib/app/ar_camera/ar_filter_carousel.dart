import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.showSideActions = false,
    this.soloShutter = false,
    this.onConfirm,
    this.onCancel,
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

  final bool showSideActions;

  final bool soloShutter;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  static const inactiveSize = 52.0;
  static const activeSize = 90.0;
  static const itemGap = 12.0;
  static const itemStride = activeSize + itemGap;
  static const _loopCopies = 200;

  @override
  State<ArFilterCarousel> createState() => _ArFilterCarouselState();
}

class _ArFilterCarouselState extends State<ArFilterCarousel> {
  late final ScrollController _controller;
  double _scrollOffset = 0;
  int _lastHapticReal = 0;
  bool _programmaticScroll = false;

  List<ArFilterItem> get _filters => widget.items;
  int get _n => _filters.length;
  int get _midBase => (ArFilterCarousel._loopCopies ~/ 2) * _n;
  int get _itemCount => _n * ArFilterCarousel._loopCopies;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _lastHapticReal = widget.selectedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToReal(widget.selectedIndex, animated: false);
    });
  }

  @override
  void didUpdateWidget(covariant ArFilterCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items || _n == 0) {
      _lastHapticReal = widget.selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToReal(widget.selectedIndex, animated: false);
      });
      return;
    }
    if (oldWidget.selectedIndex == widget.selectedIndex) return;
    if (!_controller.hasClients) return;
    final target = _nearestLoopIndex(widget.selectedIndex) *
        ArFilterCarousel.itemStride;
    if ((_controller.offset - target).abs() > 2) {
      _scrollToReal(widget.selectedIndex, animated: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _realFromLoop(int loopIndex) {
    if (_n == 0) return 0;
    return ((loopIndex % _n) + _n) % _n;
  }

  int _nearestLoopIndex(int realIndex) {
    final real = realIndex.clamp(0, _n - 1);
    if (!_controller.hasClients || _n == 0) {
      return _midBase + real;
    }
    final current = (_controller.offset / ArFilterCarousel.itemStride).round();
    final currentReal = _realFromLoop(current);
    var delta = real - currentReal;
    if (delta > _n / 2) delta -= _n;
    if (delta < -_n / 2) delta += _n;
    return current + delta;
  }

  Future<void> _scrollToReal(int realIndex, {required bool animated}) async {
    if (!_controller.hasClients || _n == 0) return;
    final loop = _nearestLoopIndex(realIndex);
    final target = loop * ArFilterCarousel.itemStride;
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
    _recenterIfNearEdge();
  }

  void _recenterIfNearEdge() {
    if (!_controller.hasClients || _n == 0) return;
    final loop = (_controller.offset / ArFilterCarousel.itemStride).round();
    final margin = _n * 20;
    if (loop < margin || loop > _itemCount - margin) {
      final real = _realFromLoop(loop);
      _programmaticScroll = true;
      _controller.jumpTo((_midBase + real) * ArFilterCarousel.itemStride);
      _scrollOffset = _controller.offset;
      _programmaticScroll = false;
    }
  }

  void _emit(int realIndex) {
    final clamped = realIndex.clamp(0, _n - 1);
    if (clamped == widget.selectedIndex) {
      _scrollToReal(clamped, animated: true);
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

    if ((_controller.offset - target).abs() > 1.5) {
      _scrollToReal(real, animated: true).then((_) {
        if (mounted) _emit(real);
      });
    } else {
      _recenterIfNearEdge();
      _emit(real);
    }
  }

  void _onActiveTap() {
    if (widget.isBusy) return;
    widget.onShutterTap();
  }

  double _sizeForLoop(int loopIndex) {
    final center = _scrollOffset / ArFilterCarousel.itemStride;
    final distance = (loopIndex - center).abs();
    final t = (1.0 - distance).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);
    return ArFilterCarousel.inactiveSize +
        (ArFilterCarousel.activeSize - ArFilterCarousel.inactiveSize) * eased;
  }

  double _opacityForLoop(int loopIndex) {
    final center = _scrollOffset / ArFilterCarousel.itemStride;
    final distance = (loopIndex - center).abs();
    return (1.0 - distance * 0.28).clamp(0.4, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_n == 0) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidePadding = (screenWidth - ArFilterCarousel.itemStride) / 2;

    return SizedBox(
      height: widget.height ?? (ArFilterCarousel.activeSize + 8),
      child: Stack(
            alignment: Alignment.center,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis != Axis.horizontal) {
                    return false;
                  }

                  if (notification is ScrollUpdateNotification ||
                      notification is ScrollStartNotification) {
                    final next = _controller.hasClients
                        ? _controller.offset
                        : _scrollOffset;
                    final hapticReal = _realFromLoop(
                      (next / ArFilterCarousel.itemStride).round(),
                    );
                    if (hapticReal != _lastHapticReal) {
                      _lastHapticReal = hapticReal;
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
                  physics: widget.isRecording || widget.soloShutter
                      ? const NeverScrollableScrollPhysics()
                      : const _FilterSnapPhysics(
                          itemExtent: ArFilterCarousel.itemStride,
                          parent: BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                        ),
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  itemCount: _itemCount,
                  itemBuilder: (context, loopIndex) {
                    final real = _realFromLoop(loopIndex);
                    final item = _filters[real];
                    final size = _sizeForLoop(loopIndex);
                    final opacity = _opacityForLoop(loopIndex);
                    final center =
                        _scrollOffset / ArFilterCarousel.itemStride;
                    final isCentered = (loopIndex - center).abs() < 0.35;

                if (widget.soloShutter && !isCentered) {
                  return const SizedBox(width: ArFilterCarousel.itemStride);
                }

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

                        onLongPressStart: isCentered && !widget.isBusy
                            ? widget.onHoldStart
                            : null,
                        onLongPressEnd: isCentered ? widget.onHoldEnd : null,
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
                              ),
                      ),
                    );
                  },
                ),
              ),
              if (widget.showSideActions)
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SideAction(
                        icon: Icons.close,
                        background: Colors.black.withValues(alpha: 0.5),
                        onTap: widget.onCancel,
                      ),
                      const SizedBox(
                        width: ArFilterCarousel.activeSize + 56,
                      ),
                      _SideAction(
                        icon: Icons.check,
                        background: const Color(0xFFFE2C55),
                        onTap: widget.onConfirm,
                      ),
                    ],
                  ),
                ),
            ],
          ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 2,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

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
    var page = position.pixels / itemExtent;
    if (velocity < -toleranceFor(position).velocity) {
      page -= 0.35;
    } else if (velocity > toleranceFor(position).velocity) {
      page += 0.35;
    }
    return page.round() * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);
    final target = _targetPixels(position, velocity)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((target - position.pixels).abs() < tolerance.distance) {
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
          if (isRecording || progress > 0.001)
            SizedBox(
              width: ring,
              height: ring,
              child: CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: 4,
                color: const Color(0xFFFE2C55),
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
              borderRadius: BorderRadius.circular(
                isRecording ? 6 : inner / 2,
              ),
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
  });

  final String emoji;
  final double size;
  final bool isActive;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final emojiSize = 20 +
        (size - ArFilterCarousel.inactiveSize) /
            (ArFilterCarousel.activeSize - ArFilterCarousel.inactiveSize) *
            10;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
