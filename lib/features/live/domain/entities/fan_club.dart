import 'package:equatable/equatable.dart';

/// Fan Club of a creator (lives/mobile-api.md §20).
class FanClub extends Equatable {
  const FanClub({
    this.enabled = true,
    this.name = '',
    this.memberCount = 0,
    this.isMember = false,
  });

  final bool enabled;
  final String name;
  final int memberCount;
  final bool isMember;

  FanClub copyWith({
    bool? enabled,
    String? name,
    int? memberCount,
    bool? isMember,
  }) {
    return FanClub(
      enabled: enabled ?? this.enabled,
      name: name ?? this.name,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
    );
  }

  @override
  List<Object?> get props => [enabled, name, memberCount, isMember];
}

/// A single member of a fan club.
class FanClubMember extends Equatable {
  const FanClubMember({
    required this.userId,
    this.fullName = '',
    this.username = '',
    this.avatarUrl,
    this.isVerified = false,
    this.joinedAt,
  });

  final String userId;
  final String fullName;
  final String username;
  final String? avatarUrl;
  final bool isVerified;
  final String? joinedAt;

  String get displayName => fullName.isNotEmpty ? fullName : username;

  @override
  List<Object?> get props =>
      [userId, fullName, username, avatarUrl, isVerified, joinedAt];
}

/// A fan club the signed-in user has joined.
class FanClubSubscription extends Equatable {
  const FanClubSubscription({
    this.creatorId = '',
    this.name = '',
    this.memberCount = 0,
    this.isMember = true,
  });

  final String creatorId;
  final String name;
  final int memberCount;
  final bool isMember;

  @override
  List<Object?> get props => [creatorId, name, memberCount, isMember];
}
