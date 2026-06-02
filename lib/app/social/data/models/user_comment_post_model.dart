import 'package:bimobondapp/app/social/data/models/social_user_model.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comment_post_entity.dart';

class UserCommentPostModel extends UserCommentPostEntity {
  const UserCommentPostModel({
    required super.id,
    super.description,
    super.user,
  });

  factory UserCommentPostModel.fromJson(Map<String, dynamic> json) {
    SocialUserModel? author;
    final userRaw = json['user'];
    if (userRaw is Map) {
      author = SocialUserModel.fromJson(Map<String, dynamic>.from(userRaw));
    }

    return UserCommentPostModel(
      id: (json['id'] ?? '').toString(),
      description: json['description']?.toString(),
      user: author,
    );
  }
}
