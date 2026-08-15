import 'package:flutter/material.dart';

import '../../../../../core/utils/app_sizes.dart';
import '../../../domain/entities/live_effect.dart';

/// Rounded effect tile with a generated preview glyph (no third-party assets).
class LiveRoomEffectThumbnail extends StatelessWidget {
  const LiveRoomEffectThumbnail({
    super.key,
    required this.effect,
    required this.selected,
    required this.onTap,
    this.size = AppSizes.effectsThumb,
  });

  final LiveEffect effect;
  final bool selected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        padding: EdgeInsets.all(selected ? 2.5 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.effectsThumbRadius),
          border: selected
              ? Border.all(color: Colors.white, width: 2.5)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            selected
                ? AppSizes.effectsThumbRadius - 2
                : AppSizes.effectsThumbRadius,
          ),
          child: _EffectPreviewArt(effect: effect),
        ),
      ),
    );
  }
}

class _EffectPreviewArt extends StatelessWidget {
  const _EffectPreviewArt({required this.effect});

  final LiveEffect effect;

  @override
  Widget build(BuildContext context) {
    if (effect.isClear) {
      return ColoredBox(
        color: const Color(0xFF2A2A2A),
        child: Center(
          child: Icon(
            Icons.do_not_disturb_alt,
            color: Colors.white.withValues(alpha: 0.9),
            size: 28,
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _EffectThumbPainter(effect.id),
      child: const SizedBox.expand(),
    );
  }
}

class _EffectThumbPainter extends CustomPainter {
  _EffectThumbPainter(this.effectId);

  final String effectId;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    switch (effectId) {
      case 'sunglasses':
        canvas.drawRect(rect, Paint()..color = const Color(0xFF4E342E));
        _face(canvas, size);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(size.width * 0.5, size.height * 0.42),
              width: size.width * 0.72,
              height: size.height * 0.16,
            ),
            const Radius.circular(8),
          ),
          Paint()..color = const Color(0xFF311B92),
        );
        return;
      case 'cat_ears':
        canvas.drawRect(rect, Paint()..color = const Color(0xFF5C6BC0));
        _face(canvas, size);
        _ear(canvas, size, left: true);
        _ear(canvas, size, left: false);
        return;
      case 'bunny_ears':
        canvas.drawRect(rect, Paint()..color = const Color(0xFF7E57C2));
        _face(canvas, size, skin: const Color(0xFFFFE0B2));
        canvas.drawOval(
          Rect.fromLTWH(
            size.width * 0.28,
            size.height * 0.02,
            size.width * 0.14,
            size.height * 0.32,
          ),
          Paint()..color = Colors.white,
        );
        canvas.drawOval(
          Rect.fromLTWH(
            size.width * 0.58,
            size.height * 0.02,
            size.width * 0.14,
            size.height * 0.32,
          ),
          Paint()..color = Colors.white,
        );
        return;
      case 'crown':
        canvas.drawRect(rect, Paint()..color = const Color(0xFF37474F));
        _face(canvas, size);
        final crown = Path()
          ..moveTo(size.width * 0.22, size.height * 0.3)
          ..lineTo(size.width * 0.34, size.height * 0.1)
          ..lineTo(size.width * 0.5, size.height * 0.22)
          ..lineTo(size.width * 0.66, size.height * 0.1)
          ..lineTo(size.width * 0.78, size.height * 0.3)
          ..close();
        canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD54F));
        return;
      case 'hearts':
        canvas.drawRect(rect, Paint()..color = const Color(0xFFAD1457));
        _face(canvas, size, skin: const Color(0xFFFFCCBC));
        canvas.drawCircle(
          Offset(size.width * 0.22, size.height * 0.35),
          5,
          Paint()..color = const Color(0xFFFF80AB),
        );
        canvas.drawCircle(
          Offset(size.width * 0.78, size.height * 0.4),
          5,
          Paint()..color = const Color(0xFFFF80AB),
        );
        return;
      case 'stars':
      case 'sparkles':
        canvas.drawRect(rect, Paint()..color = const Color(0xFF1A237E));
        final star = Paint()..color = const Color(0xFFFFF59D);
        canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), 3.5, star);
        canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.28), 4, star);
        canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.55), 3, star);
        return;
      case 'soft_skin':
      case 'natural_beauty':
        canvas.drawRect(rect, Paint()..color = const Color(0xFFFFE0B2));
        _face(canvas, size, skin: const Color(0xFFFFCC80));
        return;
      case 'blush':
      case 'cute_cheeks':
        canvas.drawRect(rect, Paint()..color = const Color(0xFFFFCDD2));
        _face(canvas, size, skin: const Color(0xFFFFE0B2));
        canvas.drawCircle(
          Offset(size.width * 0.3, size.height * 0.55),
          size.width * 0.1,
          Paint()..color = const Color(0x99FF8A80),
        );
        canvas.drawCircle(
          Offset(size.width * 0.7, size.height * 0.55),
          size.width * 0.1,
          Paint()..color = const Color(0x99FF8A80),
        );
        return;
      case 'subtle_makeup':
        canvas.drawRect(rect, Paint()..color = const Color(0xFFF8BBD0));
        _face(canvas, size, skin: const Color(0xFFFFE0B2));
        canvas.drawCircle(
          Offset(size.width * 0.35, size.height * 0.42),
          3,
          Paint()..color = const Color(0xFFCE93D8),
        );
        canvas.drawCircle(
          Offset(size.width * 0.65, size.height * 0.42),
          3,
          Paint()..color = const Color(0xFFCE93D8),
        );
        return;
      case 'warm_glow':
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFFF8A65), Color(0xFFFFCC80)],
            ).createShader(rect),
        );
        return;
      case 'cool_tone':
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF42A5F5), Color(0xFF5C6BC0)],
            ).createShader(rect),
        );
        return;
      case 'fresh':
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF69F0AE), Color(0xFF40C4FF)],
            ).createShader(rect),
        );
        return;
      case 'face_glow':
        canvas.drawRect(rect, Paint()..color = const Color(0xFF263238));
        _face(canvas, size);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.45),
          size.width * 0.28,
          Paint()..color = const Color(0x55FFFFFF),
        );
        return;
      case 'virtual_bg':
        canvas.drawRect(rect, Paint()..color = const Color(0xFF66BB6A));
        canvas.drawCircle(
          Offset(size.width * 0.75, size.height * 0.22),
          size.width * 0.12,
          Paint()..color = const Color(0xFFFFEE58),
        );
        canvas.drawOval(
          Rect.fromLTWH(
            size.width * 0.25,
            size.height * 0.35,
            size.width * 0.5,
            size.height * 0.55,
          ),
          Paint()..color = const Color(0xFFE0E0E0),
        );
        return;
      default:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF424242));
        _face(canvas, size);
    }
  }

  void _face(Canvas canvas, Size size, {Color skin = const Color(0xFFFFCC80)}) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.55),
        width: size.width * 0.62,
        height: size.height * 0.7,
      ),
      Paint()..color = skin,
    );
  }

  void _ear(Canvas canvas, Size size, {required bool left}) {
    final tip = Offset(
      size.width * (left ? 0.28 : 0.72),
      size.height * 0.12,
    );
    final path = Path()
      ..moveTo(tip.dx - size.width * 0.08, tip.dy + size.height * 0.18)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + size.width * 0.08, tip.dy + size.height * 0.18)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF6D4C41));
  }

  @override
  bool shouldRepaint(covariant _EffectThumbPainter oldDelegate) =>
      oldDelegate.effectId != effectId;
}
