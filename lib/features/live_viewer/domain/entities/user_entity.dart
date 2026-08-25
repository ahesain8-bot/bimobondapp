import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final bool isVerified;
  final bool isFollowing;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;

  const UserEntity({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isVerified = false,
    this.isFollowing = false,
    this.createdAt,
    this.lastActiveAt,
  });

  String get displayUsername => displayName ?? username;

  UserEntity copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    int? followersCount,
    int? followingCount,
    bool? isVerified,
    bool? isFollowing,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isVerified: isVerified ?? this.isVerified,
      isFollowing: isFollowing ?? this.isFollowing,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    username,
    displayName,
    avatarUrl,
    bio,
    followersCount,
    followingCount,
    isVerified,
    isFollowing,
    createdAt,
    lastActiveAt,
  ];
}
