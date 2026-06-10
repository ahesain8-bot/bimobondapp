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
    this.likedAt,
  });

  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final bool? isActive;
  final bool isFollowing;
  final bool isFollowedBy;

  /// When this user liked a post (post likes / story insights only).
  final DateTime? likedAt;

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
    DateTime? likedAt,
  }) {
    return SocialUserEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
      likedAt: likedAt ?? this.likedAt,
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
        likedAt,
      ];
}
