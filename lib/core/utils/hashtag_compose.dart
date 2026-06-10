/// Active `#hashtag` being typed at the text cursor.
class ActiveHashtagQuery {
  const ActiveHashtagQuery({
    required this.start,
    required this.end,
    required this.query,
  });

  /// Index of `#` in the text.
  final int start;

  /// Cursor offset (end of partial hashtag, exclusive).
  final int end;

  /// Tag fragment after `#` (may be empty).
  final String query;
}

/// Detects and completes inline `#tag` while composing text.
class HashtagCompose {
  HashtagCompose._();

  static final RegExp _queryChar = RegExp(
    r'[\w\u0600-\u06FF\u0590-\u05FF]',
    unicode: true,
  );

  /// Finds the `#hashtag` token the cursor is inside (or just after `#`).
  static ActiveHashtagQuery? activeAt(String text, int cursor) {
    if (text.isEmpty) return null;

    final pos = cursor.clamp(0, text.length);

    for (var hash = 0; hash < text.length; hash++) {
      if (text[hash] != '#') continue;
      if (hash > 0 && _isWordChar(text[hash - 1])) continue;

      var tokenEnd = hash + 1;
      while (tokenEnd < text.length && _queryChar.hasMatch(text[tokenEnd])) {
        tokenEnd++;
      }

      final insideToken = pos >= hash + 1 && pos <= tokenEnd;
      final onBareHash = tokenEnd == hash + 1 && (pos == hash || pos == hash + 1);

      if (!insideToken && !onBareHash) continue;

      final end = pos < hash + 1 ? hash + 1 : pos;
      final query = text.substring(hash + 1, end);
      if (query.contains(' ') ||
          query.contains('.') ||
          query.contains('-')) {
        continue;
      }
      if (query.isNotEmpty && !_isValidQuery(query)) continue;

      return ActiveHashtagQuery(start: hash, end: end, query: query);
    }
    return null;
  }

  static bool _isWordChar(String char) => RegExp(r'[\w@#]').hasMatch(char);

  static bool _isValidQuery(String query) {
    for (var i = 0; i < query.length; i++) {
      if (!_queryChar.hasMatch(query[i])) return false;
    }
    return true;
  }
}
