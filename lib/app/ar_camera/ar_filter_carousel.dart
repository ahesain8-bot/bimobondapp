import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  static const inactiveSize = 48.0;
  static const activeSize = 86.0;
  static const itemStride = 72.0;
  static const _loopCopies = 200;
  static double get visibleSpan => 4 * itemStride + inactiveSize;

  /// Roughly five slots are visible at once ([visibleSpan] / [itemStride]), so
  /// a list needs at least one more than that before wrapping can happen
  /// off-screen. See `_ArFilterCarouselState._looping`.
  static const _minLoopItems = 6;

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

  /// The carousel is an infinite loop, which only reads as a loop when there
  /// are more items than fit on screen. With a short list the repeats land
  /// inside the visible window and you see the same entries — including the
  /// centred shutter — twice over (shutter, overlay, shutter, overlay...).
  /// Below the threshold the list is rendered once, unlooped.
  bool get _looping => _n >= ArFilterCarousel._minLoopItems;

  int get _midBase => _looping ? (ArFilterCarousel._loopCopies ~/ 2) * _n : 0;
  int get _itemCount => _looping ? _n * ArFilterCarousel._loopCopies : _n;

  double get _effectiveScrollOffset =>
      _controller.hasClients ? _controller.offset : _scrollOffset;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()
      ..addListener(_syncScrollOffsetFromController);
    _lastHapticReal = widget.selectedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToReal(widget.selectedIndex, animated: false);
    });
  }

  void _syncScrollOffsetFromController() {
    if (!_controller.hasClients) return;
    final next = _controller.offset;
    if ((next - _scrollOffset).abs() > 0.01) {
      setState(() => _scrollOffset = next);
    }
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

    // Solo shutter replaces the list — re-anchor when coming back to carousel.
    final resyncCarousel =
        (oldWidget.isRecording && !widget.isRecording) ||
        (oldWidget.soloShutter && !widget.soloShutter);
    if (resyncCarousel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToReal(widget.selectedIndex, animated: false);
      });
    }

    if (oldWidget.selectedIndex == widget.selectedIndex && !resyncCarousel) {
      return;
    }
    if (!_controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToReal(widget.selectedIndex, animated: false);
      });
      return;
    }
    final target =
        _nearestLoopIndex(widget.selectedIndex) * ArFilterCarousel.itemStride;
    if ((_controller.offset - target).abs() > 2) {
      _scrollToReal(widget.selectedIndex, animated: true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncScrollOffsetFromController);
    _controller.dispose();
    super.dispose();
  }

  int _realFromLoop(int loopIndex) {
    if (_n == 0) return 0;
    if (!_looping) return loopIndex.clamp(0, _n - 1);
    return ((loopIndex % _n) + _n) % _n;
  }

  int _nearestLoopIndex(int realIndex) {
    final real = realIndex.clamp(0, _n - 1);
    // Unlooped: loop index IS the real index, and there is no shorter way round.
    if (!_looping) return real;
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
    if (_n == 0) return;
    if (!_controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToReal(realIndex, animated: animated);
        }
      });
      return;
    }
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
    // Nothing to recenter without the loop — the list has real ends.
    if (!_looping) return;
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
    if (_programmaticScroll || !_controller.hasClients || _n == 0) return;
    final loop = (_controller.offset / ArFilterCarousel.itemStride).round();
    final real = _realFromLoop(loop);
    final target = loop * ArFilterCarousel.itemStride;
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
    if (widget.isBusy && !widget.isRecording) return;
    widget.onShutterTap();
  }

  double _sizeForLoop(int loopIndex) {
    final center = _effectiveScrollOffset / ArFilterCarousel.itemStride;
    final distance = (loopIndex - center).abs();
    final t = (1.0 - distance).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);
    return ArFilterCarousel.inactiveSize +
        (ArFilterCarousel.activeSize - ArFilterCarousel.inactiveSize) * eased;
  }

  double _opacityForLoop(int loopIndex) {
    final center = _effectiveScrollOffset / ArFilterCarousel.itemStride;
    final distance = (loopIndex - center).abs();
    // Hide anything past the 2nd neighbor (no 3rd peek).
    if (distance > 2.05) return 0.0;
    return (1.0 - distance * 0.22).clamp(0.45, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_n == 0) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidePadding = (screenWidth - ArFilterCarousel.itemStride) / 2;
    final clipWidth = ArFilterCarousel.visibleSpan.clamp(0.0, screenWidth);
    final rowHeight = widget.height ?? (ArFilterCarousel.activeSize + 8);

    // Solo modes (recording, draft review, layout grid) always show one fixed
    // shutter — never rely on carousel scroll math (which can render opacity 0
    // until the user taps and syncs offset).
    if (widget.soloShutter) {
      return SizedBox(
        height: rowHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: GestureDetector(
                onTap: _onActiveTap,
                onLongPressStart: widget.isBusy ? null : widget.onHoldStart,
                onLongPressEnd: widget.onHoldEnd,
                child: _ShutterCircle(
                  size: ArFilterCarousel.activeSize,
                  isActive: true,
                  isRecording: widget.isRecording,
                  isPhotoMode: widget.isPhotoMode,
                  progress: widget.recordProgress,
                ),
              ),
            ),
            if (widget.showSideActions) _buildRightSideActions(),
          ],
        ),
      );
    }

    return SizedBox(
      height: rowHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: SizedBox(
              width: clipWidth,
              height: rowHeight,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: screenWidth,
                  minWidth: screenWidth,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: screenWidth,
                    height: rowHeight,
                    child: NotificationListener<ScrollNotification>(
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
                              _effectiveScrollOffset /
                              ArFilterCarousel.itemStride;
                          final isCentered = (loopIndex - center).abs() < 0.35;

                          if (widget.soloShutter && !isCentered) {
                            return const SizedBox(
                              width: ArFilterCarousel.itemStride,
                            );
                          }

                          if (opacity <= 0) {
                            return const SizedBox(
                              width: ArFilterCarousel.itemStride,
                            );
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
                                      _scrollToReal(real, animated: true).then((
                                        _,
                                      ) {
                                        if (mounted) _emit(real);
                                      });
                                    }
                                  },
                                  onLongPressStart: isCentered && !widget.isBusy
                                      ? widget.onHoldStart
                                      : null,
                                  onLongPressEnd: isCentered
                                      ? widget.onHoldEnd
                                      : null,
                                  child: item.isOriginal && isCentered
                                      ? _ShutterCircle(
                                          size: size,
                                          isActive: true,
                                          isRecording:
                                              widget.isRecording && isCentered,
                                          isPhotoMode: widget.isPhotoMode,
                                          progress: widget.recordProgress,
                                        )
                                      : _FilterCircle(
                                          item: item,
                                          size: size,
                                          isActive: isCentered,
                                          isRecording:
                                              widget.isRecording && isCentered,
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showSideActions) _buildRightSideActions(),
        ],
      ),
    );
  }

  /// Delete + confirm sit clear of the centered shutter (no overlap).
  Widget _buildRightSideActions() {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shutterRight =
              constraints.maxWidth / 2 + ArFilterCarousel.activeSize / 2;
          return Stack(
            children: [
              Positioned(
                left: shutterRight + 22,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SideAction(
                      icon: LucideIcons.delete,
                      size: 28,
                      iconSize: 24,
                      background: Colors.transparent,
                      onTap: widget.onCancel,
                    ),
                    const SizedBox(width: 12),
                    _SideAction(
                      icon: LucideIcons.circleCheck,
                      size: 40,
                      iconSize: 26,
                      background: const Color(0xFFFE2C55),
                      onTap: widget.onConfirm,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.background,
    required this.onTap,
    this.size = 48,
    this.iconSize = 24,
  });

  final IconData icon;
  final Color background;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Center(
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class _FilterSnapPhysics extends ScrollPhysics {
  const _FilterSnapPhysics({required this.itemExtent, super.parent});

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
    final target = _targetPixels(
      position,
      velocity,
    ).clamp(position.minScrollExtent, position.maxScrollExtent);

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
  SpringDescription get spring =>
      const SpringDescription(mass: 0.9, stiffness: 140, damping: 18);
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
    final innerColor = isPhotoMode && !isRecording
        ? Colors.white
        : const Color(0xFFFE2C55);
    final ring = size;
    final outer = size * 0.90;
    final inner = isRecording ? size * 0.36 : size * 0.68;
    final showProgress = isRecording || progress > 0.001;

    return SizedBox(
      width: ring,
      height: ring,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
          if (showProgress)
            SizedBox(
              width: outer,
              height: outer,
              child: CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: 4.5,
                color: const Color(0xFFFE2C55),
                backgroundColor: Colors.transparent,
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              color: innerColor,
              borderRadius: BorderRadius.circular(isRecording ? 6 : inner / 2),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterCircle extends StatelessWidget {
  const _FilterCircle({
    required this.item,
    required this.size,
    required this.isActive,
    required this.isRecording,
  });

  final ArFilterItem item;
  final double size;
  final bool isActive;
  final bool isRecording;

  Color? get _previewColor {
    final hex = item.previewColorHex;
    if (hex == null) return null;
    var value = hex.replaceFirst('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final emojiSize =
        20 +
        (size - ArFilterCarousel.inactiveSize) /
            (ArFilterCarousel.activeSize - ArFilterCarousel.inactiveSize) *
            10;

    final showThumbnail = item.hasThumbnail && !item.isOriginal;

    // The thumbnail rides on the BoxDecoration instead of being a child widget.
    // With shape: BoxShape.circle the decoration clips its own image to the
    // circle, and BoxFit.cover crops any aspect ratio to fill it — so a tall or
    // wide thumbnail can never spill past the ring or stretch the row, which a
    // ClipOval'd child Image was still managing to do.
    final thumbnail = showThumbnail
        ? DecorationImage(
            image: NetworkImage(item.thumbnailUrl!),
            fit: BoxFit.cover,
          )
        : null;

    // Behind the image: the catalog's swatch while it downloads, otherwise the
    // usual translucent fill.
    final fillColor = showThumbnail
        ? (_previewColor ?? Colors.white.withValues(alpha: 0.08))
        : Colors.white.withValues(alpha: isActive ? 0.16 : 0.08);

    Widget? child;
    if (isRecording) {
      child = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFFFE2C55),
          borderRadius: BorderRadius.circular(5),
        ),
      );
    } else if (item.isOriginal) {
      // "Original" is the shutter slot. Off centre it becomes a plain carousel
      // item, where a muted camera glyph reads as "no effect" better than the
      // sparkle emoji did.
      child = Opacity(
        opacity: 0.5,
        child: SvgPicture.asset(
          AppAssets.cameraShutterIcon,
          width: size * 0.42,
          height: size * 0.42,
          fit: BoxFit.contain,
          colorFilter: const ColorFilter.mode(
            Color(0xFFBDBDBD),
            BlendMode.srcIn,
          ),
        ),
      );
    } else if (!showThumbnail) {
      child = Text(item.emoji, style: TextStyle(fontSize: emojiSize));
    }

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fillColor,
          image: thumbnail,
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
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}
