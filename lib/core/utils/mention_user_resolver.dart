import 'package:bimobondapp/app/posts/domain/entities/mention_ref_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/social/presentation/services/mention_friends_source.dart';
import 'package:bimobondapp/core/utils/tag_parser.dart';

/// Resolves @username to a user id for profile navigation.
class MentionUserIdResolver {
  MentionUserIdResolver._();

  static String? lookupInMap(String username, Map<String, String> map) {
    if (username.isEmpty) return null;
    return map[username] ?? map[username.toLowerCase()];
  }

  static String? syncResolve(
    String username, {
    Map<String, String> knownIds = const {},
    PostEntity? post,
  }) {
    final fromMap = lookupInMap(username, knownIds);
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;

    final author = post?.user;
    if (author != null &&
        author.username != null &&
        author.username!.toLowerCase() == username.toLowerCase()) {
      return author.id;
    }

    return MentionFriendsSource.userIdForUsernameSync(username);
  }

  static Future<String?> resolve(
    String username, {
    Map<String, String> knownIds = const {},
    PostEntity? post,
  }) async {
    final immediate = syncResolve(
      username,
      knownIds: knownIds,
      post: post,
    );
    if (immediate != null && immediate.isNotEmpty) return immediate;

    await MentionFriendsSource.ensureLoaded();
    return syncResolve(username, knownIds: knownIds, post: post);
  }

  /// Builds a map of @username → userId for all tokens in [text].
  static Map<String, String> buildTapMap(
    String text,
    List<MentionRefEntity> mentions, {
    PostEntity? post,
  }) {
    final map = <String, String>{};

    void put(String username, String userId) {
      if (username.isEmpty || userId.isEmpty) return;
      map[username] = userId;
      map[username.toLowerCase()] = userId;
    }

    for (final ref in mentions) {
      put(ref.username ?? '', ref.userId);
    }

    final tokens = TagParser.extractMentionUsernames(text);
    for (var i = 0; i < tokens.length && i < mentions.length; i++) {
      put(tokens[i], mentions[i].userId);
    }

    for (final token in tokens) {
      if (lookupInMap(token, map) != null) continue;
      final fromFriends = MentionFriendsSource.userIdForUsernameSync(token);
      if (fromFriends != null) put(token, fromFriends);
    }

    final author = post?.user;
    if (author != null && (author.username ?? '').isNotEmpty) {
      put(author.username!, author.id);
    }

    return map;
  }
}
