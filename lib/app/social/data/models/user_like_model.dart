import 'package:bimobondapp/app/posts/data/models/post_model.dart';
import 'package:bimobondapp/app/social/data/models/social_user_model.dart';
import 'package:bimobondapp/app/social/domain/entities/user_like_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

class UserLikeModel extends UserLikeEntity {
  const UserLikeModel({
    required super.id,
    required super.postId,
    required super.createdAt,
    super.user,
    super.post,
  });

  factory UserLikeModel.fromJson(Map<String, dynamic> json) {
    final postRaw = json['post'];
    PostModel? post;
    if (postRaw is Map) {
      final postJson = Map<String, dynamic>.from(postRaw);
      final thumb = postJson['thumbnailUrl']?.toString();
      if (thumb != null &&
          thumb.isNotEmpty &&
          MediaUtils.isVideo(thumb) &&
          (postJson['videoUrl'] == null ||
              postJson['videoUrl'].toString().isEmpty)) {
        postJson['videoUrl'] = thumb;
        postJson['type'] = postJson['type'] ?? 'VIDEO';
      }
      post = PostModel.fromJson(postJson);
    }

    SocialUserModel? user;
    final userRaw = json['user'] ?? json['liker'] ?? json['likedBy'];
    if (userRaw is Map) {
      user = SocialUserModel.fromJson(Map<String, dynamic>.from(userRaw));
    } else {
      final userId = json['userId']?.toString();
      if (userId != null && userId.isNotEmpty) {
        user = SocialUserModel(id: userId);
      }
    }

    final postId = json['postId']?.toString() ?? post?.id ?? '';

    return UserLikeModel(
      id: json['id']?.toString() ?? '${user?.id ?? 'unknown'}-$postId',
      postId: postId,
      createdAt: json['createdAt']?.toString() ??
          json['likedAt']?.toString() ??
          '',
      user: user,
      post: post,
    );
  }
}
