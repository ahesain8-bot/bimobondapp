import 'package:equatable/equatable.dart';

enum SocialFollowButtonMode { hidden, follow, followBack, following }

class SocialUserEntity extends Equatable {
  const SocialUserEntity({
    required this.id,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.isActive,
    this.isFollowing = false,
    this.isFollowedBy = false,
  });

  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final bool? isActive;
  final bool isFollowing;
  final bool isFollowedBy;

  String get displayName =>
      (fullName?.trim().isNotEmpty == true ? fullName : username) ?? 'User';

  SocialFollowButtonMode followButtonMode({required bool isSelf}) {
    if (isSelf) return SocialFollowButtonMode.hidden;
    if (isFollowing) return SocialFollowButtonMode.following;
    if (isFollowedBy) return SocialFollowButtonMode.followBack;
    return SocialFollowButtonMode.follow;
  }

  SocialUserEntity copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    bool? isActive,
    bool? isFollowing,
    bool? isFollowedBy,
  }) {
    return SocialUserEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        fullName,
        avatarUrl,
        isActive,
        isFollowing,
        isFollowedBy,
      ];
}
