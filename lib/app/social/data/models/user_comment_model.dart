import 'package:bimobondapp/app/social/data/models/social_user_model.dart';
import 'package:bimobondapp/app/social/data/models/user_comment_post_model.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comment_entity.dart';

class UserCommentModel extends UserCommentEntity {
  const UserCommentModel({
    required super.id,
    required super.content,
    required super.postId,
    required super.userId,
    super.parentId,
    super.likeCount = 0,
    super.replyCount = 0,
    super.isGift = false,
    super.giftId,
    required super.createdAt,
    required super.updatedAt,
    super.user,
    super.post,
  });

  factory UserCommentModel.fromJson(Map<String, dynamic> json) {
    UserCommentPostModel? post;
    final postRaw = json['post'];
    if (postRaw is Map) {
      post = UserCommentPostModel.fromJson(Map<String, dynamic>.from(postRaw));
    }

    SocialUserModel? author;
    final userRaw = json['user'];
    if (userRaw is Map) {
      author = SocialUserModel.fromJson(Map<String, dynamic>.from(userRaw));
    }

    return UserCommentModel(
      id: (json['id'] ?? '').toString(),
      content: json['content']?.toString() ?? '',
      postId: (json['postId'] ?? post?.id ?? '').toString(),
      userId: (json['userId'] ?? author?.id ?? '').toString(),
      parentId: json['parentId']?.toString(),
      likeCount: _parseInt(json['likeCount']) ?? 0,
      replyCount: _parseInt(json['replyCount']) ?? 0,
      isGift: json['isGift'] is bool
          ? json['isGift'] as bool
          : json['isGift']?.toString().toLowerCase() == 'true',
      giftId: json['giftId']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      user: author,
      post: post,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
