import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Downloads and registers template fonts for Flutter [TextStyle.fontFamily].
class TemplateFontCache {
  TemplateFontCache._();

  static final Set<String> _loaded = {};
  static final Map<String, Future<bool>> _inflight = {};

  static String familyFor(String fontAssetId) => 'tpl_font_$fontAssetId';

  static bool isLoaded(String fontAssetId) =>
      _loaded.contains(familyFor(fontAssetId));

  /// Load font bytes from [url] and register as [familyFor(fontAssetId)].
  static Future<bool> load({
    required String fontAssetId,
    required String url,
  }) async {
    if (fontAssetId.isEmpty || url.trim().isEmpty) return false;
    final family = familyFor(fontAssetId);
    if (_loaded.contains(family)) return true;
    final existing = _inflight[family];
    if (existing != null) return existing;

    final future = _loadOnce(family: family, url: url);
    _inflight[family] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(family);
    }
  }

  static Future<bool> _loadOnce({
    required String family,
    required String url,
  }) async {
    try {
      final absolute = MediaUtils.resolveAbsoluteUrl(url);
      if (absolute.isEmpty) return false;
      final res = await http.get(Uri.parse(absolute)).timeout(
        const Duration(seconds: 20),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('TemplateFontCache HTTP ${res.statusCode} for $absolute');
        return false;
      }
      if (res.bodyBytes.isEmpty) return false;
      // Copy bytes — response buffer must not be reused after FontLoader.
      final bytes = Uint8List.fromList(res.bodyBytes);
      final loader = FontLoader(family);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loaded.add(family);
      return true;
    } catch (e, st) {
      debugPrint('TemplateFontCache.load($family): $e\n$st');
      return false;
    }
  }
}
