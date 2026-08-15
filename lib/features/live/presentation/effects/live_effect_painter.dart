import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/live_effect.dart';
import '../../domain/entities/tracked_face.dart';

/// Renders the selected live effect using mapped face landmarks + head pose.
class LiveEffectPainter extends CustomPainter {
  LiveEffectPainter({
    required this.effect,
    required this.face,
  });

  final LiveEffect effect;
  final TrackedFace? face;

  @override
  void paint(Canvas canvas, Size size) {
    switch (effect.kind) {
      case LiveEffectKind.none:
        return;
      case LiveEffectKind.colorGrade:
        _paintColorGrade(canvas, size);
        return;
      case LiveEffectKind.virtualBackground:
        if (face != null) _paintVirtualBackground(canvas, size, face!);
        return;
      case LiveEffectKind.faceOverlay:
        if (face != null) _paintFaceOverlay(canvas, face!);
        return;
    }
  }

  void _paintColorGrade(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..blendMode = BlendMode.softLight;
    switch (effect.id) {
      case 'warm_glow':
        paint.color = const Color(0x55FFB074);
        break;
      case 'cool_tone':
        paint.color = const Color(0x554B7BEA);
        break;
      case 'fresh':
        paint.color = const Color(0x447CFFB2);
        break;
      case 'natural_beauty':
        paint.color = const Color(0x33FFE0B2);
        paint.blendMode = BlendMode.screen;
        break;
      default:
        return;
    }
    canvas.drawRect(rect, paint);
  }

