import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/domain/entities/gifter_level_info.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.firebaseUid,
    super.email,
    super.phoneNumber,
    super.username,
    super.fullName,
    super.bio,
    super.avatarUrl,
    super.dateOfBirth,
    super.isVerified,
    super.roles,
    super.fcmToken,
    super.instagramUrl,
    super.youtubeUrl,
    super.websiteUrl,
    super.tiktokUrl,
    super.twitterUrl,
    super.snapchatUrl,
    super.spotifyUrl,
    super.pronouns,
    super.creatorCategory,
    super.accountType,
    super.isPrivate,
    super.allowComments,
    super.allowDirectMsgs,
    super.messagePermission,
    super.isProfileLocked,
    super.language,
    super.theme,
    super.gender,
    super.country,
    super.region,
    super.city,
    super.followerCount,
    super.followingCount,
    super.postCount,
    super.totalLikes,
    super.deviceCount,
    super.isFollowing,
    super.isFollowedBy,
    super.isFriend,
    super.isOnline,
    super.lastSeenAt,
    super.riskLevel,
    super.gifterLevel,
    super.gifterLevelInfo,
    super.likedVideosVisibility,
    super.followersListVisibility,
    super.followingListVisibility,
    super.profileViewHistoryEnabled,
    super.showActivityStatus,
    super.discoverable,
    super.suggestToContacts,
    super.restrictedMode,
    super.showShopOnProfile,
    super.allowDuetsDefault,
    super.allowStitchDefault,
    super.allowDownloadsDefault,
    super.allowRepostsDefault,
    super.showRepostsOnProfile,
    super.isBanned,
    super.banReason,
    super.bannedUntil,
    super.createdAt,
    super.updatedAt,
    super.isNewUser,
    super.isProfileIncomplete,
    super.needsInterests,
    super.authToken,
    super.deviceToken,
  });

  static String? _normalizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url.trim());
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int _readCount(
    Map<String, dynamic> json,
    String countKey,
    List<String> fallbackKeys, {
    int fallback = 0,
  }) {
    final counts = json['_count'] ?? json['count'];
    if (counts is Map && counts[countKey] != null) {
      return _parseInt(counts[countKey], fallback: fallback);
    }

    for (final key in fallbackKeys) {
      if (json[key] != null) {
        return _parseInt(json[key], fallback: fallback);
      }
    }

    return fallback;
  }

  static int? _readOptionalCount(
    Map<String, dynamic> json,
    String countKey,
    List<String> fallbackKeys,
  ) {
    final counts = json['_count'] ?? json['count'];
    if (counts is Map && counts[countKey] != null) {
      return _parseInt(counts[countKey]);
    }

    for (final key in fallbackKeys) {
      if (json[key] != null) {
        return _parseInt(json[key]);
      }
    }

    return null;
  }

  static bool? _parseOptionalBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'true':
        case '1':
        case 'followed':
        case 'following':
          return true;
        case 'false':
        case '0':
        case 'unfollowed':
          return false;
      }
    }
    return null;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final avatarRaw = json['avatarUrl'] ??
        json['avatar'] ??
        json['profilePicture'] ??
        json['profileImage'] ??
        json['photoURL'] ??
        json['photoUrl'] ??
        json['image'] ??
        (json['user'] is Map
            ? json['user']['avatarUrl'] ??
                json['user']['avatar'] ??
                json['user']['profilePicture']
            : null);

    final avatarStr = avatarRaw?.toString().trim();
    final avatarUrl = (avatarStr != null && avatarStr.isNotEmpty)
        ? _normalizeUrl(avatarStr)
        : null;

    final gifterInfoRaw = json['gifterLevelInfo'];
    GifterLevelInfo? gifterLevelInfo;
    if (gifterInfoRaw is Map<String, dynamic>) {
      gifterLevelInfo = GifterLevelInfo.fromJson(gifterInfoRaw);
    } else if (gifterInfoRaw is Map) {
      gifterLevelInfo = GifterLevelInfo.fromJson(Map<String, dynamic>.from(gifterInfoRaw));
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      firebaseUid: json['firebaseUid']?.toString(),
      email: json['email']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      username: json['username']?.toString(),
      fullName: json['fullName']?.toString() ?? json['name']?.toString(),
      bio: json['bio']?.toString(),
      avatarUrl: avatarUrl,
      dateOfBirth: json['dateOfBirth'],
      isVerified: _parseOptionalBool(json['isVerified']) ?? false,
      roles: (json['roles'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      fcmToken: json['fcmToken'],
      instagramUrl: json['instagramUrl'],
      youtubeUrl: json['youtubeUrl'],
      websiteUrl: json['websiteUrl'],
      tiktokUrl: json['tiktokUrl'],
      twitterUrl: json['twitterUrl'],
      snapchatUrl: json['snapchatUrl'],
      spotifyUrl: json['spotifyUrl'],
      pronouns: json['pronouns'],
      creatorCategory: json['creatorCategory'],
      accountType: json['accountType'],
      isPrivate: _parseOptionalBool(json['isPrivate']) ?? false,
      allowComments: _parseOptionalBool(json['allowComments']) ?? true,
      allowDirectMsgs: _parseOptionalBool(json['allowDirectMsgs']) ?? true,
      messagePermission: json['messagePermission']?.toString(),
      isProfileLocked: _parseOptionalBool(json['isProfileLocked']) == true,
      language: json['language'],
      theme: json['theme'],
      gender: json['gender'],
      country: json['country'],
      region: json['region'],
      city: json['city'],
      followerCount: _readCount(json, 'followers', ['followerCount']),
      followingCount: _readCount(json, 'following', ['followingCount']),
      postCount: _readCount(json, 'posts', ['postCount']),
      totalLikes: _readCount(json, 'postLikes', ['totalLikes', 'postLikes']),
      deviceCount: _readOptionalCount(json, 'devices', ['deviceCount']),
      isFollowing:
          _parseOptionalBool(json['isFollowing']) ??
          _parseOptionalBool(json['isFollowed']) ??
          _parseOptionalBool(json['viewerIsFollowing']) ??
          _parseOptionalBool(json['following']),
      isFollowedBy:
          _parseOptionalBool(json['isFollowedBy']) ??
          _parseOptionalBool(json['followsYou']) ??
          _parseOptionalBool(json['isFollower']),
      isFriend: _parseOptionalBool(json['isFriend']),
      isOnline: _parseOptionalBool(json['isOnline']),
      lastSeenAt: json['lastSeenAt']?.toString(),
      riskLevel: json['riskLevel']?.toString(),
      gifterLevel: json['gifterLevel'] != null ? _parseInt(json['gifterLevel']) : null,
      gifterLevelInfo: gifterLevelInfo,
      likedVideosVisibility: json['likedVideosVisibility']?.toString(),
      followersListVisibility: json['followersListVisibility']?.toString(),
      followingListVisibility: json['followingListVisibility']?.toString(),
      profileViewHistoryEnabled: _parseOptionalBool(json['profileViewHistoryEnabled']),
      showActivityStatus: _parseOptionalBool(json['showActivityStatus']),
      discoverable: _parseOptionalBool(json['discoverable']),
      suggestToContacts: _parseOptionalBool(json['suggestToContacts']),
      restrictedMode: _parseOptionalBool(json['restrictedMode']),
      showShopOnProfile: _parseOptionalBool(json['showShopOnProfile']),
      allowDuetsDefault: _parseOptionalBool(json['allowDuetsDefault']),
      allowStitchDefault: _parseOptionalBool(json['allowStitchDefault']),
      allowDownloadsDefault: _parseOptionalBool(json['allowDownloadsDefault']),
      allowRepostsDefault: _parseOptionalBool(json['allowRepostsDefault']),
      showRepostsOnProfile: _parseOptionalBool(json['showRepostsOnProfile']),
      isBanned: _parseOptionalBool(json['isBanned']) ?? false,
      banReason: json['banReason'],
      bannedUntil: json['bannedUntil'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isNewUser: _parseOptionalBool(json['isNewUser']) ?? false,
      isProfileIncomplete: _parseOptionalBool(json['isProfileIncomplete']) ?? false,
      needsInterests: _parseOptionalBool(json['needsInterests']) ?? false,
      authToken: json['token'] ?? json['authToken'],
      deviceToken: json['deviceToken'],
    );
  }

  factory UserModel.fromFirebaseUser(User user, {String? authToken}) {
    return UserModel(
      id: user.uid,
      firebaseUid: user.uid,
      email: user.email,
      fullName: user.displayName,
      authToken: authToken,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebaseUid': firebaseUid,
      'email': email,
      'phoneNumber': phoneNumber,
      'username': username,
      'fullName': fullName,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'dateOfBirth': dateOfBirth,
      'isVerified': isVerified,
      'roles': roles,
      'fcmToken': fcmToken,
      'instagramUrl': instagramUrl,
      'youtubeUrl': youtubeUrl,
      'websiteUrl': websiteUrl,
      'tiktokUrl': tiktokUrl,
      'twitterUrl': twitterUrl,
      'snapchatUrl': snapchatUrl,
      'spotifyUrl': spotifyUrl,
      'pronouns': pronouns,
      'creatorCategory': creatorCategory,
      'accountType': accountType,
      'isPrivate': isPrivate,
      'allowComments': allowComments,
      'allowDirectMsgs': allowDirectMsgs,
      'messagePermission': messagePermission,
      'isProfileLocked': isProfileLocked,
      'language': language,
      'theme': theme,
      'gender': gender,
      'country': country,
      'region': region,
      'city': city,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'postCount': postCount,
      'totalLikes': totalLikes,
      'isFollowing': isFollowing,
      'isFollowedBy': isFollowedBy,
      'isFriend': isFriend,
      'isOnline': isOnline,
      'lastSeenAt': lastSeenAt,
      'riskLevel': riskLevel,
      'gifterLevel': gifterLevel,
      'gifterLevelInfo': gifterLevelInfo?.toJson(),
      'likedVideosVisibility': likedVideosVisibility,
      'followersListVisibility': followersListVisibility,
      'followingListVisibility': followingListVisibility,
      'profileViewHistoryEnabled': profileViewHistoryEnabled,
      'showActivityStatus': showActivityStatus,
      'discoverable': discoverable,
      'suggestToContacts': suggestToContacts,
      'restrictedMode': restrictedMode,
      'showShopOnProfile': showShopOnProfile,
      'allowDuetsDefault': allowDuetsDefault,
      'allowStitchDefault': allowStitchDefault,
      'allowDownloadsDefault': allowDownloadsDefault,
      'allowRepostsDefault': allowRepostsDefault,
      'showRepostsOnProfile': showRepostsOnProfile,
      'isBanned': isBanned,
      'banReason': banReason,
      'bannedUntil': bannedUntil,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isNewUser': isNewUser,
      'isProfileIncomplete': isProfileIncomplete,
      'needsInterests': needsInterests,
      'authToken': authToken,
      'deviceToken': deviceToken,
    };
  }
}

