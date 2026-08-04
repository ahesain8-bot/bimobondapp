import 'package:flutter/material.dart';

/// High-performance CustomPainter for rendering video progress bar,
/// buffered range, played range, and centered playhead dot knob.
class VideoProgressPainter extends CustomPainter {
  VideoProgressPainter({
    required this.progress,
    required this.bufferedProgress,
    required this.isDragging,
    required this.trackColor,
    required this.bufferedColor,
    required this.progressColor,
    required this.barHeight,
    required this.dotSize,
  });

  final double progress;
  final double bufferedProgress;
  final bool isDragging;
  final Color trackColor;
  final Color bufferedColor;
  final Color progressColor;
  final double barHeight;
  final double dotSize;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final top = centerY - (barHeight / 2);
    final bottom = centerY + (barHeight / 2);
    final width = size.width;

    if (width <= 0 || barHeight <= 0) return;

    final RRect trackRRect = RRect.fromLTRBR(
      0,
      top,
      width,
      bottom,
      Radius.circular(barHeight / 2),
    );

    // 1. Paint Background Track
    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRRect, trackPaint);

    // 2. Paint Buffered Range
    final double bufWidth = (width * bufferedProgress.clamp(0.0, 1.0));
    if (bufWidth > 0) {
      final RRect bufRRect = RRect.fromLTRBR(
        0,
        top,
        bufWidth,
        bottom,
        Radius.circular(barHeight / 2),
      );
      final Paint bufPaint = Paint()
        ..color = bufferedColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(bufRRect, bufPaint);
    }

    // 3. Paint Played Range
    final double playWidth = (width * progress.clamp(0.0, 1.0));
    if (playWidth > 0) {
      final RRect playRRect = RRect.fromLTRBR(
        0,
        top,
        playWidth,
        bottom,
        Radius.circular(barHeight / 2),
      );
      final Paint playPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(playRRect, playPaint);
    }

    // 4. Paint Playhead Dot Knob (Centered both vertically and horizontally when dragging)
    if (isDragging && dotSize > 0 && playWidth > 0) {
      final double dotLeft = (playWidth - dotSize / 2).clamp(0.0, width - dotSize);
      final double dotCenterX = dotLeft + dotSize / 2;
      final Offset dotCenter = Offset(dotCenterX, centerY);

      // Drop shadow behind dot knob
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(dotCenter + const Offset(0, 1), dotSize / 2, shadowPaint);

      // Main White Dot Knob
      final Paint dotPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotCenter, dotSize / 2, dotPaint);

      // Subtle Border around Dot Knob
      final Paint borderPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawCircle(dotCenter, dotSize / 2, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant VideoProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bufferedProgress != bufferedProgress ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.bufferedColor != bufferedColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.dotSize != dotSize;
  }
}
