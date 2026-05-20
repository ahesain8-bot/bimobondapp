import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? firebaseUid;
  final String? email;
  final String? phoneNumber;
  final String? username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final String? dateOfBirth;
  final bool? isVerified;
  final List<String>? roles;
  final String? fcmToken;
  final String? instagramUrl;
  final String? youtubeUrl;
  final bool? isPrivate;
  final bool? allowComments;
  final bool? allowDirectMsgs;
  final String? language;
  final String? theme;
  final String? gender;
  final String? country;
  final String? region;
  final String? city;
  final int? followerCount;
  final int? followingCount;
  final int? postCount;
  final int? totalLikes;
  final bool? isBanned;
  final String? banReason;
  final String? bannedUntil;
  final String? createdAt;
  final String? updatedAt;
  final bool? isNewUser;
  final bool? isProfileIncomplete;
  final String? authToken;
  final String? deviceToken;

  const UserEntity({
    required this.id,
    this.firebaseUid,
    this.email,
    this.phoneNumber,
    this.username,
    this.fullName,
    this.bio,
    this.avatarUrl,
    this.dateOfBirth,
    this.isVerified,
    this.roles,
    this.fcmToken,
    this.instagramUrl,
    this.youtubeUrl,
    this.isPrivate,
    this.allowComments,
    this.allowDirectMsgs,
    this.language,
    this.theme,
    this.gender,
    this.country,
    this.region,
    this.city,
    this.followerCount,
    this.followingCount,
    this.postCount,
    this.totalLikes,
    this.isBanned,
    this.banReason,
    this.bannedUntil,
    this.createdAt,
    this.updatedAt,
    this.isNewUser,
    this.isProfileIncomplete,
    this.authToken,
    this.deviceToken,
  });

  @override
  List<Object?> get props => [
    id,
    firebaseUid,
    email,
    phoneNumber,
    username,
    fullName,
    bio,
    avatarUrl,
    dateOfBirth,
    isVerified,
    roles,
    fcmToken,
    instagramUrl,
    youtubeUrl,
    isPrivate,
    allowComments,
    allowDirectMsgs,
    language,
    theme,
    gender,
    country,
    region,
    city,
    followerCount,
    followingCount,
    postCount,
    totalLikes,
    isBanned,
    banReason,
    bannedUntil,
    createdAt,
    updatedAt,
    isNewUser,
    isProfileIncomplete,
    authToken,
    deviceToken,
  ];
}
