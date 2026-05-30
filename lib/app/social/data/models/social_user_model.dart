import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

class SocialUserModel extends SocialUserEntity {
  const SocialUserModel({
    required super.id,
    super.username,
    super.fullName,
    super.avatarUrl,
    super.isActive,
    super.isFollowing = false,
    super.isFollowedBy = false,
  });

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'true':
        case '1':
        case 'followed':
        case 'following':
          return true;
        case 'false':
        case '0':
        case 'unfollowed':
          return false;
      }
    }
    return false;
  }

  factory SocialUserModel.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatarUrl'] ??
        json['avatar'] ??
        json['image'] ??
        json['profileImage'];

    final isFollowing = _parseBool(
      json['isFollowing'] ??
          json['isFollowed'] ??
          json['viewerIsFollowing'] ??
          json['youFollow'],
    );

    final isFollowedBy = _parseBool(
      json['isFollowedBy'] ??
          json['followsYou'] ??
          json['isFollower'] ??
          json['followsViewer'],
    );

    return SocialUserModel(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      username: json['username']?.toString(),
      fullName: json['fullName']?.toString() ?? json['name']?.toString(),
      avatarUrl: avatar != null
          ? MediaUtils.resolveAbsoluteUrl(avatar.toString())
          : null,
      isActive: json['isActive'] as bool? ?? json['active'] as bool?,
      isFollowing: isFollowing,
      isFollowedBy: isFollowedBy,
    );
  }
}
