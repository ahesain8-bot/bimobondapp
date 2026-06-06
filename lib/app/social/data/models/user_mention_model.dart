import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/app/social/data/models/social_user_model.dart';
import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';

class UserMentionModel extends UserMentionEntity {
  const UserMentionModel({
    required super.id,
    required super.sourceType,
    required super.postId,
    super.commentId,
    required super.content,
    required super.createdAt,
    super.user,
    super.post,
  });

  factory UserMentionModel.fromJson(Map<String, dynamic> json) {
    final root = json['mention'] is Map
        ? Map<String, dynamic>.from(json['mention'] as Map)
        : json;

    final commentRaw = root['comment'];
    final postRaw = root['post'] ??
        (commentRaw is Map ? commentRaw['post'] : null) ??
        json['post'];

    PostModel? post;
    if (postRaw is Map) {
      post = PostModel.fromJson(Map<String, dynamic>.from(postRaw));
    } else if (_looksLikePost(root)) {
      post = PostModel.fromJson(root);
    }

    final commentMap = commentRaw is Map
        ? Map<String, dynamic>.from(commentRaw)
        : null;

    final sourceType = _parseSourceType(root, commentMap: commentMap);
    final commentId = root['commentId']?.toString() ??
        commentMap?['id']?.toString();

    final content = _firstNonEmpty([
      root['content']?.toString(),
      root['text']?.toString(),
      commentMap?['content']?.toString(),
      post?.description,
    ]);

    final postId = _firstNonEmpty([
      root['postId']?.toString(),
      root['post_id']?.toString(),
      commentMap?['postId']?.toString(),
      commentMap?['post_id']?.toString(),
      (commentMap?['post'] is Map)
          ? (commentMap!['post'] as Map)['id']?.toString()
          : null,
      post?.id,
    ])!;

    SocialUserModel? user;
    final userRaw = root['user'] ?? commentMap?['user'];
    if (userRaw is Map) {
      user = SocialUserModel.fromJson(Map<String, dynamic>.from(userRaw));
    } else if (post?.user != null) {
      final postUser = post!.user!;
      user = SocialUserModel(
        id: postUser.id,
        username: postUser.username,
        avatarUrl: postUser.avatarUrl,
        isFollowing: postUser.isFollowing ?? false,
      );
    }

    return UserMentionModel(
      id: root['id']?.toString() ??
          commentId ??
          postId,
      sourceType: sourceType,
      postId: postId,
      commentId: commentId,
      content: content ?? '',
      createdAt: _firstNonEmpty([
        root['createdAt']?.toString(),
        commentMap?['createdAt']?.toString(),
        post?.createdAt.toIso8601String(),
      ])!,
      user: user,
      post: post,
    );
  }

  static bool _looksLikePost(Map<String, dynamic> json) {
    return json.containsKey('userId') &&
        (json.containsKey('type') || json.containsKey('description'));
  }

  static UserMentionSourceType _parseSourceType(
    Map<String, dynamic> json, {
    Map<String, dynamic>? commentMap,
  }) {
    final raw = json['type']?.toString().toLowerCase() ??
        json['sourceType']?.toString().toLowerCase() ??
        json['source']?.toString().toLowerCase();

    if (raw != null) {
      if (raw.contains('comment')) return UserMentionSourceType.comment;
      if (raw.contains('post')) return UserMentionSourceType.post;
    }

    if (commentMap != null ||
        json['commentId'] != null ||
        json['comment'] != null) {
      return UserMentionSourceType.comment;
    }

    if (_looksLikePost(json)) return UserMentionSourceType.post;

    return UserMentionSourceType.unknown;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
