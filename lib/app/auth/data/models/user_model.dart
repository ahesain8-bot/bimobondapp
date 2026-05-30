import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
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
    super.isPrivate,
    super.allowComments,
    super.allowDirectMsgs,
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
    super.isBanned,
    super.banReason,
    super.bannedUntil,
    super.createdAt,
    super.updatedAt,
    super.isNewUser,
    super.isProfileIncomplete,
    super.authToken,
    super.deviceToken,
  });

  static String? _normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    if (url.startsWith('/')) {
      return url;
    }
    return url;
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
    return UserModel(
      id: json['id'] ?? '',
      firebaseUid: json['firebaseUid'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      username: json['username'],
      fullName: json['fullName'],
      bio: json['bio'],
      avatarUrl: _normalizeUrl(json['avatarUrl']),
      dateOfBirth: json['dateOfBirth'],
      isVerified: json['isVerified'] ?? false,
      roles: (json['roles'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      fcmToken: json['fcmToken'],
      instagramUrl: json['instagramUrl'],
      youtubeUrl: json['youtubeUrl'],
      isPrivate: json['isPrivate'] ?? false,
      allowComments: json['allowComments'] ?? true,
      allowDirectMsgs: json['allowDirectMsgs'] ?? true,
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
      isFollowing: _parseOptionalBool(json['isFollowing']) ??
          _parseOptionalBool(json['isFollowed']) ??
          _parseOptionalBool(json['viewerIsFollowing']) ??
          _parseOptionalBool(json['following']),
      isBanned: json['isBanned'] ?? false,
      banReason: json['banReason'],
      bannedUntil: json['bannedUntil'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isNewUser: json['isNewUser'] ?? false,
      isProfileIncomplete: json['isProfileIncomplete'] ?? false,
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
      'isPrivate': isPrivate,
      'allowComments': allowComments,
      'allowDirectMsgs': allowDirectMsgs,
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
      'isBanned': isBanned,
      'banReason': banReason,
      'bannedUntil': bannedUntil,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isNewUser': isNewUser,
      'isProfileIncomplete': isProfileIncomplete,
      'authToken': authToken,
      'deviceToken': deviceToken,
    };
  }
}
