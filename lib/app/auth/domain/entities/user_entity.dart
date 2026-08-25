import 'package:equatable/equatable.dart';
import 'package:bimobondapp/app/auth/domain/entities/gifter_level_info.dart';
import 'package:bimobondapp/app/auth/domain/entities/profile_enums.dart';

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
  final String? verificationBadge;
  final List<ProfileLinkEntity>? profileLinks;
  final List<String>? roles;
  final String? fcmToken;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String? websiteUrl;
  final String? tiktokUrl;
  final String? twitterUrl;
  final String? snapchatUrl;
  final String? spotifyUrl;
  final String? pronouns;
  final String? creatorCategory;
  final String? accountType;
  final bool? isPrivate;
  final bool? allowComments;
  final bool? allowDirectMsgs;
  /// Who can start a DM: EVERYONE | FOLLOWERS | FRIENDS | NOBODY.
  final String? messagePermission;
  final bool? isProfileLocked;
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
  final int? deviceCount;
  final bool? isFollowing;
  final bool? isFollowedBy;
  final bool? isFriend;
  final bool? isOnline;
  final String? lastSeenAt;
  final String? riskLevel;
  final int? gifterLevel;
  final GifterLevelInfo? gifterLevelInfo;
  final String? likedVideosVisibility;
  final String? followersListVisibility;
  final String? followingListVisibility;
  final bool? profileViewHistoryEnabled;
  final bool? showActivityStatus;
  final bool? discoverable;
  final bool? suggestToContacts;
  final bool? restrictedMode;
  final bool? showShopOnProfile;
  final bool? allowDuetsDefault;
  final bool? allowStitchDefault;
  final bool? allowDownloadsDefault;
  final bool? allowRepostsDefault;
  final bool? showRepostsOnProfile;
  final bool? isBanned;
  final String? banReason;
  final String? bannedUntil;
  final String? createdAt;
  final String? updatedAt;
  final bool? isNewUser;
  final bool? isProfileIncomplete;
  final bool? needsInterests;
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
    this.verificationBadge,
    this.profileLinks,
    this.roles,
    this.fcmToken,
    this.instagramUrl,
    this.youtubeUrl,
    this.websiteUrl,
    this.tiktokUrl,
    this.twitterUrl,
    this.snapchatUrl,
    this.spotifyUrl,
    this.pronouns,
    this.creatorCategory,
    this.accountType,
    this.isPrivate,
    this.allowComments,
    this.allowDirectMsgs,
    this.messagePermission,
    this.isProfileLocked,
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
    this.deviceCount,
    this.isFollowing,
    this.isFollowedBy,
    this.isFriend,
    this.isOnline,
    this.lastSeenAt,
    this.riskLevel,
    this.gifterLevel,
    this.gifterLevelInfo,
    this.likedVideosVisibility,
    this.followersListVisibility,
    this.followingListVisibility,
    this.profileViewHistoryEnabled,
    this.showActivityStatus,
    this.discoverable,
    this.suggestToContacts,
    this.restrictedMode,
    this.showShopOnProfile,
    this.allowDuetsDefault,
    this.allowStitchDefault,
    this.allowDownloadsDefault,
    this.allowRepostsDefault,
    this.showRepostsOnProfile,
    this.isBanned,
    this.banReason,
    this.bannedUntil,
    this.createdAt,
    this.updatedAt,
    this.isNewUser,
    this.isProfileIncomplete,
    this.needsInterests,
    this.authToken,
    this.deviceToken,
  });

  /// Resolved DM policy for UI (syncs legacy [allowDirectMsgs]).
  String get resolvedMessagePermission {
    final raw = messagePermission?.trim().toUpperCase();
    if (raw != null && raw.isNotEmpty) return raw;
    if (allowDirectMsgs == false) return 'NOBODY';
    return 'EVERYONE';
  }

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
    websiteUrl,
    tiktokUrl,
    twitterUrl,
    snapchatUrl,
    spotifyUrl,
    pronouns,
    creatorCategory,
    accountType,
    isPrivate,
    allowComments,
    allowDirectMsgs,
    messagePermission,
    isProfileLocked,
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
    deviceCount,
    isFollowing,
    isFollowedBy,
    isFriend,
    isOnline,
    lastSeenAt,
    riskLevel,
    gifterLevel,
    gifterLevelInfo,
    likedVideosVisibility,
    followersListVisibility,
    followingListVisibility,
    profileViewHistoryEnabled,
    showActivityStatus,
    discoverable,
    suggestToContacts,
    restrictedMode,
    showShopOnProfile,
    allowDuetsDefault,
    allowStitchDefault,
    allowDownloadsDefault,
    allowRepostsDefault,
    showRepostsOnProfile,
    isBanned,
    banReason,
    bannedUntil,
    createdAt,
    updatedAt,
    isNewUser,
    isProfileIncomplete,
    needsInterests,
    authToken,
    deviceToken,
  ];
}

