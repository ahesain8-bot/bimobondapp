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

class SoundSegmentEntity extends Equatable {
  const SoundSegmentEntity({
    required this.id,
    required this.startMs,
    required this.endMs,
    this.label,
    this.useCount = 0,
    this.isDefault = false,
  });

  final String id;
  final int startMs;
  final int endMs;
  final String? label;
  final int useCount;
  final bool isDefault;

  int get durationMs {
    final d = endMs - startMs;
    return d < 0 ? 0 : d;
  }

  factory SoundSegmentEntity.fromJson(Map<String, dynamic> json) {
    return SoundSegmentEntity(
      id: json['id']?.toString() ?? '',
      startMs: _parseSoundInt(json['startMs']),
      endMs: _parseSoundInt(json['endMs']),
      label: json['label']?.toString(),
      useCount: _parseSoundInt(json['useCount']),
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startMs': startMs,
        'endMs': endMs,
        if (label != null) 'label': label,
        'useCount': useCount,
        'isDefault': isDefault,
      };

  @override
  List<Object?> get props => [id, startMs, endMs, label, useCount, isDefault];
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
    this.creatorId,
    this.createdAt,
    this.updatedAt,
    this.creator,
    this.postCount,
    this.segmentCount,
    this.waveformPeaks,
    this.defaultSegment,
    this.sortOrder,
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
  final String? creatorId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SoundCreatorEntity? creator;
  final int? postCount;
  final int? segmentCount;
  final List<double>? waveformPeaks;
  final SoundSegmentEntity? defaultSegment;
  final int? sortOrder;

  String get resolvedAudioUrl => MediaUtils.resolveAbsoluteUrl(audioUrl);

  String? get resolvedCoverUrl {
    final url = coverUrl;
    if (url == null || url.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  /// Clip range for attach: `[startMs, endMs)` clamped to track length (min 1s).
  static ({int startMs, int endMs}) clipRangeMs({
    required int durationSeconds,
    required Duration offset,
    required Duration window,
  }) {
    final maxMs = durationSeconds > 0 ? durationSeconds * 1000 : 15000;
    final minLen = 1000;
    var start = offset.inMilliseconds;
    if (start < 0) start = 0;
    if (start > maxMs - minLen) start = (maxMs - minLen).clamp(0, maxMs);
    var end = (offset + window).inMilliseconds;
    if (end > maxMs) end = maxMs;
    if (end - start < minLen) {
      end = (start + minLen).clamp(0, maxMs);
      if (end - start < minLen) start = (end - minLen).clamp(0, maxMs);
    }
    return (startMs: start, endMs: end);
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
        if (creatorId != null) 'creatorId': creatorId,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (waveformPeaks != null) 'waveformPeaks': waveformPeaks,
        if (defaultSegment != null) 'defaultSegment': defaultSegment!.toJson(),
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (creator != null)
          'creator': {
            'id': creator!.id,
            'username': creator!.username,
            if (creator!.fullName != null) 'fullName': creator!.fullName,
            if (creator!.avatarUrl != null) 'avatarUrl': creator!.avatarUrl,
            'isVerified': creator!.isVerified,
          },
        if (postCount != null || segmentCount != null)
          '_count': {
            if (postCount != null) 'posts': postCount,
            if (segmentCount != null) 'segments': segmentCount,
          },
      };

  factory SoundEntity.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];
    int? postsCount;
    int? segmentsCount;
    if (count is Map) {
      postsCount = count['posts'] != null ? _parseSoundInt(count['posts']) : null;
      segmentsCount =
          count['segments'] != null ? _parseSoundInt(count['segments']) : null;
    }

    DateTime? createdAt;
    final rawCreated = json['createdAt'];
    if (rawCreated is String && rawCreated.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreated);
    }
    DateTime? updatedAt;
    final rawUpdated = json['updatedAt'];
    if (rawUpdated is String && rawUpdated.isNotEmpty) {
      updatedAt = DateTime.tryParse(rawUpdated);
    }

    SoundCreatorEntity? creator;
    final rawCreator = json['creator'];
    if (rawCreator is Map) {
      creator = SoundCreatorEntity.fromJson(
        Map<String, dynamic>.from(rawCreator),
      );
    }

    SoundSegmentEntity? defaultSegment;
    final rawDefault = json['defaultSegment'];
    if (rawDefault is Map) {
      defaultSegment = SoundSegmentEntity.fromJson(
        Map<String, dynamic>.from(rawDefault),
      );
    }

    List<double>? peaks;
    final rawPeaks = json['waveformPeaks'];
    if (rawPeaks is List) {
      peaks = rawPeaks
          .map((e) => e is num ? e.toDouble() : double.tryParse('$e') ?? 0)
          .toList();
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
      creatorId: json['creatorId']?.toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      creator: creator,
      postCount: postsCount,
      segmentCount: segmentsCount,
      waveformPeaks: peaks,
      defaultSegment: defaultSegment,
      sortOrder: json['sortOrder'] != null ? _parseSoundInt(json['sortOrder']) : null,
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
    creatorId,
    createdAt,
    updatedAt,
    creator,
    postCount,
    segmentCount,
    waveformPeaks,
    defaultSegment,
    sortOrder,
  ];
}

class SoundGroupEntity extends Equatable {
  const SoundGroupEntity({
    required this.id,
    required this.name,
    this.slug,
    this.iconUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.soundCount = 0,
    this.sounds = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? slug;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;
  final int soundCount;
  final List<SoundEntity> sounds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get resolvedIconUrl {
    final url = iconUrl;
    if (url == null || url.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  factory SoundGroupEntity.fromJson(Map<String, dynamic> json) {
    final sounds = <SoundEntity>[];
    final rawSounds = json['sounds'];
    if (rawSounds is List) {
      for (final item in rawSounds) {
        if (item is Map) {
          sounds.add(SoundEntity.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    DateTime? createdAt;
    final rawCreated = json['createdAt'];
    if (rawCreated is String && rawCreated.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreated);
    }
    DateTime? updatedAt;
    final rawUpdated = json['updatedAt'];
    if (rawUpdated is String && rawUpdated.isNotEmpty) {
      updatedAt = DateTime.tryParse(rawUpdated);
    }

    return SoundGroupEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      iconUrl: json['iconUrl']?.toString(),
      sortOrder: _parseSoundInt(json['sortOrder']),
      isActive: json['isActive'] != false,
      soundCount: _parseSoundInt(json['soundCount']),
      sounds: sounds,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        iconUrl,
        sortOrder,
        isActive,
        soundCount,
        sounds,
        createdAt,
        updatedAt,
      ];
}

class SoundsSegmentsPageEntity extends Equatable {
  const SoundsSegmentsPageEntity({
    required this.segments,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<SoundSegmentEntity> segments;
  final int page;
  final int totalPages;
  final int total;

  factory SoundsSegmentsPageEntity.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final list = rawData is List ? rawData : json['segments'];
    final segments = <SoundSegmentEntity>[];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          segments.add(
            SoundSegmentEntity.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final meta = json['meta'];
    if (meta is Map) {
      final map = Map<String, dynamic>.from(meta);
      return SoundsSegmentsPageEntity(
        segments: segments,
        page: _parseSoundInt(map['page'], fallback: 1),
        totalPages: _parseSoundInt(map['totalPages'], fallback: 1),
        total: _parseSoundInt(map['total']),
      );
    }

    return SoundsSegmentsPageEntity(
      segments: segments,
      page: _parseSoundInt(json['page'], fallback: 1),
      totalPages: _parseSoundInt(json['totalPages'], fallback: 1),
      total: _parseSoundInt(json['total']),
    );
  }

  @override
  List<Object?> get props => [segments, page, totalPages, total];
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
    this.soundSegmentId,
    this.soundSegment,
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
  final String? soundSegmentId;
  final SoundSegmentEntity? soundSegment;

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

    SoundSegmentEntity? segment;
    final rawSegment = json['soundSegment'];
    if (rawSegment is Map) {
      segment = SoundSegmentEntity.fromJson(
        Map<String, dynamic>.from(rawSegment),
      );
    }

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
      soundSegmentId: json['soundSegmentId']?.toString(),
      soundSegment: segment,
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
    soundSegmentId,
    soundSegment,
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
    this.segments = const [],
  });

  final SoundEntity sound;
  final List<SoundPostPreviewEntity> posts;
  final SoundEntity? originalSound;
  final List<SoundSegmentEntity> segments;

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

    final segments = <SoundSegmentEntity>[];
    final rawSegments = json['segments'];
    if (rawSegments is List) {
      for (final item in rawSegments) {
        if (item is Map) {
          segments.add(
            SoundSegmentEntity.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return SoundDetailEntity(
      sound: SoundEntity.fromJson(json),
      posts: posts,
      originalSound: originalSound,
      segments: segments,
    );
  }

  @override
  List<Object?> get props => [sound, posts, originalSound, segments];
}

/// Detail for `GET /sounds/segments/:segmentId`.
class SoundSegmentDetailEntity extends Equatable {
  const SoundSegmentDetailEntity({
    required this.segment,
    this.sound,
    this.posts = const [],
  });

  final SoundSegmentEntity segment;
  final SoundEntity? sound;
  final List<SoundPostPreviewEntity> posts;

  factory SoundSegmentDetailEntity.fromJson(Map<String, dynamic> json) {
    final segmentJson = json['segment'] is Map
        ? Map<String, dynamic>.from(json['segment'] as Map)
        : json;

    SoundEntity? sound;
    final rawSound = json['sound'];
    if (rawSound is Map) {
      sound = SoundEntity.fromJson(Map<String, dynamic>.from(rawSound));
    }

    final posts = <SoundPostPreviewEntity>[];
    final rawPosts = json['posts'];
    if (rawPosts is List) {
      for (final item in rawPosts) {
        if (item is Map) {
          posts.add(
            SoundPostPreviewEntity.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return SoundSegmentDetailEntity(
      segment: SoundSegmentEntity.fromJson(segmentJson),
      sound: sound,
      posts: posts,
    );
  }

  @override
  List<Object?> get props => [segment, sound, posts];
}
