import 'package:flutter/foundation.dart';

/// Why a LiveKit room stopped being usable.
///
/// `livekit_client` reports [DisconnectReason] on `RoomDisconnectedEvent`, but
/// that enum mixes "we asked for this" with "the server evicted us" and with
/// genuine transport failures. The viewer needs those three groups separated
/// because they demand opposite responses: ignore, show a terminal state, or
/// re-join. [LiveKitDisconnectCause] is that classification.
enum LiveKitDisconnectCause {
  /// The app closed the room itself (live switch, leaving the screen, guest
  /// upgrade). Never retry — retrying is what makes a swipe reopen the room
  /// the viewer just left.
  clientInitiated,

  /// The room no longer exists or this participant was evicted from it.
  /// Re-joining would either fail or immediately be evicted again.
  roomClosed,

  /// The same identity connected somewhere else and the server dropped this
  /// session. Retrying starts a tug-of-war between two devices.
  duplicateIdentity,

  /// The server rejected the credentials (expired/invalid token, missing
  /// grant). A fresh join token is required, an ICE restart cannot help.
  unauthorized,

  /// Signalling or media transport failed. Recoverable with a fresh join.
  network,

  /// Signalling still reports `connected` while inbound video stopped
  /// advancing. Recoverable, but only by replacing the room: the SDK has no
  /// public ICE-restart trigger.
  mediaStalled,

  /// The SDK reported something we could not classify. Treated as recoverable
  /// so a viewer is never left stuck, but logged verbatim.
  unknown,
}

extension LiveKitDisconnectCauseX on LiveKitDisconnectCause {
  /// Whether obtaining fresh credentials and rebuilding the room can help.
  bool get isRecoverable =>
      this == LiveKitDisconnectCause.network ||
      this == LiveKitDisconnectCause.mediaStalled ||
      this == LiveKitDisconnectCause.unknown;

  /// Whether the live itself is over for this viewer.
  bool get isTerminalForLive =>
      this == LiveKitDisconnectCause.roomClosed ||
      this == LiveKitDisconnectCause.duplicateIdentity;
}

/// One monotonic timeline per connection attempt.
///
/// Every stage is reported relative to the same stopwatch and tagged with the
/// live, the room and the connection generation, so a slow or failed join can
/// be attributed to teardown, signalling, subscription or rendering instead of
/// guessed at. Generations make interleaved sessions readable in a flat log:
/// two lines with different `gen=` came from different connection attempts.
class LiveSessionTrace {
  LiveSessionTrace({
    required this.liveId,
    required this.roomName,
    required this.generation,
  }) : _watch = Stopwatch()..start();

  final String liveId;
  final String roomName;
  final int generation;
  final Stopwatch _watch;

  int get elapsedMs => _watch.elapsedMilliseconds;

  /// Records a lifecycle stage. [detail] carries the SDK-provided specifics
  /// (disconnect reason, track sid, error text) that make a log line
  /// actionable instead of merely chronological.
  void mark(String stage, {String? detail}) {
    if (!kDebugMode && !_logInRelease) return;
    debugPrint(
      '[VIDEO-DIAG] $stage'
      ' liveId=$liveId'
      ' room=$roomName'
      ' gen=$generation'
      ' t=${_watch.elapsedMilliseconds}ms'
      '${detail == null ? '' : ' $detail'}',
    );
  }

  /// Disconnects are the one class of event worth keeping in release builds:
  /// they are what an on-call engineer needs and they are rare enough not to
  /// be noisy.
  void markDisconnect(LiveKitDisconnectCause cause, {String? detail}) {
    debugPrint(
      '[VIDEO-DIAG] disconnected'
      ' liveId=$liveId'
      ' room=$roomName'
      ' gen=$generation'
      ' t=${_watch.elapsedMilliseconds}ms'
      ' cause=${cause.name}'
      '${detail == null ? '' : ' $detail'}',
    );
  }

  static const bool _logInRelease = false;
}
