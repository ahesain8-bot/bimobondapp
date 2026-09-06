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
        case 'friends':
        case 'friend':
        case 'mutual':
          return true;
        case 'false':
        case '0':
        case 'unfollowed':
          return false;
      }
    }
    return false;
  }

  static bool? _parseOptionalBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'true':
        case '1':
        case 'followed':
        case 'following':
        case 'friends':
        case 'friend':
        case 'mutual':
          return true;
        case 'false':
        case '0':
        case 'unfollowed':
          return false;
      }
    }
    return null;
  }

  static const _relationshipKeys = [
    'isFollowing',
    'isFollowed',
    'viewerIsFollowing',
    'youFollow',
    'followedByMe',
    'amIFollowing',
    'isFollowedBy',
    'followsYou',
    'isFollower',
    'followsViewer',
    'isFriend',
    'isMutual',
    'friendshipStatus',
  ];

  static Map<String, dynamic> unwrapForParsing(Map<String, dynamic> json) {
    for (final key in ['user', 'friend', 'followedUser', 'follower', 'profile']) {
      final nested = json[key];
      if (nested is Map) {
        final user = Map<String, dynamic>.from(nested);
        user.putIfAbsent('id', () => json['userId'] ?? json['friendId']);
        // Viewer↔user flags live on the list item; nested profiles often omit
        // them or default isFollowing to false and would incorrectly keep
        // "Follow back" for people you already follow.
        for (final relKey in _relationshipKeys) {
          if (json.containsKey(relKey)) {
            user[relKey] = json[relKey];
          }
        }
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

    final isFriend = _parseBool(
          data['isFriend'] ?? json['isFriend'],
        ) ||
        _parseBool(data['isMutual'] ?? json['isMutual']) ||
        _parseBool(data['friendshipStatus'] ?? json['friendshipStatus']);

    final parsedFollowing = _parseOptionalBool(
      data['isFollowing'] ??
          data['isFollowed'] ??
          data['viewerIsFollowing'] ??
          data['youFollow'] ??
          data['followedByMe'] ??
          data['amIFollowing'] ??
          json['isFollowing'],
    );

    final parsedFollowedBy = _parseOptionalBool(
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
      isFollowing: isFriend || (parsedFollowing ?? false),
      isFollowedBy: isFriend || (parsedFollowedBy ?? false),
    );
  }
}
