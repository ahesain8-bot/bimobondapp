import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'live_feed_promotion.dart';

class LiveEntity extends Equatable {
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
  final DateTime? endTime;
  final LiveStatus status;
  final bool isLive;
  final bool isFollowing;
  final Map<String, dynamic>? metadata;
  final bool isPromoted;
  final LiveFeedPromotion? promotion;

  /// Feed occurrences have distinct identities even when they share a room.
  String get feedEntryKey =>
      '$id|${isPromoted ? 'promoted' : 'organic'}|${isPromoted ? promotion?.id ?? '' : ''}';

  const LiveEntity({
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
    this.endTime,
    this.status = LiveStatus.live,
    this.isLive = true,
    this.metadata,
    this.isFollowing = false,
    this.isPromoted = false,
    this.promotion,
  });

  LiveEntity copyWith({
    String? id,
    String? hostId,
    String? hostName,
    String? hostAvatar,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? streamUrl,
    String? category,
    int? viewerCount,
    int? likeCount,
    DateTime? startTime,
    DateTime? endTime,
    LiveStatus? status,
    bool? isLive,
    bool? isFollowing,
    Map<String, dynamic>? metadata,
    bool? isPromoted,
    LiveFeedPromotion? promotion,
    bool clearPromotion = false,
  }) {
    return LiveEntity(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatar: hostAvatar ?? this.hostAvatar,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      category: category ?? this.category,
      viewerCount: viewerCount ?? this.viewerCount,
      likeCount: likeCount ?? this.likeCount,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      isLive: isLive ?? this.isLive,
      isFollowing: isFollowing ?? this.isFollowing,
      metadata: metadata ?? this.metadata,
      isPromoted: isPromoted ?? this.isPromoted,
      promotion: clearPromotion ? null : (promotion ?? this.promotion),
    );
  }

  @override
  List<Object?> get props => [
    id,
    hostId,
    hostName,
    hostAvatar,
    title,
    description,
    thumbnailUrl,
    streamUrl,
    category,
    viewerCount,
    likeCount,
    startTime,
    endTime,
    status,
    isLive,
    isFollowing,
    metadata,
    isPromoted,
    promotion,
  ];
}

enum LiveStatus { scheduled, live, paused, ended, banned }

extension LiveStatusExtension on LiveStatus {
  String get displayName {
    switch (this) {
      case LiveStatus.scheduled:
        return 'Scheduled';
      case LiveStatus.live:
        return 'LIVE';
      case LiveStatus.paused:
        return 'Paused';
      case LiveStatus.ended:
        return 'Ended';
      case LiveStatus.banned:
        return 'Banned';
    }
  }

  int get colorValue {
    switch (this) {
      case LiveStatus.scheduled:
        return 0xFF00B0FF;
      case LiveStatus.live:
        return 0xFFFF0050;
      case LiveStatus.paused:
        return 0xFFFFAB00;
      case LiveStatus.ended:
        return 0xFFB3B3B3;
      case LiveStatus.banned:
        return 0xFFFF1744;
    }
  }

  Color get color => Color(colorValue);
}
