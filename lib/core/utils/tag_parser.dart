import 'package:bimobondapp/app/posts/domain/entities/mention_ref_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/mention_user_resolver.dart';

/// Parses @mentions and #hashtags the same way the API `extractTags()` does.
class TagParser {
  TagParser._();

  /// Letters, digits, underscore, and Arabic / Hebrew word characters.
  /// Dots and hyphens stop the token (not included in \w for ASCII hyphen).
  static final RegExp mentionPattern = RegExp(
    r'(?<![@\w])@([\w\u0600-\u06FF\u0590-\u05FF]+)',
    unicode: true,
  );

  static final RegExp hashtagPattern = RegExp(
    r'(?<![#\w])#([\w\u0600-\u06FF\u0590-\u05FF]+)',
    unicode: true,
  );

  static List<String> extractMentionUsernames(String text) {
    final seen = <String>{};
    final out = <String>[];
    for (final match in mentionPattern.allMatches(text)) {
      final name = match.group(1);
      if (name != null && name.isNotEmpty && seen.add(name)) {
        out.add(name);
      }
    }
    return out;
  }

  static List<String> extractHashtagNames(String text) {
    final seen = <String>{};
    final out = <String>[];
    for (final match in hashtagPattern.allMatches(text)) {
      final name = match.group(1);
      if (name != null && name.isNotEmpty && seen.add(name)) {
        out.add(name);
      }
    }
    return out;
  }
}

/// Maps @username tokens in [text] to user IDs from API [mentions].
class MentionRefUtils {
  MentionRefUtils._();

  static Map<String, String> usernameToUserIdMap(
    String text,
    List<MentionRefEntity> mentions, {
    PostEntity? post,
  }) {
    return MentionUserIdResolver.buildTapMap(text, mentions, post: post);
  }
}
