import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'safe_network_image.dart';

/// TikTok-style PK “Match start” clash — two faces slam together once.
///
/// Plays ~2s (with impact SFX) then calls [onFinished]. Use as a full-stage
/// overlay when a battle becomes ACTIVE.
class PkBattleStartOverlay extends StatefulWidget {
  const PkBattleStartOverlay({
    super.key,
    this.onFinished,
    this.duration = const Duration(milliseconds: 2200),
    this.leftAvatarUrl,
    this.rightAvatarUrl,
  });

  final VoidCallback? onFinished;
  final Duration duration;

  /// Host / left-side profile photo shown in the clash circle.
  final String? leftAvatarUrl;

  /// Opponent / right-side profile photo shown in the clash circle.
  final String? rightAvatarUrl;

  @override
  State<PkBattleStartOverlay> createState() => _PkBattleStartOverlayState();
}

class _PkBattleStartOverlayState extends State<PkBattleStartOverlay>
    with SingleTickerProviderStateMixin {
  /// Short punchy hit — timed with the faces colliding.
  static const _clashSfxUrl =
      'https://assets.mixkit.co/active_storage/sfx/1668/1668-preview.mp3';

  late final AnimationController _controller;
  late final Animation<double> _approach;
  late final Animation<double> _impact;
  late final Animation<double> _flash;
  late final Animation<double> _fadeOut;
  late final Animation<double> _label;

  AudioPlayer? _player;
  var _soundPlayed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _approach = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.38, curve: Curves.easeInCubic),
    );
    _impact = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.34, 0.55, curve: Curves.elasticOut),
    );
    _flash = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.36, 0.58, curve: Curves.easeOut),
    );
    _label = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.70, curve: Curves.easeOutBack),
    );
    _fadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1.0, curve: Curves.easeIn),
    );
    _controller.addListener(_onTick);
    _controller.forward().whenComplete(() {
      if (!mounted) return;
      widget.onFinished?.call();
    });
  }

  void _onTick() {
    if (_soundPlayed || _controller.value < 0.36) return;
    _soundPlayed = true;
    _playClashSound();
  }

  Future<void> _playClashSound() async {
    try {
      final player = AudioPlayer(
        handleInterruptions: false,
        androidApplyAudioAttributes: false,
        handleAudioSessionActivation: false,
      );
      _player = player;
      await player.setUrl(_clashSfxUrl);
      await player.setVolume(0.9);
      await player.play();
    } catch (e) {
      debugPrint('PkBattleStartOverlay clash SFX error: $e');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    final player = _player;
    _player = null;
    if (player != null) {
      player.stop().then((_) => player.dispose()).catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final fade = (1.0 - _fadeOut.value).clamp(0.0, 1.0);
          final approach = _approach.value;
          final impactScale = 0.85 + (_impact.value * 0.35);
          final flash = (math.sin(_flash.value * math.pi) * 0.95).clamp(
            0.0,
            1.0,
          );
          // Faces start off-screen and meet at center.
          final leftX = -140.0 * (1.0 - approach);
          final rightX = 140.0 * (1.0 - approach);
          final shake = flash > 0.05
              ? math.sin(_controller.value * 80) * 4.0 * flash
              : 0.0;

          return Opacity(
            opacity: fade,
            child: ColoredBox(
              color: Color.fromRGBO(0, 0, 0, 0.35 * fade),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _label.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.7 + _label.value * 0.35,
                        child: const Text(
                          'MATCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            shadows: [
                              Shadow(
                                color: Color(0xCC000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                              Shadow(
                                color: Color(0xFFFF2D55),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 280,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (flash > 0.02)
                            Transform.scale(
                              scale: 0.6 + flash * 1.6,
                              child: Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Color.fromRGBO(
                                        255,
                                        255,
                                        255,
                                        0.85 * flash,
                                      ),
                                      Color.fromRGBO(
                                        255,
                                        214,
                                        90,
                                        0.45 * flash,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          Transform.translate(
                            offset: Offset(shake, 0),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.translate(
                                  offset: Offset(leftX, 0),
                                  child: Transform.scale(
                                    scale: impactScale,
                                    child: _ClashFace(
                                      color: const Color(0xFFFFD54F),
                                      accent: const Color(0xFFFF2D55),
                                      mirror: false,
                                      avatarUrl: widget.leftAvatarUrl,
                                    ),
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(rightX, 0),
                                  child: Transform.scale(
                                    scale: impactScale,
                                    child: _ClashFace(
                                      color: const Color(0xFF7DE8FF),
                                      accent: const Color(0xFF25F4EE),
                                      mirror: true,
                                      avatarUrl: widget.rightAvatarUrl,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClashFace extends StatelessWidget {
  const _ClashFace({
    required this.color,
    required this.accent,
    required this.mirror,
    this.avatarUrl,
  });

  final Color color;
  final Color accent;
  final bool mirror;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = isValidNetworkImageUrl(avatarUrl);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(mirror ? -1.0 : 1.0, 1.0, 1.0),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: hasAvatar
            ? Transform(
                alignment: Alignment.center,
                // Un-mirror the photo so faces read correctly.
                transform: Matrix4.diagonal3Values(mirror ? -1.0 : 1.0, 1.0, 1.0),
                child: SafeNetworkImage(
                  imageUrl: avatarUrl,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  blankOnError: true,
                  showLoadingIndicator: false,
                ),
              )
            : CustomPaint(painter: _AngryFacePainter(accent: accent)),
      ),
    );
  }
}

class _AngryFacePainter extends CustomPainter {
  _AngryFacePainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    // Angry brows.
    final brow = Path()
      ..moveTo(size.width * 0.22, size.height * 0.34)
      ..lineTo(size.width * 0.42, size.height * 0.40)
      ..moveTo(size.width * 0.58, size.height * 0.40)
      ..lineTo(size.width * 0.78, size.height * 0.34);
    canvas.drawPath(brow, paint);

    // Eyes — one heart-shaped accent eye (TikTok vibe).
    final leftEye = Offset(size.width * 0.34, size.height * 0.48);
    final rightEye = Offset(size.width * 0.66, size.height * 0.48);
    canvas.drawCircle(leftEye, 5.5, Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawCircle(rightEye, 6.5, Paint()..color = accent);
    canvas.drawCircle(
      rightEye.translate(0, -0.5),
      2.2,
      Paint()..color = Colors.white,
    );

    // Mouth.
    final mouth = Path()
      ..moveTo(size.width * 0.32, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.58,
        size.width * 0.68,
        size.height * 0.68,
      );
    canvas.drawPath(mouth, paint);
  }

  @override
  bool shouldRepaint(covariant _AngryFacePainter oldDelegate) =>
      oldDelegate.accent != accent;
}
