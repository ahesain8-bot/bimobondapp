import 'dart:ui' as ui;

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Loads and caches effect sticker PNGs from [assetUrl] (absolute or API-relative).
class CameraEffectAssetLoader {
  CameraEffectAssetLoader._();

  static final Map<String, ui.Image> _cache = {};

  static String? resolveUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(raw);
  }

  static bool hasAsset(String? raw) => resolveUrl(raw) != null;

  static ui.Image? image(String? raw) {
    final url = resolveUrl(raw);
    if (url == null) return null;
    return _cache[url];
  }

  static bool isReady(String? raw) {
    final url = resolveUrl(raw);
    if (url == null) return true;
    return _cache.containsKey(url);
  }

  static Future<void> preload(String? raw) async {
    final url = resolveUrl(raw);
    if (url == null || _cache.containsKey(url)) return;
    try {
      final bytes = url.startsWith('http')
          ? (await http.get(Uri.parse(url))).bodyBytes
          : await rootBundle.load(url).then((data) => data.buffer.asUint8List());
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _cache[url] = frame.image;
    } catch (e, st) {
      debugPrint('CameraEffectAssetLoader preload failed for $url: $e\n$st');
    }
  }

  static Future<void> preloadAll(Iterable<String?> urls) async {
    final unique = urls
        .map(resolveUrl)
        .whereType<String>()
        .where((url) => !_cache.containsKey(url))
        .toSet();
    await Future.wait(unique.map(preload));
  }

  /// UI preview for effect chips/buttons (bundle + network + cached decode).
  static Widget preview({
    required String? raw,
    String? emojiFallback,
    double size = 52,
    BoxFit fit = BoxFit.cover,
  }) {
    final url = resolveUrl(raw);
    if (url == null) {
      return _emojiPreview(emojiFallback, size);
    }

    final cached = _cache[url];
    if (cached != null) {
      return RawImage(
        image: cached,
        fit: fit,
        width: size,
        height: size,
      );
    }

    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: size,
        height: size,
        placeholder: (_, _) => _emojiPreview(emojiFallback, size),
        errorWidget: (_, _, _) => _emojiPreview(emojiFallback, size),
      );
    }

    return Image.asset(
      url,
      fit: fit,
      width: size,
      height: size,
      errorBuilder: (_, _, _) => _emojiPreview(emojiFallback, size),
    );
  }

  static Widget _emojiPreview(String? emoji, double size) {
    if (emoji == null || emoji.isEmpty) {
      return Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.46);
    }
    return Text(emoji, style: TextStyle(fontSize: size * 0.5));
  }
}
