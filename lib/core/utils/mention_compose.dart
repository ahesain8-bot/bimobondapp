/// Active `@mention` being typed at the text cursor.
class ActiveMentionQuery {
  const ActiveMentionQuery({
    required this.start,
    required this.end,
    required this.query,
  });

  /// Index of `@` in the text.
  final int start;

  /// Cursor offset (end of partial mention, exclusive).
  final int end;

  /// Username fragment after `@` (may be empty).
  final String query;
}

/// Detects and completes inline `@username` while composing text.
class MentionCompose {
  MentionCompose._();

  static final RegExp _queryChar = RegExp(
    r'[\w\u0600-\u06FF\u0590-\u05FF]',
    unicode: true,
  );

  /// Finds the `@mention` token the cursor is inside (or just after `@`).
  static ActiveMentionQuery? activeAt(String text, int cursor) {
    if (text.isEmpty) return null;

    final pos = cursor.clamp(0, text.length);

    for (var at = 0; at < text.length; at++) {
      if (text[at] != '@') continue;
      if (at > 0 && _isWordChar(text[at - 1])) continue;

      var tokenEnd = at + 1;
      while (tokenEnd < text.length && _queryChar.hasMatch(text[tokenEnd])) {
        tokenEnd++;
      }

      final insideToken = pos >= at + 1 && pos <= tokenEnd;
      final onBareAt = tokenEnd == at + 1 && (pos == at || pos == at + 1);

      if (!insideToken && !onBareAt) continue;

      final end = pos < at + 1 ? at + 1 : pos;
      final query = text.substring(at + 1, end);
      if (query.contains(' ') ||
          query.contains('.') ||
          query.contains('-')) {
        continue;
      }
      if (query.isNotEmpty && !_isValidQuery(query)) continue;

      return ActiveMentionQuery(start: at, end: end, query: query);
    }
    return null;
  }

  static bool _isWordChar(String char) =>
      RegExp(r'[\w@#]').hasMatch(char);

  static bool _isValidQuery(String query) {
    for (var i = 0; i < query.length; i++) {
      if (!_queryChar.hasMatch(query[i])) return false;
    }
    return true;
  }
}
