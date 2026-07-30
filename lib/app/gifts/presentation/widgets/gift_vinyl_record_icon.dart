import 'dart:ui';

import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/presentation/utils/gift_accent_color.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Visual density for vinyl art (catalog grid vs compact sound chip).
enum GiftVinylDiscStyle {
  catalog,
  /// TikTok-style mini disc in a sound chip — larger label hub, tighter ring.
  chip,
}

/// TikTok-style music gift tile — colored vinyl ring from [GiftEntity.color].
class GiftVinylRecordIcon extends StatelessWidget {
  const GiftVinylRecordIcon({
    required this.gift,
    this.size = 56,
    this.isSelected = false,
    this.showPauseIcon = false,
    this.showPlayIcon = false,
    this.discStyle = GiftVinylDiscStyle.catalog,
    super.key,
  });

  final GiftEntity gift;
  final double size;
  final bool isSelected;
  final bool showPauseIcon;
  final bool showPlayIcon;
  final GiftVinylDiscStyle discStyle;

  @override
  Widget build(BuildContext context) {
    return _VinylRecordStack(
      gift: gift,
      size: size,
      isSelected: isSelected,
      showPauseIcon: showPauseIcon,
      showPlayIcon: showPlayIcon,
      disc: _GiftVinylDiscRing(
        gift: gift,
        size: size,
        isSelected: isSelected,
        discStyle: discStyle,
      ),
    );
  }
}

/// Continuous spin while [spinning] is true (preview / playing audio gift).
class SpinningGiftVinylRecordIcon extends StatefulWidget {
  const SpinningGiftVinylRecordIcon({
    required this.gift,
    required this.spinning,
    this.size = 56,
    this.isSelected = false,
    this.showPauseIcon = false,
    this.showPlayIcon = false,
    this.discStyle = GiftVinylDiscStyle.catalog,
    super.key,
  });

  final GiftEntity gift;
  final bool spinning;
  final double size;
  final bool isSelected;
  final bool showPauseIcon;
  final bool showPlayIcon;
  final GiftVinylDiscStyle discStyle;

  @override
  State<SpinningGiftVinylRecordIcon> createState() =>
      _SpinningGiftVinylRecordIconState();
}

class _SpinningGiftVinylRecordIconState extends State<SpinningGiftVinylRecordIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _syncSpin();
  }

  @override
  void didUpdateWidget(SpinningGiftVinylRecordIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spinning != widget.spinning) {
      _syncSpin();
    }
  }

  void _syncSpin() {
    if (widget.spinning) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
    } else {
      _spinController.stop();
      _spinController.value = 0;
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _VinylRecordStack(
      gift: widget.gift,
      size: widget.size,
      isSelected: widget.isSelected,
      showPauseIcon: widget.showPauseIcon,
      showPlayIcon: widget.showPlayIcon,
      disc: RotationTransition(
        turns: _spinController,
        child: _GiftVinylDiscRing(
          gift: widget.gift,
          size: widget.size,
          isSelected: widget.isSelected,
          discStyle: widget.discStyle,
        ),
      ),
    );
  }
}

class _VinylRecordStack extends StatelessWidget {
  const _VinylRecordStack({
    required this.gift,
    required this.size,
    required this.isSelected,
    required this.showPauseIcon,
    required this.showPlayIcon,
    required this.disc,
  });

  final GiftEntity gift;
  final double size;
  final bool isSelected;
  final bool showPauseIcon;
  final bool showPlayIcon;
  final Widget disc;

  @override
  Widget build(BuildContext context) {
    final outer = size;

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          disc,
          if (showPauseIcon && isSelected)
            Icon(
              LucideIcons.pause,
              size: outer * 0.22,
              color: Colors.white.withValues(alpha: 0.96),
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          if (showPlayIcon && isSelected && !showPauseIcon)
            Icon(
              LucideIcons.play,
              size: outer * 0.22,
              color: Colors.white.withValues(alpha: 0.96),
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Spinning / static colored ring and label area.
class _GiftVinylDiscRing extends StatelessWidget {
  const _GiftVinylDiscRing({
    required this.gift,
    required this.size,
    required this.isSelected,
    this.discStyle = GiftVinylDiscStyle.catalog,
  });

  final GiftEntity gift;
  final double size;
  final bool isSelected;
  final GiftVinylDiscStyle discStyle;

  @override
  Widget build(BuildContext context) {
    final silk = giftSilkDiscColors(gift.color);
    final outer = size;
    final isChip = discStyle == GiftVinylDiscStyle.chip;
    final inner = size * (isChip ? 0.46 : 0.36);
    final silkBlurSigma = isChip ? 4.0 : 6.0;

    return SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: outer,
                  height: outer,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: silk,
                      stops: const [0.0, 0.18, 0.38, 0.55, 0.72, 0.88, 1.0],
                    ),
                  ),
                ),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: silkBlurSigma,
                    sigmaY: silkBlurSigma,
                  ),
                  child: Container(
                    width: outer * (isChip ? 0.88 : 0.92),
                    height: outer * (isChip ? 0.88 : 0.92),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: silk
                            .map((c) => c.withValues(alpha: 0.85))
                            .toList(),
                        stops: const [0.0, 0.2, 0.4, 0.58, 0.75, 0.9, 1.0],
                        transform: const GradientRotation(0.85),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: outer,
                  height: outer,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: isSelected ? 0.35 : 0.22),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.12),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: isSelected
                      ? (isChip ? 0.38 : 0.32)
                      : (isChip ? 0.22 : 0.16),
                ),
                width: isChip ? 0.85 : 1,
              ),
            ),
          ),
          Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF050505),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isChip ? 0.42 : 0.35),
                  blurRadius: isChip ? 3 : 4,
                  offset: Offset(0, isChip ? 1.5 : 2),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: isChip ? 0.1 : 0.08),
              ),
            ),
          ),
          Container(
            width: inner * (isChip ? 0.28 : 0.32),
            height: inner * (isChip ? 0.28 : 0.32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }
}
