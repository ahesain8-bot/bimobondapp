import '../../../core/models/live_media_mode.dart';
import '../../../core/models/live_topic.dart';

/// Host scheduling helpers for `lives/live-p3-parity.md` §4.
class LivePlannedScheduling {
  const LivePlannedScheduling._();

  static bool isPlannedStatus(String? status) =>
      status?.trim().toUpperCase() == 'PLANNED';

  /// Viewers may join LiveKit only while the live is actually broadcasting.
  static bool viewerMayJoinLiveKit(String? status) =>
      status?.trim().toUpperCase() == 'LIVE';

  /// Host may start early or late — `scheduledAt` is not a client lock.
  static bool canStartNow({DateTime? scheduledAt, DateTime? now}) => true;

  /// `POST /lives` body for a scheduled live. Never includes `startNow`.
  static Map<String, dynamic> createBody({
    required String title,
    required DateTime scheduledAt,
    String mediaMode = 'VIDEO',
    String? coverUrl,
    String? topic,
    String? categoryId,
  }) {
    final normalizedTopic = LiveTopic.normalize(topic);
    final trimmedCover = coverUrl?.trim();
    final cover = (trimmedCover == null || trimmedCover.isEmpty)
        ? null
        : trimmedCover;
    final trimmedCategory = categoryId?.trim();
    final category = (trimmedCategory == null || trimmedCategory.isEmpty)
        ? null
        : trimmedCategory;
    return {
      'title': title.trim().isEmpty ? 'بث مباشر' : title.trim(),
      'scheduledAt': LiveSchedule.toUtcIso(scheduledAt),
      'mediaMode': LiveMediaMode.normalize(mediaMode),
      'coverUrl': ?cover,
      'topic': ?normalizedTopic,
      'categoryId': ?category,
    };
  }

  static Map<String, dynamic> rescheduleBody(DateTime scheduledAt) => {
    'scheduledAt': LiveSchedule.toUtcIso(scheduledAt),
  };

  /// Clears calendar time; status stays `PLANNED`. This is not a delete.
  static Map<String, dynamic> clearScheduledTimeBody() => {
    'scheduledAt': null,
  };

  static List<Map<String, dynamic>> plannedMapsFromMinePayload(
    Map<String, dynamic> json,
  ) {
    final raw = json['data'] ?? json['items'] ?? json['lives'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => isPlannedStatus(e['status']?.toString()))
        .toList(growable: false);
  }
}
