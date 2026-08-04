import 'package:bimobondapp/app/auth/data/models/user_model.dart';
import 'package:bimobondapp/app/social/domain/entities/profile_visitor_entity.dart';

class ProfileVisitorModel extends ProfileVisitorEntity {
  const ProfileVisitorModel({
    required super.user,
    required super.viewedAt,
    super.isFollowing = false,
    super.isFollowedBy = false,
    super.isFriend = false,
  });

  factory ProfileVisitorModel.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json['user'] is Map
            ? Map<String, dynamic>.from(json['user'] as Map)
            : json;

    final user = UserModel.fromJson(userRaw);

    bool parseBool(dynamic val) {
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) {
        final s = val.toLowerCase();
        return s == 'true' || s == '1';
      }
      return false;
    }

    return ProfileVisitorModel(
      user: user,
      viewedAt: json['viewedAt']?.toString() ?? '',
      isFollowing: parseBool(json['isFollowing'] ?? user.isFollowing),
      isFollowedBy: parseBool(json['isFollowedBy'] ?? user.isFollowedBy),
      isFriend: parseBool(json['isFriend'] ?? user.isFriend),
    );
  }
}
