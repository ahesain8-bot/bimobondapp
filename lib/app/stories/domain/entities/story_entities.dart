import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_location_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_view_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_views_page_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:equatable/equatable.dart';

class StoryUserEntity extends Equatable {
  const StoryUserEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.isVerified = false,
    this.isPrivate = false,
  });

  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool isVerified;
  final bool isPrivate;

  factory StoryUserEntity.fromJson(Map<String, dynamic> json) {
    return StoryUserEntity(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      isVerified: json['isVerified'] == true,
      isPrivate: json['isPrivate'] == true,
    );
  }

  PostUserEntity toPostUser() => PostUserEntity(
        id: id,
        username: username,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );

  SocialUserEntity toSocialUser() => SocialUserEntity(
        id: id,
        username: username,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );

  @override
  List<Object?> get props =>
      [id, username, fullName, avatarUrl, isVerified, isPrivate];
}

class StoryMediaEntity extends Equatable {
  const StoryMediaEntity({
    required this.url,
    required this.mediaType,
    this.id,
    this.order,
  });

  final String? id;
  final String url;
  final String mediaType;
  final int? order;

  factory StoryMediaEntity.fromJson(Map<String, dynamic> json) {
    return StoryMediaEntity(
      id: json['id']?.toString(),
      url: json['url']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? 'IMAGE',
      order: json['order'] is int
          ? json['order'] as int
          : int.tryParse(json['order']?.toString() ?? ''),
    );
  }

  PostMediaEntity toPostMedia() => PostMediaEntity(
        url: url,
        mediaType: mediaType,
        order: order,
      );

  @override
  List<Object?> get props => [id, url, mediaType, order];
}

