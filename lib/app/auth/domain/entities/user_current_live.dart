import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/core/models/live_media_mode.dart';

/// Typed `currentLive` from `GET /users/:id` and `GET /auth/me` (live-p3 §8).
class UserCurrentLive {
  const UserCurrentLive({
    required this.id,
    this.title,
    this.coverUrl,
    this.viewers = 0,
    this.mediaMode = LiveMediaMode.video,
    this.audioOnly = false,
  });

  final String id;
  final String? title;
  final String? coverUrl;
  final int viewers;
  final String mediaMode;
  final bool audioOnly;

  /// Parses the documented profile payload. Returns null when there is no
  /// broadcast id, or when the payload is scheduled/ended rather than LIVE.
  static UserCurrentLive? tryParse(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final id = raw['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;
    if (_isNonBroadcastStatus(raw['status']?.toString())) return null;

    final mediaMode = LiveMediaMode.normalize(raw['mediaMode']?.toString());
    final audioOnly =
        raw['audioOnly'] == true ||
        LiveMediaMode.isAudio(mediaMode: mediaMode);
    final title = raw['title']?.toString();
    final cover = raw['coverUrl']?.toString() ?? raw['cover']?.toString();

    return UserCurrentLive(
      id: id,
      title: title == null || title.trim().isEmpty ? null : title.trim(),
      coverUrl: cover == null || cover.trim().isEmpty ? null : cover.trim(),
      viewers: _asInt(raw['viewers'] ?? raw['viewerCount']),
      mediaMode: mediaMode,
      audioOnly: audioOnly,
    );
  }

  static bool _isNonBroadcastStatus(String? status) {
    switch (status?.trim().toUpperCase()) {
      case 'PLANNED':
      case 'SCHEDULED':
      case 'ENDED':
      case 'BANNED':
        return true;
      default:
        return false;
    }
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

extension UserProfileLiveX on UserEntity {
  /// Typed `currentLive` when it is a real broadcast, ignoring stale maps.
  UserCurrentLive? get profileCurrentLive =>
      UserCurrentLive.tryParse(currentLive);

  /// Profile LIVE badge: `isLive` wins; never shown for PLANNED/scheduled
  /// payloads or when `currentLive.id` is missing.
  bool get showsProfileLiveBadge {
    if (isLive != true) return false;
    return profileCurrentLive != null;
  }

  /// `isLive == true` without a usable `currentLive.id`.
  bool get hasInconsistentProfileLive =>
      isLive == true && profileCurrentLive == null;
}
