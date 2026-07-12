import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_effect_mapper.dart';
import 'package:flutter/material.dart';

/// Draws face box + landmark dots/labels for live AR debugging.
class CameraFaceLandmarkDebugPainter {
  CameraFaceLandmarkDebugPainter._();

  static const _colors = <CameraFaceLandmarkType, Color>{
    CameraFaceLandmarkType.leftEye: Color(0xFF00E5FF),
    CameraFaceLandmarkType.rightEye: Color(0xFF00E5FF),
    CameraFaceLandmarkType.noseBase: Color(0xFFFFEA00),
    CameraFaceLandmarkType.mouth: Color(0xFFFF1744),
    CameraFaceLandmarkType.leftEar: Color(0xFF76FF03),
    CameraFaceLandmarkType.rightEar: Color(0xFF76FF03),
  };

  static const _labels = <CameraFaceLandmarkType, String>{
    CameraFaceLandmarkType.leftEye: 'L-Eye',
    CameraFaceLandmarkType.rightEye: 'R-Eye',
    CameraFaceLandmarkType.noseBase: 'Nose',
    CameraFaceLandmarkType.mouth: 'Mouth',
    CameraFaceLandmarkType.leftEar: 'L-Ear',
    CameraFaceLandmarkType.rightEar: 'R-Ear',
  };

  static void paint(Canvas canvas, List<ScreenFace> faces) {
    for (final face in faces) {
      _paintFace(canvas, face);
    }
  }

  static void _paintFace(Canvas canvas, ScreenFace face) {
    final boxPaint = Paint()
      ..color = const Color(0xFF69F0AE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(face.boundingBox, boxPaint);

    for (final entry in face.landmarks.entries) {
      final color = _colors[entry.key] ?? Colors.white;
      final point = entry.value;

      canvas.drawCircle(
        point,
        6,
        Paint()..color = color.withValues(alpha: 0.35),
      );
      canvas.drawCircle(point, 3.5, Paint()..color = color);

      final label = _labels[entry.key] ?? entry.key.name;
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(blurRadius: 4, color: Colors.black),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, point + const Offset(7, -14));
    }
  }
}
