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
    final commentRaw = json['comment'];
    final postRaw = json['post'] ?? (commentRaw is Map ? commentRaw['post'] : null);

    PostModel? post;
    if (postRaw is Map) {
      post = PostModel.fromJson(Map<String, dynamic>.from(postRaw));
    } else if (_looksLikePost(json)) {
      post = PostModel.fromJson(json);
    }

    final commentMap = commentRaw is Map
        ? Map<String, dynamic>.from(commentRaw)
        : null;

    final sourceType = _parseSourceType(json, commentMap: commentMap);
    final commentId = json['commentId']?.toString() ??
        commentMap?['id']?.toString();

    final content = _firstNonEmpty([
      json['content']?.toString(),
      json['text']?.toString(),
      commentMap?['content']?.toString(),
      post?.description,
    ]);

    final postId = _firstNonEmpty([
      json['postId']?.toString(),
      commentMap?['postId']?.toString(),
      post?.id,
    ])!;

    SocialUserModel? user;
    final userRaw = json['user'] ?? commentMap?['user'];
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
      id: json['id']?.toString() ??
          commentId ??
          postId,
      sourceType: sourceType,
      postId: postId,
      commentId: commentId,
      content: content ?? '',
      createdAt: _firstNonEmpty([
        json['createdAt']?.toString(),
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
