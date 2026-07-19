import 'package:dio/dio.dart';

/// Lightweight comment translation via Google's public translate endpoint.
class CommentTranslator {
  CommentTranslator._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  static final Map<String, String> _cache = {};

  static String _cacheKey(String text, String targetLang) =>
      '$targetLang::${text.hashCode}::${text.length}';

  /// Translates [text] into [targetLang] (e.g. `ar`, `en`). Returns null on failure.
  static Future<String?> translate({
    required String text,
    required String targetLang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final key = _cacheKey(trimmed, targetLang);
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final response = await _dio.get<dynamic>(
        'https://translate.googleapis.com/translate_a/single',
        queryParameters: {
          'client': 'gtx',
          'sl': 'auto',
          'tl': targetLang,
          'dt': 't',
          'q': trimmed,
        },
      );

      final translated = _parseTranslatedText(response.data);
      if (translated == null || translated.trim().isEmpty) return null;

      _cache[key] = translated;
      return translated;
    } catch (_) {
      return null;
    }
  }

  static String? _parseTranslatedText(dynamic data) {
    if (data is! List || data.isEmpty) return null;
    final chunks = data.first;
    if (chunks is! List) return null;

    final buffer = StringBuffer();
    for (final chunk in chunks) {
      if (chunk is List && chunk.isNotEmpty && chunk.first is String) {
        buffer.write(chunk.first as String);
      }
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? null : result;
  }
}
