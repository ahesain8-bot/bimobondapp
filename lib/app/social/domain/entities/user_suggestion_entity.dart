import 'package:equatable/equatable.dart';

class UserSuggestionEntity extends Equatable {
  const UserSuggestionEntity({
    required this.id,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.isVerified = false,
    this.followerCount = 0,
    this.mutualCount = 0,
    this.reason,
    this.isFollowing = false,
  });

  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final bool isVerified;
  final int followerCount;
  final int mutualCount;
  final String? reason;
  final bool isFollowing;

  String get displayName =>
      (fullName?.trim().isNotEmpty == true ? fullName : username) ?? 'User';

  factory UserSuggestionEntity.from(UserSuggestionEntity other) {
    return UserSuggestionEntity(
      id: other.id,
      username: other.username,
      fullName: other.fullName,
      avatarUrl: other.avatarUrl,
      isVerified: other.isVerified,
      followerCount: other.followerCount,
      mutualCount: other.mutualCount,
      reason: other.reason,
      isFollowing: other.isFollowing,
    );
  }

  UserSuggestionEntity copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    bool? isVerified,
    int? followerCount,
    int? mutualCount,
    String? reason,
    bool? isFollowing,
  }) {
    return UserSuggestionEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      followerCount: followerCount ?? this.followerCount,
      mutualCount: mutualCount ?? this.mutualCount,
      reason: reason ?? this.reason,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        fullName,
        avatarUrl,
        isVerified,
        followerCount,
        mutualCount,
        reason,
        isFollowing,
      ];
}
