import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/home/presentation/utils/media_text_font_styles.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_overlay.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Bakes text stickers onto an image at full resolution.
///
/// Overlay centers are image-normalized. [previewSize] scales font size so
/// baked text matches on-screen size.
class MediaTextBaker {
  const MediaTextBaker._();

  static Future<File> bake({
    required File input,
    required List<MediaTextOverlay> overlays,
    required Size previewSize,
  }) async {
    if (overlays.isEmpty ||
        previewSize.width <= 0 ||
        previewSize.height <= 0) {
      return input;
    }

    final bytes = await input.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    if (imgW <= 0 || imgH <= 0) {
      image.dispose();
      return input;
    }

    final displayScale = _minOf(
      previewSize.width / imgW,
      previewSize.height / imgH,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());

    _paintOverlays(
      canvas: canvas,
      overlays: overlays,
      previewSize: previewSize,
      imgW: imgW,
      imgH: imgH,
      displayScale: displayScale,
    );

    final picture = recorder.endRecording();
    final out = await picture.toImage(image.width, image.height);
    image.dispose();
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    if (data == null) return input;

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/text_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
  }

  /// Renders text overlays onto a transparent canvas of [frameSize].
  /// Centers are image-normalized; [previewSize] scales font size.
  static Future<File?> bakeOverlayPng({
    required List<MediaTextOverlay> overlays,
    required Size previewSize,
    required Size frameSize,
  }) async {
    final hasText = overlays.any((o) => o.text.trim().isNotEmpty);
    if (!hasText ||
        previewSize.width <= 0 ||
        previewSize.height <= 0 ||
        frameSize.width <= 0 ||
        frameSize.height <= 0) {
      return null;
    }

    final imgW = frameSize.width;
    final imgH = frameSize.height;
    final displayScale = _maxOf(
      previewSize.width / imgW,
      previewSize.height / imgH,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    _paintOverlays(
      canvas: canvas,
      overlays: overlays,
      previewSize: previewSize,
      imgW: imgW,
      imgH: imgH,
      displayScale: displayScale,
    );

    final picture = recorder.endRecording();
    final out = await picture.toImage(imgW.round(), imgH.round());
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    if (data == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/vtext_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
  }

  static void _paintOverlays({
    required Canvas canvas,
    required List<MediaTextOverlay> overlays,
    required Size previewSize,
    required double imgW,
    required double imgH,
    required double displayScale,
  }) {
    for (final overlay in overlays) {
      final text = overlay.text.trim();
      if (text.isEmpty) continue;

      final imgX = overlay.center.dx * imgW;
      final imgY = overlay.center.dy * imgH;

      final fontSize = overlay.fontSize / displayScale;
      final maxWidth = (previewSize.width * 0.9) / displayScale;
      final look = overlay.look;
      final textColor = overlay.resolvedTextColor;
      final fillStyle = MediaTextFontStyles.byId(overlay.fontStyleId).resolve(
        color: textColor,
        fontSize: fontSize,
        decoration: overlay.textDecoration,
        shadows: look == MediaTextLook.none
            ? [
                Shadow(
                  color: Colors.black45,
                  blurRadius: 8 / displayScale,
                  offset: Offset(0, 1 / displayScale),
                ),
              ]
            : null,
      );

      final fillPainter = TextPainter(
        text: TextSpan(text: text, style: fillStyle),
        textAlign: overlay.textAlign,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

      final topLeft = Offset(
        imgX - fillPainter.width / 2,
        imgY - fillPainter.height / 2,
      );

      if (look == MediaTextLook.background) {
        final bg = overlay.resolvedBackground;
        final padH = 10 / displayScale;
        final padV = 4 / displayScale;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            topLeft.dx - padH,
            topLeft.dy - padV,
            fillPainter.width + padH * 2,
            fillPainter.height + padV * 2,
          ),
          Radius.circular(8 / displayScale),
        );
        canvas.drawRRect(rect, Paint()..color = bg);
      }

      if (look == MediaTextLook.outline) {
        final strokeStyle = fillStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 / displayScale
            ..color = Colors.white,
          shadows: null,
        );
        final strokePainter = TextPainter(
          text: TextSpan(text: text, style: strokeStyle),
          textAlign: overlay.textAlign,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxWidth);
        strokePainter.paint(canvas, topLeft);
      }

      fillPainter.paint(canvas, topLeft);
    }
  }

  static double _maxOf(double a, double b) => a > b ? a : b;

  static double _minOf(double a, double b) => a < b ? a : b;
}
