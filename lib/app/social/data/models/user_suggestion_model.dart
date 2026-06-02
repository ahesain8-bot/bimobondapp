import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

class UserSuggestionModel extends UserSuggestionEntity {
  const UserSuggestionModel({
    required super.id,
    super.username,
    super.fullName,
    super.avatarUrl,
    super.isVerified = false,
    super.followerCount = 0,
    super.mutualCount = 0,
    super.reason,
    super.isFollowing = false,
  });

  factory UserSuggestionModel.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatarUrl'] ?? json['avatar'] ?? json['image'];

    return UserSuggestionModel(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      username: json['username']?.toString(),
      fullName: json['fullName']?.toString() ?? json['name']?.toString(),
      avatarUrl: avatar != null
          ? MediaUtils.resolveAbsoluteUrl(avatar.toString())
          : null,
      isVerified: json['isVerified'] as bool? ?? false,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      mutualCount: (json['mutualCount'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString(),
    );
  }
}
