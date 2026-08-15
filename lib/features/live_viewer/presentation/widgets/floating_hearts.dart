import 'dart:math';

import 'package:flutter/material.dart';

import 'tiktok_live_tokens.dart';

class FloatingHeart extends StatefulWidget {
  final VoidCallback onComplete;
  final Color? color;
  final double startRight;
  final double startBottom;

  const FloatingHeart({
    super.key,
    required this.onComplete,
    this.color,
    this.startRight = 22,
    this.startBottom = 96,
  });

  @override
  State<FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<FloatingHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rise;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late double _horizontalOffset;
  late double _rotation;
  late Color _color;
  late double _size;

  static const _palette = [
    TikTokLiveTokens.liveRed,
    Color(0xFFFF5A7A),
    Color(0xFFFF2D55),
    Color(0xFFFF8FAB),
    Color(0xFFFF4D6D),
  ];

  @override
  void initState() {
    super.initState();
    final random = Random();
    _horizontalOffset = (random.nextDouble() - 0.5) * 48;
    _rotation = (random.nextDouble() - 0.5) * 0.55;
    _color = widget.color ?? _palette[random.nextInt(_palette.length)];
    _size = TikTokLiveTokens.heartMin +
        random.nextDouble() *
            (TikTokLiveTokens.heartMax - TikTokLiveTokens.heartMin);

    final ms = TikTokLiveTokens.heartMsMin +
        random.nextInt(
          TikTokLiveTokens.heartMsMax - TikTokLiveTokens.heartMsMin,
        );

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );

    _rise = Tween<double>(begin: 0, end: TikTokLiveTokens.heartRise).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.35, end: 1.15), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7), weight: 60),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 30),
    ]).animate(_controller);

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          right: widget.startRight + _horizontalOffset,
          bottom: widget.startBottom + _rise.value,
          child: Transform.rotate(
            angle: _rotation,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Icon(
                  Icons.favorite,
                  color: _color,
                  size: _size,
                  shadows: [
                    Shadow(
                      color: _color.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Overlay that spawns hearts when [burst] increments.
class FloatingHeartsOverlay extends StatefulWidget {
  final int burst;
  final VoidCallback onConsumed;

  const FloatingHeartsOverlay({
    super.key,
    required this.burst,
    required this.onConsumed,
  });

  @override
  State<FloatingHeartsOverlay> createState() => _FloatingHeartsOverlayState();
}

class _FloatingHeartsOverlayState extends State<FloatingHeartsOverlay> {
  final List<FloatingHeart> _hearts = [];

  @override
  void didUpdateWidget(covariant FloatingHeartsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.burst > 0 && widget.burst != oldWidget.burst) {
      final count = widget.burst.clamp(1, 8);
      for (var i = 0; i < count; i++) {
        Future.delayed(Duration(milliseconds: i * 70), _spawn);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onConsumed();
      });
    }
  }

  void _spawn() {
    if (!mounted) return;
    late FloatingHeart heart;
    heart = FloatingHeart(
      key: UniqueKey(),
      onComplete: () {
        if (!mounted) return;
        setState(() => _hearts.remove(heart));
      },
    );
    setState(() => _hearts.add(heart));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: _hearts);
  }
}
