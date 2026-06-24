import 'dart:math' as math;

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detector_service.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraArEffectsLayer extends StatelessWidget {
  const CameraArEffectsLayer({
    super.key,
    required this.cameraState,
    required this.preview,
    required this.faceStream,
    required this.effect,
  });

  final CameraState cameraState;
  final AnalysisPreview preview;
  final Stream<CameraFaceDetectionFrame> faceStream;
  final CameraEffectDefinition effect;

  @override
  Widget build(BuildContext context) {
    if (!effect.requiresFaceDetection) return const SizedBox.shrink();

    return IgnorePointer(
      child: StreamBuilder<SensorConfig>(
        stream: cameraState.sensorConfig$,
        builder: (context, sensorSnapshot) {
          if (!sensorSnapshot.hasData) return const SizedBox.shrink();

          return StreamBuilder<CameraFaceDetectionFrame>(
            stream: faceStream,
            builder: (context, frameSnapshot) {
              if (!frameSnapshot.hasData) return const SizedBox.shrink();

              final frame = frameSnapshot.data!;
              final transform = frame.image.getCanvasTransformation(preview);

              return CustomPaint(
                painter: CameraArEffectsPainter(
                  effect: effect,
                  frame: frame,
                  preview: preview,
                  canvasTransformation: transform,
                ),
                size: Size.infinite,
              );
            },
          );
        },
      ),
    );
  }
}

class CameraArEffectsPainter extends CustomPainter {
  CameraArEffectsPainter({
    required this.effect,
    required this.frame,
    required this.preview,
    this.canvasTransformation,
  });

  final CameraEffectDefinition effect;
  final CameraFaceDetectionFrame frame;
  final AnalysisPreview preview;
  final CanvasTransformation? canvasTransformation;

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.faces.isEmpty) return;

    if (canvasTransformation != null) {
      canvas.save();
      canvas.applyTransformation(canvasTransformation!, size);
    }

    for (final face in frame.faces) {
      switch (effect.id) {
        case CameraEffectId.crown:
          _drawAboveFace(canvas, face, emoji: '👑', scale: 1.1, yOffset: -0.55);
        case CameraEffectId.bunny:
          _drawBunnyEars(canvas, face);
        case CameraEffectId.sunglasses:
          _drawSunglasses(canvas, face);
        case CameraEffectId.dog:
          _drawAboveFace(
            canvas,
            face,
            emoji: '🐶',
            scale: 0.95,
            yOffset: -0.15,
          );
          _drawOnLandmark(canvas, face, FaceLandmarkType.noseBase, '👃', 28);
        case CameraEffectId.hearts:
          _drawOnLandmark(canvas, face, FaceLandmarkType.leftEye, '❤️', 34);
          _drawOnLandmark(canvas, face, FaceLandmarkType.rightEye, '❤️', 34);
        case CameraEffectId.none:
        case CameraEffectId.sparkle:
        case CameraEffectId.neon:
        case CameraEffectId.glitch:
          break;
      }
    }

    if (canvasTransformation != null) {
      canvas.restore();
    }
  }

  void _drawAboveFace(
    Canvas canvas,
    Face face, {
    required String emoji,
    required double scale,
    required double yOffset,
  }) {
    final box = face.boundingBox;
    final center = preview.convertFromImage(
      Offset(box.center.dx, box.top + box.height * yOffset),
      frame.image,
    );
    _drawEmoji(canvas, emoji, center, box.width * scale * 0.45);
  }

  void _drawBunnyEars(Canvas canvas, Face face) {
    final box = face.boundingBox;
    final left = preview.convertFromImage(
      Offset(box.left + box.width * 0.22, box.top - box.height * 0.15),
      frame.image,
    );
    final right = preview.convertFromImage(
      Offset(box.right - box.width * 0.22, box.top - box.height * 0.15),
      frame.image,
    );
    final size = box.width * 0.35;
    _drawEmoji(canvas, '🐰', left, size);
    _drawEmoji(canvas, '🐰', right, size);
  }

  void _drawSunglasses(Canvas canvas, Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    if (leftEye == null || rightEye == null) {
      _drawAboveFace(canvas, face, emoji: '😎', scale: 1.0, yOffset: 0.35);
      return;
    }

    final left = preview.convertFromImage(
      Offset(leftEye.position.x.toDouble(), leftEye.position.y.toDouble()),
      frame.image,
    );
    final right = preview.convertFromImage(
      Offset(rightEye.position.x.toDouble(), rightEye.position.y.toDouble()),
      frame.image,
    );
    final center = Offset((left.dx + right.dx) / 2, (left.dy + right.dy) / 2);
    final width = (right.dx - left.dx).abs() * 2.2;
    _drawEmoji(canvas, '😎', center, width);
  }

  void _drawOnLandmark(
    Canvas canvas,
    Face face,
    FaceLandmarkType type,
    String emoji,
    double size,
  ) {
    final landmark = face.landmarks[type];
    if (landmark == null) return;
    final point = preview.convertFromImage(
      Offset(landmark.position.x.toDouble(), landmark.position.y.toDouble()),
      frame.image,
    );
    _drawEmoji(canvas, emoji, point, size);
  }

  void _drawEmoji(Canvas canvas, String emoji, Offset center, double size) {
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

  @override
  bool shouldRepaint(CameraArEffectsPainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.effect != effect;
  }
}

class CameraScreenEffectsLayer extends StatefulWidget {
  const CameraScreenEffectsLayer({super.key, required this.effect});

  final CameraEffectDefinition effect;

  @override
  State<CameraScreenEffectsLayer> createState() =>
      _CameraScreenEffectsLayerState();
}

class _CameraScreenEffectsLayerState extends State<CameraScreenEffectsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.effect.isScreenEffect) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: CameraScreenEffectsPainter(
              effect: widget.effect,
              progress: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class CameraScreenEffectsPainter extends CustomPainter {
  CameraScreenEffectsPainter({required this.effect, required this.progress});

  final CameraEffectDefinition effect;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    switch (effect.id) {
      case CameraEffectId.sparkle:
        _paintSparkle(canvas, size);
      case CameraEffectId.neon:
        _paintNeon(canvas, size);
      case CameraEffectId.glitch:
        _paintGlitch(canvas, size);
      default:
        break;
    }
  }

  void _paintSparkle(Canvas canvas, Size size) {
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
      _drawEmojiAt(canvas, '✨', Offset(x, y), 16 + random.nextDouble() * 10);
    }
  }

  void _paintNeon(Canvas canvas, Size size) {
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

  void _paintGlitch(Canvas canvas, Size size) {
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

  void _drawEmojiAt(Canvas canvas, String emoji, Offset center, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(CameraScreenEffectsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.effect != effect;
  }
}
