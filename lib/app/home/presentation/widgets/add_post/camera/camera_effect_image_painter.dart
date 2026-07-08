import 'dart:math' as math;

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_effect_mapper.dart';
import 'package:flutter/material.dart';

/// Paints camera effects directly in image / overlay pixel coordinates.
class CameraEffectImagePainter {
  CameraEffectImagePainter._();

  static void paintAr(
    Canvas canvas,
    Size size,
    List<CameraDetectedFace> faces,
    CameraEffectDefinition effect,
  ) {
    for (final face in faces) {
      _paintScreenFace(canvas, _faceToScreen(face), effect);
    }
  }

  /// Paints AR effects using coordinates already mapped to the target canvas.
  static void paintArScreenSpace(
    Canvas canvas,
    List<ScreenFace> faces,
    CameraEffectDefinition effect,
  ) {
    for (final face in faces) {
      _paintScreenFace(canvas, face, effect);
    }
  }

  static ScreenFace _faceToScreen(CameraDetectedFace face) {
    return ScreenFace(
      boundingBox: face.boundingBox,
      landmarks: Map<CameraFaceLandmarkType, Offset>.from(face.landmarks),
    );
  }

  static void _paintScreenFace(
    Canvas canvas,
    ScreenFace face,
    CameraEffectDefinition effect,
  ) {
    switch (effect.id) {
      case CameraEffectId.crown:
        _drawAboveScreenFace(
          canvas,
          face,
          emoji: '👑',
          scale: 1.1,
          yOffset: -0.55,
        );
      case CameraEffectId.bunny:
        _drawBunnyEarsScreen(canvas, face);
      case CameraEffectId.sunglasses:
        _drawSunglassesScreen(canvas, face);
      case CameraEffectId.dog:
        _drawAboveScreenFace(
          canvas,
          face,
          emoji: '🐶',
          scale: 0.95,
          yOffset: -0.15,
        );
        _drawOnScreenLandmark(
          canvas,
          face,
          CameraFaceLandmarkType.noseBase,
          '👃',
          face.boundingBox.width * 0.18,
        );
      case CameraEffectId.hearts:
        _drawOnScreenLandmark(
          canvas,
          face,
          CameraFaceLandmarkType.leftEye,
          '❤️',
          face.boundingBox.width * 0.22,
        );
        _drawOnScreenLandmark(
          canvas,
          face,
          CameraFaceLandmarkType.rightEye,
          '❤️',
          face.boundingBox.width * 0.22,
        );
      case CameraEffectId.none:
      case CameraEffectId.sparkle:
      case CameraEffectId.neon:
      case CameraEffectId.glitch:
        break;
    }
  }

  static void paintScreen(
    Canvas canvas,
    Size size,
    CameraEffectDefinition effect, {
    double progress = 0.35,
  }) {
    switch (effect.id) {
      case CameraEffectId.sparkle:
        _paintSparkle(canvas, size, progress);
      case CameraEffectId.neon:
        _paintNeon(canvas, size, progress);
      case CameraEffectId.glitch:
        _paintGlitch(canvas, size, progress);
      default:
        break;
    }
  }

  static void _drawAboveScreenFace(
    Canvas canvas,
    ScreenFace face, {
    required String emoji,
    required double scale,
    required double yOffset,
  }) {
    final box = face.boundingBox;
    final center = Offset(
      box.center.dx,
      box.top + box.height * yOffset,
    );
    _drawEmoji(canvas, emoji, center, box.width * scale * 0.45);
  }

  static void _drawBunnyEarsScreen(Canvas canvas, ScreenFace face) {
    final box = face.boundingBox;
    final left = Offset(
      box.left + box.width * 0.22,
      box.top - box.height * 0.15,
    );
    final right = Offset(
      box.right - box.width * 0.22,
      box.top - box.height * 0.15,
    );
    final size = box.width * 0.35;
    _drawEmoji(canvas, '🐰', left, size);
    _drawEmoji(canvas, '🐰', right, size);
  }

  static void _drawSunglassesScreen(Canvas canvas, ScreenFace face) {
    final leftEye = face.landmarks[CameraFaceLandmarkType.leftEye];
    final rightEye = face.landmarks[CameraFaceLandmarkType.rightEye];
    if (leftEye == null || rightEye == null) {
      _drawAboveScreenFace(
        canvas,
        face,
        emoji: '😎',
        scale: 1.0,
        yOffset: 0.35,
      );
      return;
    }

    final center = Offset(
      (leftEye.dx + rightEye.dx) / 2,
      (leftEye.dy + rightEye.dy) / 2,
    );
    final width = (rightEye.dx - leftEye.dx).abs() * 2.2;
    _drawEmoji(canvas, '😎', center, width);
  }

  static void _drawOnScreenLandmark(
    Canvas canvas,
    ScreenFace face,
    CameraFaceLandmarkType type,
    String emoji,
    double size,
  ) {
    final point = face.landmarks[type];
    if (point == null) return;
    _drawEmoji(canvas, emoji, point, size);
  }

  static void _drawEmoji(Canvas canvas, String emoji, Offset center, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: size.clamp(24, 120)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  static void _paintSparkle(Canvas canvas, Size size, double progress) {
    final random = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final t = (progress + i * 0.07) % 1.0;
      final x = size.width * ((i * 0.17 + t) % 1.0);
      final y = size.height * ((i * 0.23 + t * 0.5) % 1.0);
      final alpha = (math.sin(t * math.pi * 2) * 0.5 + 0.5).clamp(0.2, 1.0);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      final radius = 2 + random.nextDouble() * 4;
      canvas.drawCircle(Offset(x, y), radius, paint);
      _drawEmoji(canvas, '✨', Offset(x, y), 16 + random.nextDouble() * 10);
    }
  }

  static void _paintNeon(Canvas canvas, Size size, double progress) {
    final pulse = (math.sin(progress * math.pi * 2) * 0.5 + 0.5);
    final colors = [
      Color.lerp(const Color(0xFFFE2C55), const Color(0xFF25F4EE), pulse)!,
      Color.lerp(const Color(0xFF25F4EE), const Color(0xFFFE2C55), pulse)!,
    ];
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 + pulse * 3
      ..shader = LinearGradient(colors: colors).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      paint,
    );
  }

  static void _paintGlitch(Canvas canvas, Size size, double progress) {
    final shift = math.sin(progress * math.pi * 6) * 6;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 2;
    for (var y = 0.0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.translate(shift, 0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0x22FF0044),
    );
    canvas.restore();
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.translate(-shift, 0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0x2200FFFF),
    );
    canvas.restore();
  }
}
