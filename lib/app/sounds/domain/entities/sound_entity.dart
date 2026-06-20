import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:equatable/equatable.dart';

int _parseSoundInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

enum SoundSort { trending, recent, name }

extension SoundSortQuery on SoundSort {
  String get apiValue => name;
}

class SoundCreatorEntity extends Equatable {
  const SoundCreatorEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.isVerified = false,
  });

  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool isVerified;

  factory SoundCreatorEntity.fromJson(Map<String, dynamic> json) {
    return SoundCreatorEntity(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      isVerified: json['isVerified'] == true,
    );
  }

  @override
  List<Object?> get props => [id, username, fullName, avatarUrl, isVerified];
}

class SoundEntity extends Equatable {
  const SoundEntity({
    required this.id,
    required this.name,
    required this.author,
    required this.audioUrl,
    this.coverUrl,
    this.duration = 0,
    this.useCount = 0,
    this.isOriginal = false,
    this.isActive = true,
    this.originalSoundId,
    this.createdAt,
    this.creator,
    this.postCount,
  });

  final String id;
  final String name;
  final String author;
  final String audioUrl;
  final String? coverUrl;
  final int duration;
  final int useCount;
  final bool isOriginal;
  final bool isActive;
  final String? originalSoundId;
  final DateTime? createdAt;
  final SoundCreatorEntity? creator;
  final int? postCount;

  String get resolvedAudioUrl => MediaUtils.resolveAbsoluteUrl(audioUrl);

  String? get resolvedCoverUrl {
    final url = coverUrl;
    if (url == null || url.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  factory SoundEntity.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];
    int? postsCount;
    if (count is Map) {
      postsCount = _parseSoundInt(count['posts']);
    }

    DateTime? createdAt;
    final rawCreated = json['createdAt'];
    if (rawCreated is String && rawCreated.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreated);
    }

    SoundCreatorEntity? creator;
    final rawCreator = json['creator'];
    if (rawCreator is Map) {
      creator = SoundCreatorEntity.fromJson(
        Map<String, dynamic>.from(rawCreator),
      );
    }

    return SoundEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      audioUrl: json['audioUrl']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString(),
      duration: _parseSoundInt(json['duration']),
      useCount: _parseSoundInt(json['useCount']),
      isOriginal: json['isOriginal'] == true,
      isActive: json['isActive'] != false,
      originalSoundId: json['originalSoundId']?.toString(),
      createdAt: createdAt,
      creator: creator,
      postCount: postsCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    author,
    audioUrl,
    coverUrl,
    duration,
    useCount,
    isOriginal,
    isActive,
    originalSoundId,
    createdAt,
    creator,
    postCount,
  ];
}

class SoundsPageEntity extends Equatable {
  const SoundsPageEntity({
    required this.sounds,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<SoundEntity> sounds;
  final int page;
  final int totalPages;
  final int total;

  bool get hasReachedMax => page >= totalPages;

  factory SoundsPageEntity.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final list = rawData is List ? rawData : json['sounds'];
    final sounds = <SoundEntity>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          sounds.add(
            SoundEntity.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final meta = json['meta'];
    if (meta is Map) {
      final map = Map<String, dynamic>.from(meta);
      return SoundsPageEntity(
        sounds: sounds,
        page: _parseSoundInt(map['page'], fallback: 1),
        totalPages: _parseSoundInt(map['totalPages'], fallback: 1),
        total: _parseSoundInt(map['total']),
      );
    }

    return SoundsPageEntity(
      sounds: sounds,
      page: _parseSoundInt(json['page'], fallback: 1),
      totalPages: _parseSoundInt(json['totalPages'], fallback: 1),
      total: _parseSoundInt(json['total']),
    );
  }

  @override
  List<Object?> get props => [sounds, page, totalPages, total];
}

class SoundPostPreviewEntity extends Equatable {
  const SoundPostPreviewEntity({
    required this.id,
    this.thumbnailUrl,
    this.viewCount = 0,
    this.likeCount = 0,
    this.username,
    this.avatarUrl,
  });

  final String id;
  final String? thumbnailUrl;
  final int viewCount;
  final int likeCount;
  final String? username;
  final String? avatarUrl;

  String? get resolvedThumbnailUrl {
    final url = thumbnailUrl;
    if (url == null || url.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  factory SoundPostPreviewEntity.fromJson(Map<String, dynamic> json) {
    String? username;
    String? avatarUrl;
    final user = json['user'];
    if (user is Map) {
      username = user['username']?.toString();
      avatarUrl = user['avatarUrl']?.toString();
    }

    return SoundPostPreviewEntity(
      id: json['id']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      viewCount: _parseSoundInt(json['viewCount']),
      likeCount: _parseSoundInt(json['likeCount']),
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  @override
  List<Object?> get props => [
    id,
    thumbnailUrl,
    viewCount,
    likeCount,
    username,
    avatarUrl,
  ];
}

class SoundDetailEntity extends Equatable {
  const SoundDetailEntity({
    required this.sound,
    required this.posts,
    this.originalSound,
  });

  final SoundEntity sound;
  final List<SoundPostPreviewEntity> posts;
  final SoundEntity? originalSound;

  factory SoundDetailEntity.fromJson(Map<String, dynamic> json) {
    SoundEntity? originalSound;
    final rawOriginal = json['originalSound'];
    if (rawOriginal is Map) {
      originalSound = SoundEntity.fromJson(
        Map<String, dynamic>.from(rawOriginal),
      );
    }

    final posts = <SoundPostPreviewEntity>[];
    final rawPosts = json['posts'];
    if (rawPosts is List) {
      for (final item in rawPosts) {
        if (item is Map) {
          posts.add(
            SoundPostPreviewEntity.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return SoundDetailEntity(
      sound: SoundEntity.fromJson(json),
      posts: posts,
      originalSound: originalSound,
    );
  }

  @override
  List<Object?> get props => [sound, posts, originalSound];
}
