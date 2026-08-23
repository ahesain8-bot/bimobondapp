import 'package:dio/dio.dart';

/// Lightweight comment and chat message translation via Google & fallback translate endpoints.
class CommentTranslator {
  CommentTranslator._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': '*/*',
      },
    ),
  );

  static final Map<String, String> _cache = {};

  static String _cleanLang(String lang) {
    final code = lang.split('_').first.split('-').first.toLowerCase().trim();
    return code.isEmpty ? 'en' : code;
  }

  static String _cacheKey(String text, String targetLang) =>
      '${_cleanLang(targetLang)}::${text.hashCode}::${text.length}';

  static bool _isInvalidTranslationText(String result) {
    final upper = result.toUpperCase().trim();
    return upper.contains('SELECT TWO DISTINCT LANGUAGES') ||
        upper.contains('INVALID LANGUAGE PAIR') ||
        upper.contains('QUERY LENGTH LIMIT EXCEEDED') ||
        upper.contains('MYMEMORY WARNING') ||
        upper.contains('NO QUERY SPECIFIED');
  }

  /// Automatically resolves distinct target language (translates Arabic to English, or English/Latin to Arabic/AppLang)
  static String resolveTargetLanguage(String text, String appLang) {
    final cleanAppLang = _cleanLang(appLang);
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(text);

    if (hasArabic) {
      return cleanAppLang == 'ar' ? 'en' : cleanAppLang;
    } else {
      return cleanAppLang == 'en' ? 'ar' : cleanAppLang;
    }
  }

  static (String masked, List<String> tags) _maskHashtagsAndMentions(String text) {
    final tags = <String>[];
    final regExp = RegExp(
      r'(#[\w\u0600-\u06FF\u0590-\u05FF]+|@[\w\u0600-\u06FF\u0590-\u05FF\._-]+)',
    );
    int index = 0;
    final masked = text.replaceAllMapped(regExp, (match) {
      final tag = match.group(0)!;
      tags.add(tag);
      final placeholder = ' XTAG${index}X ';
      index++;
      return placeholder;
    });
    return (masked, tags);
  }

  static String _unmaskHashtagsAndMentions(String text, List<String> tags) {
    if (tags.isEmpty) return text;
    var result = text;
    for (int i = 0; i < tags.length; i++) {
      final pattern = RegExp('X\\s*TAG\\s*$i\\s*X', caseSensitive: false);
      result = result.replaceAll(pattern, tags[i]);
    }
    return result;
  }

  /// Translates [text] into appropriate target language. Returns null on failure.
  static Future<String?> translate({
    required String text,
    required String targetLang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final resolvedTarget = resolveTargetLanguage(trimmed, targetLang);
    final key = _cacheKey(trimmed, resolvedTarget);
    final cached = _cache[key];
    if (cached != null) return cached;

    final (maskedText, tags) = _maskHashtagsAndMentions(trimmed);

    // 1. Try Google GTx endpoint
    try {
      final response = await _dio.get<dynamic>(
        'https://translate.googleapis.com/translate_a/single',
        queryParameters: {
          'client': 'gtx',
          'sl': 'auto',
          'tl': resolvedTarget,
          'dt': 't',
          'q': maskedText,
        },
      );

      final translatedRaw = _parseTranslatedText(response.data);
      if (translatedRaw != null &&
          translatedRaw.trim().isNotEmpty &&
          !_isInvalidTranslationText(translatedRaw)) {
        final finalResult = _unmaskHashtagsAndMentions(translatedRaw.trim(), tags);
        if (finalResult.trim() != trimmed) {
          _cache[key] = finalResult.trim();
          return finalResult.trim();
        }
      }
    } catch (_) {}

    // 2. Fallback to MyMemory translation API
    try {
      final sourceLang = resolvedTarget == 'ar' ? 'en' : 'ar';
      final response = await _dio.get<dynamic>(
        'https://api.mymemory.translated.net/get',
        queryParameters: {
          'q': maskedText,
          'langpair': '$sourceLang|$resolvedTarget',
        },
      );

      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final responseData = data['responseData'];
        if (responseData is Map) {
          final translatedRaw = responseData['translatedText']?.toString();
          if (translatedRaw != null &&
              translatedRaw.trim().isNotEmpty &&
              !_isInvalidTranslationText(translatedRaw)) {
            final finalResult = _unmaskHashtagsAndMentions(translatedRaw.trim(), tags);
            if (finalResult.trim() != trimmed) {
              _cache[key] = finalResult.trim();
              return finalResult.trim();
            }
          }
        }
      }
    } catch (_) {}

    return null;
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
