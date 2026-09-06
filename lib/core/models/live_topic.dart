/// Live `topic` (max 80) and `scheduledAt` (ISO-8601 UTC).
///
/// Backend: `POST /lives`, `PATCH /lives/:id`, `PATCH /lives/:id/settings`
/// (`lives/live-p3-parity.md`, `enhanced-live-performance.md` §9).
class LiveTopic {
  const LiveTopic._();

  static const maxLength = 80;

  static String? normalize(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }
}

class LiveSchedule {
  const LiveSchedule._();

  /// Serialize for `scheduledAt`. Always UTC with a `Z` suffix.
  static String toUtcIso(DateTime value) {
    final utc = value.toUtc();
    final iso = utc.toIso8601String();
    return iso.endsWith('Z') ? iso : '${iso}Z';
  }

  static DateTime? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    return DateTime.tryParse(raw.toString())?.toUtc();
  }
}
