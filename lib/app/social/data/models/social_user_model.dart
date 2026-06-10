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
    super.likedAt,
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

  static Map<String, dynamic> unwrapForParsing(Map<String, dynamic> json) {
    for (final key in ['user', 'friend', 'followedUser', 'follower', 'profile']) {
      final nested = json[key];
      if (nested is Map) {
        final user = Map<String, dynamic>.from(nested);
        user.putIfAbsent('id', () => json['userId'] ?? json['friendId']);
        return user;
      }
    }
    return json;
  }

  factory SocialUserModel.fromJson(Map<String, dynamic> json) {
    final data = unwrapForParsing(json);
    final avatar =
        data['avatarUrl'] ??
        data['avatar'] ??
        data['image'] ??
        data['profileImage'];

    final isFollowing = _parseBool(
      data['isFollowing'] ??
          data['isFollowed'] ??
          data['viewerIsFollowing'] ??
          data['youFollow'] ??
          json['isFollowing'],
    );

    final isFollowedBy = _parseBool(
      data['isFollowedBy'] ??
          data['followsYou'] ??
          data['isFollower'] ??
          data['followsViewer'] ??
          json['isFollowedBy'],
    );

    return SocialUserModel(
      id: (data['id'] ?? data['userId'] ?? json['userId'] ?? '').toString(),
      username: data['username']?.toString(),
      fullName: data['fullName']?.toString() ?? data['name']?.toString(),
      avatarUrl: avatar != null
          ? MediaUtils.resolveAbsoluteUrl(avatar.toString())
          : null,
      isActive: data['isActive'] as bool? ?? data['active'] as bool?,
      isFollowing: isFollowing,
      isFollowedBy: isFollowedBy,
    );
  }
}
