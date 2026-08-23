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

  static String displayNameForUsernameSync(
    String username, {
    Map<String, String> knownNames = const {},
    PostEntity? post,
  }) {
    final fromMap = lookupInMap(username, knownNames);
    if (fromMap != null && fromMap.trim().isNotEmpty) return fromMap.trim();

    final author = post?.user;
    if (author != null &&
        author.username.isNotEmpty &&
        author.username.toLowerCase() == username.toLowerCase()) {
      final name = author.fullName?.trim() ?? author.username.trim();
      if (name.isNotEmpty) return name;
    }

    final friendName = MentionFriendsSource.fullNameForUsernameSync(username);
    if (friendName != null && friendName.trim().isNotEmpty) {
      return friendName.trim();
    }

    return username;
  }

  /// Builds a map of @username → displayName for all tokens in [text].
  static Map<String, String> buildDisplayNameMap(
    String text,
    List<MentionRefEntity> mentions, {
    PostEntity? post,
  }) {
    final map = <String, String>{};

    void put(String username, String displayName) {
      if (username.isEmpty || displayName.isEmpty) return;
      map[username] = displayName;
      map[username.toLowerCase()] = displayName;
    }

    for (final ref in mentions) {
      final display = ref.displayName?.trim() ?? '';
      if (display.isNotEmpty) {
        put(ref.username ?? '', display);
      }
    }

    final tokens = TagParser.extractMentionUsernames(text);
    for (var i = 0; i < tokens.length && i < mentions.length; i++) {
      final display = mentions[i].displayName?.trim() ?? '';
      if (display.isNotEmpty) {
        put(tokens[i], display);
      }
    }

    for (final token in tokens) {
      if (lookupInMap(token, map) != null) continue;
      final fromFriends = MentionFriendsSource.fullNameForUsernameSync(token);
      if (fromFriends != null && fromFriends.isNotEmpty) put(token, fromFriends);
    }

    final author = post?.user;
    if (author != null && author.username.isNotEmpty) {
      final name = author.fullName?.trim() ?? author.username.trim();
      if (name.isNotEmpty) {
        put(author.username, name);
      }
    }

    return map;
  }
}