class StoryEntity extends Equatable {
  const StoryEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.privacyStatus,
    required this.createdAt,
    this.videoUrl,
    this.hlsUrl,
    this.thumbnailUrl,
    this.animatedCoverUrl,
    this.description,
    this.ttlHours = 24,
    this.expiresAt,
    this.viewCount = 0,
    this.allowReplies = true,
    this.allowSharing = true,
    this.allowReactions = true,
    this.isExpired = false,
    this.hasViewed = false,
    this.filterName,
    this.beautyEnabled,
    this.media = const [],
    this.hashtags = const [],
    this.user,
    this.location,
  });

  final String id;
  final String userId;
  final String type;
  final String status;
  final String privacyStatus;
  final String? videoUrl;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final String? animatedCoverUrl;
  final String? description;
  final int ttlHours;
  final DateTime? expiresAt;
  final int viewCount;
  final bool allowReplies;
  final bool allowSharing;
  final bool allowReactions;
  final bool isExpired;
  final bool hasViewed;
  final String? filterName;
  final bool? beautyEnabled;
  final List<StoryMediaEntity> media;
  final List<String> hashtags;
  final StoryUserEntity? user;
  final PostLocationEntity? location;
  final DateTime createdAt;

  bool get isActive {
    if (isExpired) return false;
    if (status.toUpperCase() != 'PUBLISHED') return false;
    if (expiresAt != null && !expiresAt!.isAfter(DateTime.now().toUtc())) {
      return false;
    }
    return true;
  }

  factory StoryEntity.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final mediaRaw = data['media'];
    final hashtagsRaw = data['hashtags'];
    final userRaw = data['user'];
    final locationRaw = data['location'];

    DateTime? parseDate(dynamic v) => DateTime.tryParse(v?.toString() ?? '');

    final hashtags = <String>[];
    if (hashtagsRaw is List) {
      for (final item in hashtagsRaw) {
        if (item is Map) {
          final name = item['name']?.toString();
          if (name != null && name.isNotEmpty) hashtags.add(name);
        } else if (item != null) {
          hashtags.add(item.toString());
        }
      }
    }

    return StoryEntity(
      id: data['id']?.toString() ?? '',
      userId: data['userId']?.toString() ??
          (userRaw is Map ? userRaw['id']?.toString() : null) ??
          '',
      type: data['type']?.toString() ?? 'VIDEO',
      status: data['status']?.toString() ?? 'PUBLISHED',
      privacyStatus: data['privacyStatus']?.toString() ?? 'PUBLIC',
      videoUrl: data['videoUrl']?.toString(),
      hlsUrl: data['hlsUrl']?.toString(),
      thumbnailUrl: data['thumbnailUrl']?.toString(),
      animatedCoverUrl: data['animatedCoverUrl']?.toString(),
      description: data['description']?.toString(),
      ttlHours: data['ttlHours'] is int
          ? data['ttlHours'] as int
          : int.tryParse(data['ttlHours']?.toString() ?? '') ?? 24,
      expiresAt: parseDate(data['expiresAt']),
      viewCount: data['viewCount'] is int
          ? data['viewCount'] as int
          : int.tryParse(data['viewCount']?.toString() ?? '') ?? 0,
      allowReplies: data['allowReplies'] != false,
      allowSharing: data['allowSharing'] != false,
      allowReactions: data['allowReactions'] != false,
      isExpired: data['isExpired'] == true,
      hasViewed: data['hasViewed'] == true,
      filterName: data['filterName']?.toString(),
      beautyEnabled: data['beautyEnabled'] is bool
          ? data['beautyEnabled'] as bool
          : null,
      media: mediaRaw is List
          ? mediaRaw
              .whereType<Map>()
              .map((e) => StoryMediaEntity.fromJson(Map<String, dynamic>.from(e)))
              .where((m) => m.url.isNotEmpty)
              .toList()
          : const [],
      hashtags: hashtags,
      user: userRaw is Map
          ? StoryUserEntity.fromJson(Map<String, dynamic>.from(userRaw))
          : null,
      location: locationRaw is Map
          ? PostLocationEntity.fromJson(
              Map<String, dynamic>.from(locationRaw),
            )
          : null,
      createdAt: parseDate(data['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  /// Adapter so existing story UI (built on [PostEntity]) keeps working.
  PostEntity toPostEntity() {
    return PostEntity(
      id: id,
      userId: userId,
      type: type,
      videoUrl: videoUrl,
      hlsUrl: hlsUrl,
      thumbnailUrl: thumbnailUrl,
      description: description,
      privacyStatus: privacyStatus,
      viewCount: viewCount,
      likeCount: 0,
      commentCount: 0,
      saveCount: 0,
      shareCount: 0,
      repostCount: 0,
      isLiked: false,
      isSaved: false,
      isReposted: false,
      createdAt: createdAt,
      user: user?.toPostUser(),
      media: media.map((m) => m.toPostMedia()).toList(),
      hashtags: hashtags,
      mentions: const [],
      isStory: true,
      location: location,
      filterName: filterName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        status,
        privacyStatus,
        videoUrl,
        thumbnailUrl,
        description,
        ttlHours,
        expiresAt,
        viewCount,
        isExpired,
        hasViewed,
        media,
        hashtags,
        user,
        createdAt,
      ];
}

class StoryRingEntity extends Equatable {
  const StoryRingEntity({
    required this.user,
    required this.stories,
    required this.hasUnseen,
  });

  final StoryUserEntity user;
  final List<StoryEntity> stories;
  final bool hasUnseen;

  factory StoryRingEntity.fromJson(Map<String, dynamic> json) {
    final userRaw = json['user'];
    final storiesRaw = json['stories'];
    final user = userRaw is Map
        ? StoryUserEntity.fromJson(Map<String, dynamic>.from(userRaw))
        : const StoryUserEntity(id: '', username: '');
    final stories = storiesRaw is List
        ? storiesRaw
            .whereType<Map>()
            .map((e) {
              final map = Map<String, dynamic>.from(e);
              map.putIfAbsent('userId', () => user.id);
              map.putIfAbsent('user', () => {
                    'id': user.id,
                    'username': user.username,
                    'fullName': user.fullName,
                    'avatarUrl': user.avatarUrl,
                    'isVerified': user.isVerified,
                    'isPrivate': user.isPrivate,
                  });
              map.putIfAbsent('type', () => 'IMAGE');
              map.putIfAbsent('status', () => 'PUBLISHED');
              map.putIfAbsent('privacyStatus', () => 'PUBLIC');
              map.putIfAbsent(
                'createdAt',
                () => map['expiresAt'] ?? DateTime.now().toUtc().toIso8601String(),
              );
              return StoryEntity.fromJson(map);
            })
            .where((s) => s.id.isNotEmpty && s.isActive)
            .toList()
        : <StoryEntity>[];

    return StoryRingEntity(
      user: user,
      stories: stories,
      hasUnseen: json['hasUnseen'] == true,
    );
  }

  @override
  List<Object?> get props => [user, stories, hasUnseen];
}

class StoryViewRecordResult extends Equatable {
  const StoryViewRecordResult({
    required this.recorded,
    this.reason,
  });

  final bool recorded;
  final String? reason;

  factory StoryViewRecordResult.fromJson(Map<String, dynamic> json) {
    return StoryViewRecordResult(
      recorded: json['recorded'] == true,
      reason: json['reason']?.toString(),
    );
  }

  @override
  List<Object?> get props => [recorded, reason];
}

class StoryViewersPageEntity extends Equatable {
  const StoryViewersPageEntity({
    required this.views,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<PostViewEntity> views;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  PostViewsPageEntity toPostViewsPage() => PostViewsPageEntity(
        views: views,
        page: page,
        lastPage: lastPage,
        total: total,
      );

  factory StoryViewersPageEntity.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : <String, dynamic>{};
    final page = meta['page'] is int
        ? meta['page'] as int
        : int.tryParse(meta['page']?.toString() ?? '') ?? 1;
    final limit = meta['limit'] is int
        ? meta['limit'] as int
        : int.tryParse(meta['limit']?.toString() ?? '') ?? 20;
    final total = meta['total'] is int
        ? meta['total'] as int
        : int.tryParse(meta['total']?.toString() ?? '') ?? 0;
    final totalPages = meta['totalPages'] is int
        ? meta['totalPages'] as int
        : int.tryParse(meta['totalPages']?.toString() ?? '') ??
            (limit == 0 ? 1 : (total / limit).ceil().clamp(1, 999999));

    final views = <PostViewEntity>[];
    if (data is List) {
      for (final raw in data.whereType<Map>()) {
        final map = Map<String, dynamic>.from(raw);
        final userRaw = map['user'];
        SocialUserEntity? user;
        if (userRaw is Map) {
          final u = Map<String, dynamic>.from(userRaw);
          user = SocialUserEntity(
            id: u['id']?.toString() ?? '',
            username: u['username']?.toString() ?? '',
            fullName: u['fullName']?.toString(),
            avatarUrl: u['avatarUrl']?.toString(),
          );
        }
        views.add(
          PostViewEntity(
            id: map['id']?.toString() ?? '',
            userId: map['userId']?.toString() ?? user?.id ?? '',
            postId: map['storyId']?.toString() ?? '',
            watchedDuration: map['watchedDuration'] is int
                ? map['watchedDuration'] as int
                : int.tryParse(map['watchedDuration']?.toString() ?? ''),
            createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
            user: user,
          ),
        );
      }
    }

    return StoryViewersPageEntity(
      views: views,
      page: page,
      lastPage: totalPages,
      total: total,
    );
  }

  @override
  List<Object?> get props => [views, page, lastPage, total];
}

class CreateStoryInput extends Equatable {
  const CreateStoryInput({
    this.type,
    this.videoUrl,
    this.hlsUrl,
    this.thumbnailUrl,
    this.animatedCoverUrl,
    this.description,
    this.status,
    this.privacyStatus,
    this.allowReplies,
    this.allowSharing,
    this.allowReactions,
    this.ttlHours,
    this.duration,
    this.videoWidth,
    this.videoHeight,
    this.categoryId,
    this.locationId,
    this.location,
    this.soundSegmentId,
    this.soundId,
    this.startMs,
    this.endMs,
    this.newSound,
    this.media,
    this.filterName,
    this.filterCategory,
    this.effectSlug,
    this.beautyEnabled,
  });

  final String? type;
  final String? videoUrl;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final String? animatedCoverUrl;
  final String? description;
  final String? status;
  final String? privacyStatus;
  final bool? allowReplies;
  final bool? allowSharing;
  final bool? allowReactions;
  final int? ttlHours;
  final int? duration;
  final int? videoWidth;
  final int? videoHeight;
  final String? categoryId;
  final String? locationId;
  final PostInlineLocationInput? location;
  final String? soundSegmentId;
  final String? soundId;
  final int? startMs;
  final int? endMs;
  final Map<String, dynamic>? newSound;
  final List<PostMediaEntity>? media;
  final String? filterName;
  final String? filterCategory;
  final String? effectSlug;
  final bool? beautyEnabled;

  Map<String, dynamic> toJson() => {
        if (type != null) 'type': type,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (hlsUrl != null) 'hlsUrl': hlsUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (animatedCoverUrl != null) 'animatedCoverUrl': animatedCoverUrl,
        if (description != null) 'description': description,
        if (status != null) 'status': status,
        if (privacyStatus != null) 'privacyStatus': privacyStatus,
        if (allowReplies != null) 'allowReplies': allowReplies,
        if (allowSharing != null) 'allowSharing': allowSharing,
        if (allowReactions != null) 'allowReactions': allowReactions,
        if (ttlHours != null) 'ttlHours': ttlHours,
        if (duration != null) 'duration': duration,
        if (videoWidth != null) 'videoWidth': videoWidth,
        if (videoHeight != null) 'videoHeight': videoHeight,
        if (categoryId != null) 'categoryId': categoryId,
        if (locationId != null) 'locationId': locationId,
        if (location != null) 'location': location!.toJson(),
        if (soundSegmentId != null) 'soundSegmentId': soundSegmentId,
        if (soundId != null && soundSegmentId == null) 'soundId': soundId,
        if (soundId != null &&
            soundSegmentId == null &&
            startMs != null &&
            endMs != null) ...{
          'startMs': startMs,
          'endMs': endMs,
        },
        if (newSound != null && soundSegmentId == null && soundId == null)
          'newSound': newSound,
        if (media != null && media!.isNotEmpty)
          'media': media!
              .map(
                (m) => {
                  'url': m.url,
                  'mediaType': m.mediaType,
                  if (m.order != null) 'order': m.order,
                },
              )
              .toList(),
        if (filterName != null) 'filterName': filterName,
        if (filterCategory != null) 'filterCategory': filterCategory,
        if (effectSlug != null) 'effectSlug': effectSlug,
        if (beautyEnabled != null) 'beautyEnabled': beautyEnabled,
      };

  @override
  List<Object?> get props => [
        type,
        videoUrl,
        thumbnailUrl,
        description,
        privacyStatus,
        ttlHours,
        media,
        soundId,
        soundSegmentId,
      ];
}

class StoryListPageEntity extends Equatable {
  const StoryListPageEntity({
    required this.stories,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<StoryEntity> stories;
  final int page;
  final int lastPage;
  final int total;

  bool get hasReachedMax => page >= lastPage;

  factory StoryListPageEntity.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : <String, dynamic>{};
    final page = meta['page'] is int
        ? meta['page'] as int
        : int.tryParse(meta['page']?.toString() ?? '') ?? 1;
    final limit = meta['limit'] is int
        ? meta['limit'] as int
        : int.tryParse(meta['limit']?.toString() ?? '') ?? 20;
    final total = meta['total'] is int
        ? meta['total'] as int
        : int.tryParse(meta['total']?.toString() ?? '') ?? 0;
    final totalPages = meta['totalPages'] is int
        ? meta['totalPages'] as int
        : int.tryParse(meta['totalPages']?.toString() ?? '') ??
            (limit == 0 ? 1 : (total / limit).ceil().clamp(1, 999999));

    final stories = data is List
        ? data
            .whereType<Map>()
            .map((e) => StoryEntity.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.id.isNotEmpty)
            .toList()
        : <StoryEntity>[];

    return StoryListPageEntity(
      stories: stories,
      page: page,
      lastPage: totalPages,
      total: total,
    );
  }

  @override
  List<Object?> get props => [stories, page, lastPage, total];
}
