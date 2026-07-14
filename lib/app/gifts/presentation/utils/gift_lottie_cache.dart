import 'dart:async';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:lottie/lottie.dart';

/// In-memory preload cache for gift Lottie animations (faster send/replay).
///
/// Supports classic `.json` Lottie and `.lottie` (dotLottie zip) archives.
class GiftLottieCache {
  GiftLottieCache._() {
    Lottie.cache.maximumSize = 40;
  }

  static final GiftLottieCache instance = GiftLottieCache._();

  final Map<String, Future<LottieComposition?>> _loads = {};

  static bool looksLikeDotLottieUrl(String url) {
    final lower = url.toLowerCase().split('?').first.trim();
    return lower.endsWith('.lottie');
  }

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

  /// Decodes `.lottie` zip packages (and gzip `.tgs`); returns null for raw JSON
  /// so [LottieComposition.fromBytes] can parse it normally.
  static Future<LottieComposition?> giftDecoder(List<int> bytes) async {
    if (bytes.length < 2) return null;

    // PK zip → `.lottie` / dotLottie
    if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return LottieComposition.decodeZip(
        bytes,
        filePicker: (files) {
          // Prefer real animation JSON inside the .lottie archive.
          for (final file in files) {
            final name = file.name.replaceAll('\\', '/');
            if (name.startsWith('animations/') && name.endsWith('.json')) {
              return file;
            }
          }
          for (final file in files) {
            final name = file.name.replaceAll('\\', '/').toLowerCase();
            if (name.endsWith('.json') && !name.endsWith('manifest.json')) {
              return file;
            }
          }
          return null;
        },
      );
    }

    // gzip → Telegram stickers / compressed Lottie
    if (bytes[0] == 31 && bytes[1] == 139) {
      return LottieComposition.decodeGZip(bytes);
    }

    return null;
  }

  Future<LottieComposition?> load(String url) {
    final resolved = MediaUtils.resolveAbsoluteUrl(url).trim();
    if (resolved.isEmpty) return Future<LottieComposition?>.value(null);

    return _loads.putIfAbsent(resolved, () async {
      try {
        // Always use giftDecoder so `.lottie` archives pick the real animation
        // JSON (not manifest.json). Plain `.json` still works via fallback.
        return await NetworkLottie(
          resolved,
          backgroundLoading: true,
          decoder: giftDecoder,
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
