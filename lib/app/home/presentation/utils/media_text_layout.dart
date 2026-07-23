import 'package:flutter/material.dart';

/// Maps text sticker centers between image-normalized (0..1 of media pixels)
/// and preview-container-normalized (0..1 of the on-screen preview box).
class MediaTextLayout {
  MediaTextLayout._();

  static Rect contentRect(Size imageSize, Size containerSize, BoxFit fit) {
    if (imageSize.width <= 0 ||
        imageSize.height <= 0 ||
        containerSize.width <= 0 ||
        containerSize.height <= 0) {
      return Offset.zero & containerSize;
    }
    final fitted = applyBoxFit(fit, imageSize, containerSize);
    return Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & containerSize,
    );
  }

  static Offset toContainer(
    Offset imageNorm,
    Size imageSize,
    Size containerSize,
    BoxFit fit,
  ) {
    final rect = contentRect(imageSize, containerSize, fit);
    if (containerSize.width <= 0 || containerSize.height <= 0) {
      return imageNorm;
    }
    return Offset(
      (rect.left + imageNorm.dx * rect.width) / containerSize.width,
      (rect.top + imageNorm.dy * rect.height) / containerSize.height,
    );
  }

  static Offset toImage(
    Offset containerNorm,
    Size imageSize,
    Size containerSize,
    BoxFit fit,
  ) {
    final rect = contentRect(imageSize, containerSize, fit);
    if (rect.width <= 0 || rect.height <= 0) return containerNorm;
    return Offset(
      ((containerNorm.dx * containerSize.width - rect.left) / rect.width)
          .clamp(0.0, 1.0),
      ((containerNorm.dy * containerSize.height - rect.top) / rect.height)
          .clamp(0.0, 1.0),
    );
  }

  /// Remaps image-normalized centers into a cropped image's coordinate space.
  static List<T> remapForCrop<T>({
    required List<T> overlays,
    required Size sourceSize,
    required Rect cropRect,
    required Offset Function(T overlay) centerOf,
    required T Function(T overlay, Offset center) copyWithCenter,
  }) {
    if (sourceSize.width <= 0 ||
        sourceSize.height <= 0 ||
        cropRect.width <= 0 ||
        cropRect.height <= 0) {
      return overlays;
    }
    final out = <T>[];
    for (final overlay in overlays) {
      final center = centerOf(overlay);
      final px = center.dx * sourceSize.width;
      final py = center.dy * sourceSize.height;
      final nx = (px - cropRect.left) / cropRect.width;
      final ny = (py - cropRect.top) / cropRect.height;
      if (nx < 0 || nx > 1 || ny < 0 || ny > 1) continue;
      out.add(copyWithCenter(overlay, Offset(nx, ny)));
    }
    return out;
  }
}
