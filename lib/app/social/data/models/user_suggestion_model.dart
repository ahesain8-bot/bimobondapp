import 'package:bimobondapp/app/social/data/models/social_user_model.dart';
import 'package:bimobondapp/app/social/domain/entities/user_suggestion_entity.dart';

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
    super.isFollowedBy = false,
  });

  factory UserSuggestionModel.fromJson(Map<String, dynamic> json) {
    final social = SocialUserModel.fromJson(json);

    return UserSuggestionModel(
      id: social.id,
      username: social.username,
      fullName: social.fullName,
      avatarUrl: social.avatarUrl,
      isVerified: json['isVerified'] as bool? ?? false,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      mutualCount: (json['mutualCount'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString(),
      isFollowing: social.isFollowing,
      isFollowedBy: social.isFollowedBy,
    );
  }
}
