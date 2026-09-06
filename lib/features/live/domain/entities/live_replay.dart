/// Replay and clips (`lives/live-p0-parity.md` §1, `lives/live-p1-parity.md` §5).
///
/// Every value is server-owned: recording, Egress, storage, expiry and the
/// replay view count all belong to the backend. The app only reads state and
/// asks for changes through the documented endpoints.
library;

/// Documented lifecycle: `NONE` → `READY` → `EXPIRED` | `REMOVED`.
enum LiveReplayStatus {
  none('NONE'),
  ready('READY'),
  expired('EXPIRED'),
  removed('REMOVED'),

  /// A status this build does not know. Never treated as playable.
  unknown('UNKNOWN');

  const LiveReplayStatus(this.wireValue);
  final String wireValue;

  static LiveReplayStatus parse(String? value) {
    final upper = value?.toUpperCase();
    for (final status in values) {
      if (status != unknown && status.wireValue == upper) return status;
    }
    return unknown;
  }
}

class LiveReplay {
  const LiveReplay({
    required this.status,
    this.enabled,
    this.available,
    this.url,
    this.expiresAt,
    this.viewCount,
  });

  /// The `replay` object is absent on lives that never had one.
  static const LiveReplay none = LiveReplay(status: LiveReplayStatus.none);

  final LiveReplayStatus status;

  /// Host toggle. Null when the server did not report it.
  final bool? enabled;

  /// The server's own verdict on whether this viewer may watch.
  final bool? available;

  /// Only filled on `ENDED` + `READY`, per the contract.
  final String? url;
  final DateTime? expiresAt;
  final int? viewCount;

  /// A URL alone is not permission: the status and the server's `available`
  /// flag decide. A banned live has no public replay.
  bool get isPlayable =>
      status == LiveReplayStatus.ready &&
      available == true &&
      (url != null && url!.trim().isNotEmpty);

  /// Recording exists but is not watchable yet.
  bool get isPreparing => enabled == true && status == LiveReplayStatus.none;

  bool get isGone =>
      status == LiveReplayStatus.expired || status == LiveReplayStatus.removed;
}

/// Only POSTED is established by P1. Other recognized legacy values below
/// are compatibility values, not proof of preparation or publication success.
enum LiveClipStatus {
  processing('PROCESSING'),
  ready('READY'),
  posted('POSTED'),
  failed('FAILED'),
  unknown('UNKNOWN');

  const LiveClipStatus(this.wireValue);
  final String wireValue;

  static LiveClipStatus parse(String? value) {
    final upper = value?.toUpperCase();
    for (final status in values) {
      if (status != unknown && status.wireValue == upper) return status;
    }
    return unknown;
  }
}

class LiveClip {
  const LiveClip({
    required this.id,
    required this.status,
    this.liveId,
    this.title,
    this.startSeconds,
    this.endSeconds,
    this.clipUrl,
    this.postId,
    this.alreadyPosted,
  });

  final String id;
  final LiveClipStatus status;
  final String? liveId;
  final String? title;

  /// Nullable on purpose: a missing bound is unknown, not zero.
  final num? startSeconds;
  final num? endSeconds;
  final String? clipUrl;

  /// Set once the clip has been published; kept separate from [id] and liveId.
  final String? postId;

  /// The server's idempotency signal on a repeated publish.
  final bool? alreadyPosted;

  bool get isPosted =>
      status == LiveClipStatus.posted && postId?.trim().isNotEmpty == true;
}
