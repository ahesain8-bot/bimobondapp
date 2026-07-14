import 'dart:async';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:lottie/lottie.dart';

/// In-memory preload cache for gift Lottie animations (faster send/replay).
class GiftLottieCache {
  GiftLottieCache._() {
    Lottie.cache.maximumSize = 40;
  }

  static final GiftLottieCache instance = GiftLottieCache._();

  final Map<String, Future<LottieComposition?>> _loads = {};

  static bool looksLikeLottieUrl(String url) {
    final lower = url.toLowerCase().split('?').first.trim();
    if (lower.isEmpty) return false;
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return false;
    }
    return lower.endsWith('.json') ||
        lower.endsWith('.lottie') ||
        lower.contains('lottie') ||
        lower.contains('/gifts/') ||
        lower.contains('animation');
  }

  static bool looksLikeVideoUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  Future<LottieComposition?> load(String url) {
    final resolved = MediaUtils.resolveAbsoluteUrl(url).trim();
    if (resolved.isEmpty) return Future<LottieComposition?>.value(null);

    return _loads.putIfAbsent(resolved, () async {
      try {
        // Package cache makes a second load() resolve synchronously.
        return await NetworkLottie(
          resolved,
          backgroundLoading: true,
        ).load();
      } catch (_) {
        _loads.remove(resolved);
        return null;
      }
    });
  }

  /// Warm cache when the gift catalog / sheet opens.
  void prefetch(Iterable<String?> urls) {
    for (final url in urls) {
      final value = url?.trim();
      if (value == null || value.isEmpty) continue;
      if (!looksLikeLottieUrl(value)) continue;
      unawaited(load(value));
    }
  }
}