  void _paintVirtualBackground(Canvas canvas, Size size, TrackedFace face) {
    final head = face.boundingBox.inflate(face.boundingBox.width * 0.2);
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addOval(head)
      ..fillType = PathFillType.evenOdd;

    final bg = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, size.height * 0.15),
        Offset(0, size.height),
        const [
          Color(0xFF43A047),
          Color(0xFF66BB6A),
          Color(0xFFA5D6A7),
          Color(0xFF90CAF9),
        ],
        const [0.0, 0.35, 0.7, 1.0],
      );
    canvas.drawPath(path, bg);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.16),
      26,
      Paint()..color = const Color(0xDDFFEE58),
    );
  }

  void _paintFaceOverlay(Canvas canvas, TrackedFace face) {
    switch (effect.id) {
      case 'sunglasses':
        _paintSunglasses(canvas, face);
        return;
      case 'cat_ears':
        _paintCatEars(canvas, face);
        return;
      case 'bunny_ears':
        _paintBunnyEars(canvas, face);
        return;
      case 'crown':
        _paintCrown(canvas, face);
        return;
      case 'hearts':
        _paintHearts(canvas, face);
        return;
      case 'stars':
        _paintStars(canvas, face);
        return;
      case 'sparkles':
        _paintSparkles(canvas, face);
        return;
      case 'soft_skin':
        _paintSoftSkin(canvas, face);
        return;
      case 'blush':
        _paintBlush(canvas, face, intensity: 1);
        return;
      case 'cute_cheeks':
        _paintBlush(canvas, face, intensity: 1.35);
        return;
      case 'subtle_makeup':
        _paintSubtleMakeup(canvas, face);
        return;
      case 'face_glow':
        _paintFaceGlow(canvas, face);
        return;
    }
  }

  void _withFacePose(
    Canvas canvas,
    TrackedFace face,
    Offset pivot,
    void Function(Canvas canvas) draw,
  ) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(face.rollRadians);
    // Mild yaw squash for depth cue (not a full 3D mesh).
    final yawScale = (1 - face.yawRadians.abs() * 0.18).clamp(0.75, 1.0);
    canvas.scale(yawScale, 1);
    canvas.translate(-pivot.dx, -pivot.dy);
    draw(canvas);
    canvas.restore();
  }

  void _paintSunglasses(Canvas canvas, TrackedFace face) {
    final eyes = face.eyesCenter;
    final eyeDist = face.eyeDistance;
    final height = eyeDist * 0.9;

    _withFacePose(canvas, face, eyes, (c) {
      final frame = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.8, eyeDist * 0.11);
      final lens = Paint()
        ..shader = ui.Gradient.linear(
          Offset(eyes.dx - eyeDist, eyes.dy),
          Offset(eyes.dx + eyeDist, eyes.dy),
          const [Color(0xCC311B92), Color(0xCC880E4F)],
        );

      final leftLens = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(eyes.dx - eyeDist * 0.55, eyes.dy),
          width: eyeDist * 0.98,
          height: height * 0.88,
        ),
        const Radius.circular(12),
      );
      final rightLens = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(eyes.dx + eyeDist * 0.55, eyes.dy),
          width: eyeDist * 0.98,
          height: height * 0.88,
        ),
        const Radius.circular(12),
      );

      c.drawRRect(leftLens, lens);
      c.drawRRect(rightLens, lens);
      c.drawRRect(leftLens, frame);
      c.drawRRect(rightLens, frame);
      c.drawLine(
        Offset(leftLens.right, eyes.dy),
        Offset(rightLens.left, eyes.dy),
        frame,
      );

      // Soft temple accents.
      c.drawCircle(
        Offset(leftLens.left - 2, eyes.dy - height * 0.15),
        5,
        Paint()..color = const Color(0xFFFF5252),
      );
      c.drawCircle(
        Offset(rightLens.right + 2, eyes.dy - height * 0.1),
        4.5,
        Paint()..color = const Color(0xFFFFEB3B),
      );
    });
  }

  void _paintCatEars(Canvas canvas, TrackedFace face) {
    final box = face.boundingBox;
    final pivot = face.forehead;
    final earW = box.width * 0.26;
    final earH = box.height * 0.3;

    _withFacePose(canvas, face, pivot, (c) {
      void ear(Offset tip, bool left) {
        final base = Offset(
          tip.dx + (left ? earW * 0.12 : -earW * 0.12),
          tip.dy + earH * 0.9,
        );
        final outer = Path()
          ..moveTo(base.dx - earW * 0.42, base.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(base.dx + earW * 0.42, base.dy)
          ..close();
        final inner = Path()
          ..moveTo(base.dx - earW * 0.18, base.dy - earH * 0.08)
          ..lineTo(tip.dx, tip.dy + earH * 0.28)
          ..lineTo(base.dx + earW * 0.18, base.dy - earH * 0.08)
          ..close();
        c.drawPath(outer, Paint()..color = const Color(0xFF5D4037));
        c.drawPath(inner, Paint()..color = const Color(0xFFFF8A80));
      }

      ear(Offset(pivot.dx - box.width * 0.28, pivot.dy - earH * 0.15), true);
      ear(Offset(pivot.dx + box.width * 0.28, pivot.dy - earH * 0.15), false);

      final nose = face.noseBase ?? box.center;
      c.drawOval(
        Rect.fromCenter(
          center: nose.translate(0, box.height * 0.02),
          width: box.width * 0.14,
          height: box.height * 0.1,
        ),
        Paint()..color = const Color(0xE6FF5252),
      );
    });
  }

  void _paintBunnyEars(Canvas canvas, TrackedFace face) {
    final box = face.boundingBox;
    final pivot = face.forehead;
    final earW = box.width * 0.16;
    final earH = box.height * 0.42;

    _withFacePose(canvas, face, pivot, (c) {
      void ear(double xSign) {
        final base = Offset(pivot.dx + box.width * 0.18 * xSign, pivot.dy);
        final tip = Offset(base.dx + box.width * 0.02 * xSign, pivot.dy - earH);
        final outer = Path()
          ..moveTo(base.dx - earW * 0.55, base.dy)
          ..quadraticBezierTo(tip.dx - earW * 0.2, tip.dy + earH * 0.35, tip.dx, tip.dy)
          ..quadraticBezierTo(tip.dx + earW * 0.2, tip.dy + earH * 0.35, base.dx + earW * 0.55, base.dy)
          ..close();
        c.drawPath(outer, Paint()..color = const Color(0xFFF5F5F5));
        c.drawPath(
          outer,
          Paint()
            ..color = const Color(0xFFFFCDD2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }

      ear(-1);
      ear(1);
    });
  }

  void _paintCrown(Canvas canvas, TrackedFace face) {
    final pivot = face.forehead;
    final w = face.boundingBox.width * 0.72;
    final h = face.boundingBox.height * 0.24;

    _withFacePose(canvas, face, pivot, (c) {
      final baseY = pivot.dy + h * 0.15;
      final path = Path()
        ..moveTo(pivot.dx - w / 2, baseY)
        ..lineTo(pivot.dx - w * 0.36, baseY - h)
        ..lineTo(pivot.dx - w * 0.16, baseY - h * 0.42)
        ..lineTo(pivot.dx, baseY - h * 1.15)
        ..lineTo(pivot.dx + w * 0.16, baseY - h * 0.42)
        ..lineTo(pivot.dx + w * 0.36, baseY - h)
        ..lineTo(pivot.dx + w / 2, baseY)
        ..close();
      c.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(pivot.dx, baseY - h),
            Offset(pivot.dx, baseY),
            const [Color(0xFFFFF176), Color(0xFFFFB300)],
          ),
      );
      c.drawCircle(
        Offset(pivot.dx, baseY - h * 1.2),
        5.5,
        Paint()..color = const Color(0xFFE53935),
      );
    });
  }

  void _paintHearts(Canvas canvas, TrackedFace face) {
    final box = face.boundingBox.inflate(8);
    final paint = Paint()..color = const Color(0xE6FF4081);
    final anchors = <Offset>[
      Offset(box.left, box.top + box.height * 0.25),
      Offset(box.right, box.top + box.height * 0.3),
      Offset(box.left + 4, box.top + box.height * 0.55),
      Offset(box.right - 4, box.top + box.height * 0.6),
      face.forehead.translate(0, -box.height * 0.08),
    ];
    for (var i = 0; i < anchors.length; i++) {
      _drawHeart(canvas, anchors[i], 6.5 + (i % 3), paint);
    }
  }

  void _paintStars(Canvas canvas, TrackedFace face) {
    final eyes = face.eyesCenter;
    final paint = Paint()..color = const Color(0xFFFFF59D);
    final d = face.eyeDistance;
    _withFacePose(canvas, face, eyes, (c) {
      _drawStar(c, Offset(eyes.dx - d * 0.85, eyes.dy - d * 0.15), 5, paint);
      _drawStar(c, Offset(eyes.dx + d * 0.85, eyes.dy - d * 0.1), 5, paint);
      _drawStar(
        c,
        face.forehead,
        6,
        Paint()..color = Colors.white,
      );
    });
  }

  void _paintSparkles(Canvas canvas, TrackedFace face) {
    final box = face.boundingBox.inflate(14);
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 12; i++) {
      final t = i / 12;
      final x = i.isEven ? box.left : box.right;
      final y = box.top + box.height * t;
      _drawStar(canvas, Offset(x, y), 2.5 + (i % 3), paint);
    }
  }

  void _paintSoftSkin(Canvas canvas, TrackedFace face) {
    final oval = face.boundingBox.inflate(face.boundingBox.width * 0.06);
    canvas.drawOval(
      oval,
      Paint()
        ..color = const Color(0x33FFE0B2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _paintBlush(Canvas canvas, TrackedFace face, {required double intensity}) {
    final left = face.leftCheek ??
        Offset(
          face.boundingBox.left + face.boundingBox.width * 0.22,
          face.boundingBox.top + face.boundingBox.height * 0.55,
        );
    final right = face.rightCheek ??
        Offset(
          face.boundingBox.right - face.boundingBox.width * 0.22,
          face.boundingBox.top + face.boundingBox.height * 0.55,
        );
    final r = face.boundingBox.width * 0.11 * intensity;
    final paint = Paint()
      ..color = Color.fromRGBO(255, 120, 140, 0.38 * intensity.clamp(0.5, 1.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    _withFacePose(canvas, face, face.eyesCenter, (c) {
      c.drawCircle(left, r, paint);
      c.drawCircle(right, r, paint);
    });
  }

  void _paintSubtleMakeup(Canvas canvas, TrackedFace face) {
    _paintSoftSkin(canvas, face);
    _paintBlush(canvas, face, intensity: 0.85);
    final eyes = face.eyesCenter;
    final d = face.eyeDistance;
    _withFacePose(canvas, face, eyes, (c) {
      final lid = Paint()
        ..color = const Color(0x55CE93D8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, d * 0.08)
        ..strokeCap = StrokeCap.round;
      c.drawArc(
        Rect.fromCenter(
          center: Offset(eyes.dx - d * 0.5, eyes.dy),
          width: d * 0.7,
          height: d * 0.35,
        ),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        lid,
      );
      c.drawArc(
        Rect.fromCenter(
          center: Offset(eyes.dx + d * 0.5, eyes.dy),
          width: d * 0.7,
          height: d * 0.35,
        ),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        lid,
      );
    });
  }

  void _paintFaceGlow(Canvas canvas, TrackedFace face) {
    final center = face.eyesCenter;
    canvas.drawCircle(
      center,
      face.boundingBox.width * 0.55,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          face.boundingBox.width * 0.55,
          [
            const Color(0x55FFFFFF),
            const Color(0x00FFFFFF),
          ],
        ),
    );
  }

  void _drawHeart(Canvas canvas, Offset c, double s, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.35)
      ..cubicTo(
        c.dx - s,
        c.dy - s * 0.15,
        c.dx - s * 0.85,
        c.dy - s,
        c.dx,
        c.dy - s * 0.45,
      )
      ..cubicTo(
        c.dx + s * 0.85,
        c.dy - s,
        c.dx + s,
        c.dy - s * 0.15,
        c.dx,
        c.dy + s * 0.35,
      );
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.22, c.dy - r * 0.22)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + r * 0.22, c.dy + r * 0.22)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.22, c.dy + r * 0.22)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r * 0.22, c.dy - r * 0.22)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LiveEffectPainter oldDelegate) {
    return oldDelegate.effect.id != effect.id || oldDelegate.face != face;
  }
}
