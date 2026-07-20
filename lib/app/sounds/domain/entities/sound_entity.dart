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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'author': author,
        'audioUrl': audioUrl,
        if (coverUrl != null) 'coverUrl': coverUrl,
        'duration': duration,
        'useCount': useCount,
        'isOriginal': isOriginal,
        'isActive': isActive,
        if (originalSoundId != null) 'originalSoundId': originalSoundId,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (creator != null)
          'creator': {
            'id': creator!.id,
            'username': creator!.username,
            if (creator!.fullName != null) 'fullName': creator!.fullName,
            if (creator!.avatarUrl != null) 'avatarUrl': creator!.avatarUrl,
            'isVerified': creator!.isVerified,
          },
        if (postCount != null) '_count': {'posts': postCount},
      };

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
    this.type = 'VIDEO',
    this.thumbnailUrl,
    this.videoUrl,
    this.imageUrl,
    this.viewCount = 0,
    this.likeCount = 0,
    this.username,
    this.avatarUrl,
  });

  final String id;
  final String type;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? imageUrl;
  final int viewCount;
  final int likeCount;
  final String? username;
  final String? avatarUrl;

  bool get isVideo {
    if (type.toUpperCase() == 'IMAGE') return false;
    if (type.toUpperCase() == 'VIDEO') return true;
    final video = videoUrl;
    return video != null && video.isNotEmpty;
  }

  String? get resolvedThumbnailUrl {
    final url = thumbnailUrl;
    if (url == null || url.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  String? get resolvedVideoUrl {
    final url = videoUrl;
    if (url == null || url.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  String? get resolvedImageUrl {
    final url = imageUrl;
    if (url == null || url.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  /// Cover/poster for grid tiles. Prefer any non-file-video URL (CDN thumbs
  /// often contain "video" in the path and must still display as images).
  String? get resolvedCoverUrl {
    for (final candidate in [resolvedThumbnailUrl, resolvedImageUrl]) {
      if (candidate == null || candidate.isEmpty) continue;
      if (_isVideoFileUrl(candidate)) continue;
      return candidate;
    }
    return null;
  }

  factory SoundPostPreviewEntity.fromJson(Map<String, dynamic> json) {
    String? username;
    String? avatarUrl;
    final user = json['user'];
    if (user is Map) {
      username = user['username']?.toString();
      avatarUrl = user['avatarUrl']?.toString();
    }

    final type = json['type']?.toString().trim().isNotEmpty == true
        ? json['type'].toString()
        : (_resolvePostPreviewVideo(json) != null ? 'VIDEO' : 'IMAGE');

    return SoundPostPreviewEntity(
      id: json['id']?.toString() ?? '',
      type: type,
      thumbnailUrl: _resolvePostPreviewThumbnail(json),
      videoUrl: _resolvePostPreviewVideo(json),
      imageUrl: _resolvePostPreviewImage(json),
      viewCount: _parseSoundInt(json['viewCount']),
      likeCount: _parseSoundInt(json['likeCount']),
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    thumbnailUrl,
    videoUrl,
    imageUrl,
    viewCount,
    likeCount,
    username,
    avatarUrl,
  ];
}

String? _firstNonEmptyString(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

/// True only for clear video *files* / streams — not CDN paths that contain
/// the word "video" (those are often image thumbnails).
bool _isVideoFileUrl(String url) {
  if (url.isEmpty) return false;
  final lower = url.toLowerCase();
  final clean = lower.split('?').first;
  if (MediaUtils.imageExtensions.any((ext) => clean.endsWith(ext))) {
    return false;
  }
  if (MediaUtils.videoExtensions.any((ext) => clean.endsWith(ext))) {
    return true;
  }
  return lower.contains('.m3u8');
}

String? _resolvePostPreviewThumbnail(Map<String, dynamic> json) {
  final direct = _firstNonEmptyString([
    json['thumbnailUrl']?.toString(),
    json['coverUrl']?.toString(),
    json['posterUrl']?.toString(),
    json['imageUrl']?.toString(),
  ]);
  if (direct != null && !_isVideoFileUrl(direct)) return direct;

  final media = json['media'];
  if (media is List) {
    for (final item in media) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final mediaType = map['mediaType']?.toString();
      final candidate = _firstNonEmptyString([
        map['thumbnailUrl']?.toString(),
        map['coverUrl']?.toString(),
        map['posterUrl']?.toString(),
      ]);
      if (candidate != null && !_isVideoFileUrl(candidate)) {
        return candidate;
      }
      final url = map['url']?.toString();
      if (url == null || url.isEmpty) continue;
      if (mediaType?.toUpperCase() == 'IMAGE' ||
          (!_isVideoFileUrl(url) &&
              MediaUtils.isImage(url, mediaType: mediaType))) {
        return url;
      }
    }
  }
  return null;
}

String? _resolvePostPreviewVideo(Map<String, dynamic> json) {
  if (json['type']?.toString().toUpperCase() == 'IMAGE') return null;

  final candidates = <String>[
    if (json['hlsUrl']?.toString().trim().isNotEmpty == true)
      json['hlsUrl'].toString(),
    if (json['videoUrl']?.toString().trim().isNotEmpty == true)
      json['videoUrl'].toString(),
  ];

  final media = json['media'];
  if (media is List) {
    for (final item in media) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final url = map['url']?.toString();
      if (url == null || url.isEmpty) continue;
      final mediaType = map['mediaType']?.toString();
      if (mediaType?.toUpperCase() == 'IMAGE') continue;
      if (mediaType?.toUpperCase() == 'VIDEO' || _isVideoFileUrl(url)) {
        candidates.add(url);
      }
    }
  }

  for (final url in candidates) {
    if (url.isEmpty) continue;
    if (_isVideoFileUrl(url) || url.toLowerCase().contains('.m3u8')) {
      return url;
    }
  }

  // Explicit videoUrl / hlsUrl fields are trusted even without extension.
  if (candidates.isNotEmpty) return candidates.first;
  return null;
}

String? _resolvePostPreviewImage(Map<String, dynamic> json) {
  final direct = _firstNonEmptyString([
    json['imageUrl']?.toString(),
    json['coverUrl']?.toString(),
  ]);
  if (direct != null && !_isVideoFileUrl(direct)) return direct;

  final media = json['media'];
  if (media is List) {
    for (final item in media) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final url = map['url']?.toString();
      if (url == null || url.isEmpty) continue;
      final mediaType = map['mediaType']?.toString();
      if (mediaType?.toUpperCase() == 'VIDEO' || _isVideoFileUrl(url)) {
        continue;
      }
      if (mediaType?.toUpperCase() == 'IMAGE' ||
          MediaUtils.isImage(url, mediaType: mediaType)) {
        return url;
      }
    }
  }

  final thumb = json['thumbnailUrl']?.toString();
  if (thumb != null && thumb.isNotEmpty && !_isVideoFileUrl(thumb)) {
    return thumb;
  }
  return null;
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
