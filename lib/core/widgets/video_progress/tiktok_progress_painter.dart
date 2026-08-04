import 'package:flutter/material.dart';

/// High-performance CustomPainter for TikTok-style video progress bar.
///
/// Features:
/// - Transparent background track
/// - Semi-transparent white buffered progress
/// - White played progress
/// - Smoothly animated bar height (driven by external Animation)
/// - Smoothly animated circular thumb with fade (driven by thumbOpacity)
///
/// Only repaints when one of its values actually changes (shouldRepaint guards).
class TikTokProgressPainter extends CustomPainter {
  TikTokProgressPainter({
    required this.progress,
    required this.bufferedProgress,
    required this.barHeight,
    required this.thumbSize,
    required this.thumbOpacity,
    this.bufferedColor = const Color(0x59FFFFFF),
    this.progressColor = Colors.white,
    this.thumbColor = Colors.white,
  });

  final double progress;
  final double bufferedProgress;
  final double barHeight;
  final double thumbSize;
  final double thumbOpacity;
  final Color bufferedColor;
  final Color progressColor;
  final Color thumbColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || barHeight <= 0) return;

    final clampedProgress = progress.clamp(0.0, 1.0);
    final clampedBuffered = bufferedProgress.clamp(0.0, 1.0);

    final centerY = size.height / 2;
    final top = centerY - (barHeight / 2);
    final bottom = centerY + (barHeight / 2);
    final corner = Radius.circular(barHeight / 2);
    final width = size.width;

    final bufferedWidth = width * clampedBuffered;
    if (bufferedWidth > 0) {
      final paint = Paint()
        ..color = bufferedColor
        ..style = PaintingStyle.fill;
      final rrect = RRect.fromLTRBR(0, top, bufferedWidth, bottom, corner);
      canvas.drawRRect(rrect, paint);
    }

    final playedWidth = width * clampedProgress;
    if (playedWidth > 0) {
      final paint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;
      final rrect = RRect.fromLTRBR(0, top, playedWidth, bottom, corner);
      canvas.drawRRect(rrect, paint);
    }

    if (thumbOpacity > 0.0 && thumbSize > 0) {
      final effectiveThumbSize = thumbSize * thumbOpacity;
      if (effectiveThumbSize > 0.5) {
        final halfFull = thumbSize / 2;
        final dotLeft = (playedWidth - halfFull)
            .clamp(0.0, width - thumbSize)
            .toDouble();
        final thumbCenterX = dotLeft + halfFull;
        final thumbCenter = Offset(thumbCenterX, centerY);

        if (thumbOpacity > 0.3) {
          final shadowPaint = Paint()
            ..color = Colors.black.withValues(alpha: 0.35 * thumbOpacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(
            thumbCenter + const Offset(0, 1.5),
            effectiveThumbSize / 2,
            shadowPaint,
          );
        }

        final thumbPaint = Paint()
          ..color = thumbColor.withValues(alpha: thumbOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(thumbCenter, effectiveThumbSize / 2, thumbPaint);

        if (thumbOpacity > 0.5) {
          final borderPaint = Paint()
            ..color = Colors.black.withValues(alpha: 0.15 * thumbOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5;
          canvas.drawCircle(thumbCenter, effectiveThumbSize / 2, borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TikTokProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bufferedProgress != bufferedProgress ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.thumbSize != thumbSize ||
        oldDelegate.thumbOpacity != thumbOpacity ||
        oldDelegate.bufferedColor != bufferedColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.thumbColor != thumbColor;
  }
}
