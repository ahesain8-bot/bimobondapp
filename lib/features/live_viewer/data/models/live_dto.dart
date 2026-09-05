import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_feed_promotion.dart';

/// Data-transfer object for live feed items.
/// Swap JSON parsing here when wiring real REST responses.
class LiveDto {
  final String id;
  final String hostId;
  final String hostName;
  final String? hostAvatar;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String? streamUrl;
  final String category;
  final int viewerCount;
  final int likeCount;
  final DateTime startTime;
  final String status;
  final bool isPromoted;
  final LiveFeedPromotion? promotion;

  const LiveDto({
    required this.id,
    required this.hostId,
    required this.hostName,
    this.hostAvatar,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.streamUrl,
    required this.category,
    this.viewerCount = 0,
    this.likeCount = 0,
    required this.startTime,
    this.status = 'live',
    this.isPromoted = false,
    this.promotion,
  });

  factory LiveDto.fromJson(Map<String, dynamic> json) {
    return LiveDto(
      id: json['id'] as String,
      hostId: json['host_id'] as String? ?? json['hostId'] as String,
      hostName: json['host_name'] as String? ?? json['hostName'] as String,
      hostAvatar:
          json['host_avatar'] as String? ?? json['hostAvatar'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      thumbnailUrl:
          json['thumbnail_url'] as String? ?? json['thumbnailUrl'] as String?,
      streamUrl: json['stream_url'] as String? ?? json['streamUrl'] as String?,
      category: json['category'] as String? ?? 'Other',
      viewerCount:
          (json['viewer_count'] as num?)?.toInt() ??
          (json['viewerCount'] as num?)?.toInt() ??
          0,
      likeCount:
          (json['like_count'] as num?)?.toInt() ??
          (json['likeCount'] as num?)?.toInt() ??
          0,
      startTime:
          DateTime.tryParse(
            json['start_time'] as String? ?? json['startTime'] as String? ?? '',
          ) ??
          DateTime.now(),
      status: json['status'] as String? ?? 'live',
      isPromoted: json['isPromoted'] == true,
      promotion: LiveFeedPromotion.fromJson(json['promotion']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'host_id': hostId,
    'host_name': hostName,
    'host_avatar': hostAvatar,
    'title': title,
    'description': description,
    'thumbnail_url': thumbnailUrl,
    'stream_url': streamUrl,
    'category': category,
    'viewer_count': viewerCount,
    'like_count': likeCount,
    'start_time': startTime.toIso8601String(),
    'status': status,
    'isPromoted': isPromoted,
    if (promotion != null) 'promotion': promotion!.toJson(),
  };

  LiveEntity toEntity() {
    return LiveEntity(
      id: id,
      hostId: hostId,
      hostName: hostName,
      hostAvatar: hostAvatar,
      title: title,
      description: description,
      thumbnailUrl: thumbnailUrl,
      streamUrl: streamUrl,
      category: category,
      viewerCount: viewerCount,
      likeCount: likeCount,
      startTime: startTime,
      status: _mapStatus(status),
      isLive: status.toLowerCase() == 'live',
      isPromoted: isPromoted,
      promotion: promotion,
    );
  }

  static LiveStatus _mapStatus(String value) {
    switch (value.toLowerCase()) {
      case 'planned':
      case 'scheduled':
        return LiveStatus.scheduled;
      case 'paused':
        return LiveStatus.paused;
      case 'ended':
        return LiveStatus.ended;
      case 'banned':
        return LiveStatus.banned;
      default:
        return LiveStatus.live;
    }
  }
}
