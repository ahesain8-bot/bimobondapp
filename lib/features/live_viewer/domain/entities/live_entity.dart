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
  /// Server pause flag (`paused`). Status stays `LIVE` while this is true.
  final bool paused;
  /// Stored `VIDEO` | `AUDIO`.
  final String mediaMode;
  /// Voice Chat rooms: avatars / waveform, never a video renderer.
  final bool audioOnly;
  /// `CAMERA` | `SCREEN` | `DUAL`.
  final String scene;
  /// `front` | `back`.
  final String cameraFacing;
  final bool dualCameraEnabled;
  /// Radio / room topic (max 80). Feature #3 may filter feed on this value.
  final String? topic;
  /// Present on `PLANNED` lives. ISO-8601 UTC from the backend.
  final DateTime? scheduledAt;
  final int shareCount;
  final String? houseId;
  /// 18+ join/detail gate. Backend is authoritative.
  final bool ageRestricted;
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
    this.paused = false,
    this.mediaMode = 'VIDEO',
    this.audioOnly = false,
    this.scene = 'CAMERA',
    this.cameraFacing = 'front',
    this.dualCameraEnabled = false,
    this.topic,
    this.scheduledAt,
    this.shareCount = 0,
    this.houseId,
    this.ageRestricted = false,
    this.metadata,
    this.isFollowing = false,
    this.isPromoted = false,
    this.promotion,
  });

  bool get isAudioOnly => audioOnly || mediaMode.toUpperCase() == 'AUDIO';
  bool get isFrontCamera => cameraFacing.toLowerCase() != 'back';

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
    bool? paused,
    String? mediaMode,
    bool? audioOnly,
    String? scene,
    String? cameraFacing,
    bool? dualCameraEnabled,
    String? topic,
    DateTime? scheduledAt,
    int? shareCount,
    Object? houseId = _liveEntityUnset,
    bool? ageRestricted,
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
      paused: paused ?? this.paused,
      mediaMode: mediaMode ?? this.mediaMode,
      audioOnly: audioOnly ?? this.audioOnly,
      scene: scene ?? this.scene,
      cameraFacing: cameraFacing ?? this.cameraFacing,
      dualCameraEnabled: dualCameraEnabled ?? this.dualCameraEnabled,
      topic: topic ?? this.topic,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      shareCount: shareCount ?? this.shareCount,
      houseId: identical(houseId, _liveEntityUnset)
          ? this.houseId
          : houseId as String?,
      ageRestricted: ageRestricted ?? this.ageRestricted,
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
    paused,
    mediaMode,
    audioOnly,
    scene,
    cameraFacing,
    dualCameraEnabled,
    topic,
    scheduledAt,
    shareCount,
    houseId,
    ageRestricted,
    metadata,
    isPromoted,
    promotion,
  ];
}

enum LiveStatus { scheduled, live, paused, ended, banned }

extension LiveStatusViewerJoin on LiveStatus {
  /// Viewers connect LiveKit only while the room is broadcasting.
  bool get allowsViewerLiveKitJoin => this == LiveStatus.live;
}

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

const Object _liveEntityUnset = Object();
