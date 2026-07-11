import 'dart:math' as math;

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_asset_loader.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_placement.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_effect_mapper.dart';
import 'package:flutter/material.dart';

/// Paints camera effects using API placement metadata from `/camera-studio/catalog`.
class CameraEffectImagePainter {
  CameraEffectImagePainter._();

  static Future<void> preloadAsset(String? url) =>
      CameraEffectAssetLoader.preload(url);

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
    if (effect.isNone) return;

    final placement = _resolvePlacement(face, effect.placement);
    final anchor = placement.anchorType;
    if (anchor == null || anchor == CameraEffectAnchorType.screen) return;

    switch (anchor) {
      case CameraEffectAnchorType.onFace:
        _paintOnFace(canvas, face, effect, placement);
      case CameraEffectAnchorType.coverFace:
        _paintCoverFace(canvas, face, effect, placement);
      case CameraEffectAnchorType.aboveFace:
        _paintAboveFace(canvas, face, effect, placement);
      case CameraEffectAnchorType.dualAboveFace:
        _paintDualAboveFace(canvas, face, effect, placement);
      case CameraEffectAnchorType.betweenLandmarks:
        _paintBetweenLandmarks(canvas, face, effect, placement);
      case CameraEffectAnchorType.onLandmark:
        _paintOnLandmark(canvas, face, effect, placement, all: false);
      case CameraEffectAnchorType.onLandmarks:
        _paintOnLandmark(canvas, face, effect, placement, all: true);
      case CameraEffectAnchorType.screen:
        break;
    }
  }

  static CameraEffectPlacement _resolvePlacement(
    ScreenFace face,
    CameraEffectPlacement placement,
  ) {
    final needsLandmarks =
        placement.anchorType == CameraEffectAnchorType.betweenLandmarks ||
        placement.anchorType == CameraEffectAnchorType.onLandmark ||
        placement.anchorType == CameraEffectAnchorType.onLandmarks;

    if (!needsLandmarks) return placement;

    final keys = placement.anchorLandmarks.isNotEmpty
        ? placement.anchorLandmarks
        : _defaultLandmarksFor(placement.anchorType);
    final missing = keys.any((key) => !face.landmarks.containsKey(key));
    if (!missing) return placement;

    final fallback = placement.fallbackAnchorType;
    if (fallback == null) return placement;

    return placement.copyWith(
      anchorType: fallback,
      scaleFactor: placement.fallbackScaleFactor ?? placement.scaleFactor,
      offsetX: placement.offsetX,
      offsetY: placement.fallbackOffsetY ?? placement.offsetY,
    );
  }

  static List<CameraFaceLandmarkType> _defaultLandmarksFor(
    CameraEffectAnchorType? anchor,
  ) {
    return switch (anchor) {
      CameraEffectAnchorType.betweenLandmarks => const [
          CameraFaceLandmarkType.leftEye,
          CameraFaceLandmarkType.rightEye,
        ],
      CameraEffectAnchorType.onLandmark ||
      CameraEffectAnchorType.onLandmarks =>
        const [CameraFaceLandmarkType.noseBase],
      _ => const [],
    };
  }

  static void _paintOnFace(
    Canvas canvas,
    ScreenFace face,
    CameraEffectDefinition effect,
    CameraEffectPlacement placement,
  ) {
    final box = face.boundingBox;
    final scale = placement.scaleFactor ?? 1;
    final offsetX = (placement.offsetX ?? 0) * box.width;
    final offsetY = (placement.offsetY ?? 0) * box.height;
    final center = box.center + Offset(offsetX, offsetY);
    final size = _faceStickerSize(box.width, scale, effect.hasAsset);
    _drawSticker(canvas, effect, center, size);
  }

  static void _paintCoverFace(
    Canvas canvas,
    ScreenFace face,
    CameraEffectDefinition effect,
    CameraEffectPlacement placement,
  ) {
    final box = face.boundingBox;
    final scale = placement.scaleFactor ?? 1;
    final offsetX = (placement.offsetX ?? 0) * box.width;
    final offsetY = (placement.offsetY ?? 0) * box.height;
    final center = box.center + Offset(offsetX, offsetY);
    final rect = Rect.fromCenter(
      center: center,
      width: box.width * scale,
      height: box.height * scale,
    );
    _drawStickerInRect(canvas, effect, rect, fit: BoxFit.cover);
  }

  static void _paintAboveFace(
    Canvas canvas,
    ScreenFace face,
    CameraEffectDefinition effect,
    CameraEffectPlacement placement,
  ) {
    final box = face.boundingBox;
    final scale = placement.scaleFactor ?? 1;
    final offsetX = (placement.offsetX ?? 0) * box.width;
    final offsetY = placement.offsetY ?? -0.55;
    final center = Offset(
      box.center.dx + offsetX,
      box.top + box.height * offsetY,
    );
    final size = _faceStickerSize(box.width, scale, effect.hasAsset);
    _drawSticker(canvas, effect, center, size);
  }

  static void _paintDualAboveFace(
    Canvas canvas,
    ScreenFace face,
    CameraEffectDefinition effect,
    CameraEffectPlacement placement,
  ) {
    final box = face.boundingBox;
    final scale = placement.scaleFactor ?? 0.35;
    final offsetX = placement.offsetX ?? 0.22;
    final offsetY = placement.offsetY ?? -0.15;
    final size = box.width * scale;
    final y = box.top + box.height * offsetY;
    final left = Offset(box.left + box.width * offsetX, y);
    final right = Offset(box.right - box.width * offsetX, y);
    _drawSticker(canvas, effect, left, size);
    _drawSticker(canvas, effect, right, size);
  }

  static void _paintBetweenLandmarks(
    Canvas canvas,
    ScreenFace face,
    CameraEffectDefinition effect,
    CameraEffectPlacement placement,
  ) {
    final keys = placement.anchorLandmarks.length >= 2
        ? placement.anchorLandmarks.take(2).toList()
        : const [
            CameraFaceLandmarkType.leftEye,
            CameraFaceLandmarkType.rightEye,
          ];
    final first = face.landmarks[keys[0]];
    final second = face.landmarks[keys[1]];
    if (first == null || second == null) {
      final fallback = placement.fallbackAnchorType == CameraEffectAnchorType.onFace
          ? placement.copyWith(
              anchorType: CameraEffectAnchorType.onFace,
              offsetY: placement.fallbackOffsetY ?? -0.2,
              scaleFactor: placement.fallbackScaleFactor ?? placement.scaleFactor,
            )
          : placement;
      _paintOnFace(canvas, face, effect, fallback);
      return;
    }

    final eyeSpan = (second.dx - first.dx).abs();
    final center = Offset(
      (first.dx + second.dx) / 2 + (placement.offsetX ?? 0) * eyeSpan,
      (first.dy + second.dy) / 2 + (placement.offsetY ?? 0) * eyeSpan,
    );
    final width = eyeSpan * (placement.scaleFactor ?? 2.2);

    if (effect.hasAsset) {
      final rect = Rect.fromCenter(
        center: center,
        width: width,
        height: width * 0.42,
      );
      _drawStickerInRect(canvas, effect, rect, fit: BoxFit.contain);
      return;
    }

    _drawSticker(canvas, effect, center, width);
  }

  static void _paintOnLandmark(
    Canvas canvas,
    ScreenFace face,
    CameraEffectDefinition effect,
    CameraEffectPlacement placement, {
    required bool all,
  }) {
    final keys = placement.anchorLandmarks.isNotEmpty
        ? placement.anchorLandmarks
        : const [CameraFaceLandmarkType.noseBase];
    final targets = all ? keys : [keys.first];
    final landmarkSize = placement.landmarkSize ?? 0.2;
    final size = face.boundingBox.width * landmarkSize;

    for (final key in targets) {
      final point = face.landmarks[key];
      if (point == null) continue;
      _drawSticker(canvas, effect, point, size);
    }
  }

  static void paintScreen(
    Canvas canvas,
    Size size,
    CameraEffectDefinition effect, {
    double progress = 0.35,
  }) {
    if (effect.hasAsset) {
      _drawStickerInRect(
        canvas,
        effect,
        Offset.zero & size,
        fit: BoxFit.cover,
      );
      return;
    }

    switch (effect.slug) {
      case 'sparkle':
        _paintSparkle(canvas, size, progress);
      case 'neon':
        _paintNeon(canvas, size, progress);
      case 'glitch':
        _paintGlitch(canvas, size, progress);
      default:
        break;
    }
  }

  static double _faceStickerSize(
    double faceWidth,
    double scaleFactor,
    bool hasAsset,
  ) {
    // EFFECTS_API: emoji ≈ face.width × scaleFactor × 0.45; assets are proportional.
    if (hasAsset) return faceWidth * scaleFactor;
    return faceWidth * scaleFactor * 0.45;
  }

  static void _drawSticker(
    Canvas canvas,
    CameraEffectDefinition effect,
    Offset center,
    double size,
  ) {
    final rect = Rect.fromCenter(center: center, width: size, height: size);
    _drawStickerInRect(canvas, effect, rect, fit: BoxFit.contain);
  }

  static void _drawStickerInRect(
    Canvas canvas,
    CameraEffectDefinition effect,
    Rect rect, {
    required BoxFit fit,
  }) {
    final image = CameraEffectAssetLoader.image(effect.assetUrl);
    if (image != null) {
      paintImage(canvas: canvas, rect: rect, image: image, fit: fit);
      return;
    }
    _drawEmoji(canvas, effect.emoji, rect.center, rect.shortestSide * 0.9);
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
