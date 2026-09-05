import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/models/live_media_hints.dart';
import '../../../../core/services/live_audio_session.dart';
import '../../../../core/services/media_progress_watchdog.dart';
import 'fake_livekit_service.dart'
    show LiveKitConnectionState, LiveKitService, LiveKitSessionUpdate;
import 'live_session_diagnostics.dart';

/// How often the viewer health watchdog samples inbound media counters.
const Duration _kMediaHealthTick = Duration(seconds: 2);

/// Consecutive stalled samples before a connected-but-frozen room is reported.
/// At [_kMediaHealthTick] this is ten seconds of a picture that is not
/// advancing while the track is subscribed, unmuted, un-paused by the SFU and
/// attached to a renderer — every legitimate reason for frames to stop has
/// already been excluded by then.
const int _kStalledSampleLimit = 5;

/// Upper bound on the graceful leave of a room we are throwing away.
///
/// `Room.disconnect()` in livekit_client 2.11 awaits `EngineDisconnectedEvent`
/// for ten seconds (`core/room.dart`) and then throws. A socket that is
/// already dead never delivers that event, which is exactly the situation when
/// a viewer swipes away from a broken live. Bounding the polite leave keeps a
/// dead room from delaying the next join; `dispose()` afterwards tears the
/// engine down unconditionally either way.
const Duration _kGracefulLeaveTimeout = Duration(seconds: 2);

class RealLiveKitService implements LiveKitService {
  final _sessionController = StreamController<LiveKitSessionUpdate>.broadcast();
  final _battleStateController =
      StreamController<LiveKitConnectionState>.broadcast();

  LiveKitConnectionState _state = LiveKitConnectionState.disconnected;
  String? _roomName;
  String? _streamUrl;
  String? _url;
  String? _token;
  LiveMediaHints? _mediaHints;

  // ── Primary room ownership ────────────────────────────────────────────────
  //
  // Exactly one primary Room is authoritative at a time, identified by
  // [_primaryGeneration]. The counter is bumped synchronously by every caller
  // that intends to replace or close the room, *before* any await, so a
  // callback belonging to a superseded attempt can recognise itself and return
  // without touching shared state. Room identity alone is not enough: the same
  // object can be current for one generation and retired for the next.
  Room? _room;
  int _primaryGeneration = 0;
  int _roomGeneration = -1;
  LiveSessionTrace? _trace;

  /// Serializes primary connect/disconnect so two operations can never
  /// interleave their teardown and setup phases.
  Future<void> _primaryQueue = Future<void>.value();

  /// Room releases that were allowed to finish in the background.
  final Set<Future<void>> _pendingReleases = <Future<void>>{};

  Room? _battleRoom;
  Room? _battleRecoveryRoom;
  Future<void> _battleOperationQueue = Future<void>.value();
  var _battleConnectionGeneration = 0;
  Timer? _primaryVideoHealthTimer;
  Timer? _battleVideoHealthTimer;
  bool _primaryHealthCheckInFlight = false;
  bool _battleHealthCheckInFlight = false;
  final _primaryVideoProgress = MediaProgressWatchdog(
    stalledSampleLimit: _kStalledSampleLimit,
  );
  final _battleVideoProgress = MediaProgressWatchdog(stalledSampleLimit: 5);

  /// Whether this service currently holds [LiveAudioSession]. The battle room
  /// coming and going must never touch it — only entering and leaving the live
  /// does, which is what keeps a PK teardown from silencing the primary room.
  bool _holdsAudioSession = false;

  /// LiveKit 2.11 can leave an internal participant-update callback waiting
  /// for `RoomConnectedEvent` after a room has already been replaced. Ten
  /// seconds later that callback throws an unhandled TimeoutException from
  /// the SDK event stream and Android terminates the whole app. Keep every
  /// Room and its subscriptions inside a guarded zone: normal connect errors
  /// still reach the caller, while only this stale SDK timeout is absorbed.
  Future<T> _runWithLiveKitErrorGuard<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    runZonedGuarded(
      () async {
        try {
          final value = await action();
          if (!completer.isCompleted) completer.complete(value);
        } catch (error, stack) {
          if (!completer.isCompleted) {
            completer.completeError(error, stack);
          } else {
            Zone.root.handleUncaughtError(error, stack);
          }
        }
      },
      (error, stack) {
        final isStaleSdkTimeout =
            error.toString().contains('Timeout') &&
            stack.toString().contains('package:livekit_client/');
        if (isStaleSdkTimeout) {
          debugPrint('LiveKit ignored stale room callback timeout: $error');
          return;
        }
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        } else {
          Zone.root.handleUncaughtError(error, stack);
        }
      },
    );
    return completer.future;
  }

  @override
  LiveKitConnectionState get state => _state;

  @override
  Stream<LiveKitConnectionState> get stateStream =>
      _sessionController.stream.map((update) => update.state);

  @override
  Stream<LiveKitSessionUpdate> get sessionStream => _sessionController.stream;

  @override
  Stream<LiveKitConnectionState> get battleStateStream =>
      _battleStateController.stream;

  @override
  String? get roomName => _roomName;

  @override
  String? get streamUrl => _streamUrl;

  @override
  LiveMediaHints? get mediaHints => _mediaHints;

  /// The underlying LiveKit room the renderer subscribes to.
  @override
  Room? get room => _room;

  @override
  Room? get battleRoom => _battleRoom;

  /// True while [room] is the room belonging to the newest connect request.
  bool _isCurrent(Room room, int generation) =>
      generation == _primaryGeneration &&
      identical(_room, room) &&
      _roomGeneration == generation;

  Future<void> _acquireAudioSession() async {
    if (_holdsAudioSession) return;
    await LiveAudioSession.instance.acquire();
    _holdsAudioSession = true;
  }

  Future<void> _releaseAudioSession() async {
    if (!_holdsAudioSession) return;
    await LiveAudioSession.instance.release();
    _holdsAudioSession = false;
  }

  Future<T> _serializePrimary<T>(Future<T> Function() operation) {
    final previous = _primaryQueue;
    final result = previous.then((_) => operation());
    // A failed connect must not wedge the queue for the next live.
    _primaryQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<T> _serializeBattleOperation<T>(Future<T> Function() operation) {
    final previous = _battleOperationQueue;
    final result = previous.then((_) => operation());
    // Keep a failed reconnect from blocking a later battle-end/disconnect,
    // while preserving the original error for its caller.
    _battleOperationQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  // ── Lifecycle emission ────────────────────────────────────────────────────

  void _emit(
    LiveKitConnectionState next, {
    required int generation,
    LiveKitDisconnectCause? cause,
    String? detail,
  }) {
    if (generation != _primaryGeneration) return;
    if (_sessionController.isClosed) return;
    _state = next;
    _sessionController.add(
      LiveKitSessionUpdate(
        state: next,
        generation: generation,
        roomName: _roomName,
        cause: cause,
        detail: detail,
      ),
    );
  }

  static LiveKitDisconnectCause _causeFor(DisconnectReason? reason) {
    switch (reason) {
      case DisconnectReason.clientInitiated:
      case DisconnectReason.migration:
        return LiveKitDisconnectCause.clientInitiated;
      case DisconnectReason.duplicateIdentity:
        return LiveKitDisconnectCause.duplicateIdentity;
      case DisconnectReason.roomDeleted:
      case DisconnectReason.roomClosed:
      case DisconnectReason.participantRemoved:
      case DisconnectReason.serverShutdown:
        return LiveKitDisconnectCause.roomClosed;
      case DisconnectReason.joinFailure:
        // The server refused the join outright. On this backend that is
        // almost always an expired or revoked join token, and only a fresh
        // `POST /lives/:id/join` can fix it.
        return LiveKitDisconnectCause.unauthorized;
      case DisconnectReason.disconnected:
      case DisconnectReason.signalingConnectionFailure:
      case DisconnectReason.signalClose:
      case DisconnectReason.reconnectAttemptsExceeded:
      case DisconnectReason.stateMismatch:
      case DisconnectReason.connectionTimeout:
      case DisconnectReason.mediaFailure:
        return LiveKitDisconnectCause.network;
      case null:
      case DisconnectReason.unknown:
      default:
        return LiveKitDisconnectCause.unknown;
    }
  }

  static LiveKitDisconnectCause _causeForConnectError(Object error) {
    if (error is ConnectException) {
      switch (error.reason) {
        case ConnectionErrorReason.NotAllowed:
          // 401/403 from the signalling handshake: the join token is expired,
          // revoked, or lacks the grant. Only a fresh `POST /lives/:id/join`
          // can fix it, so retrying this token would loop forever.
          return LiveKitDisconnectCause.unauthorized;
        case ConnectionErrorReason.Timeout:
        case ConnectionErrorReason.InternalError:
          return LiveKitDisconnectCause.network;
      }
    }
    if (error is MediaConnectException || error is NegotiationError) {
      return LiveKitDisconnectCause.network;
    }
    // `dart:async` and `livekit_client` both declare a `TimeoutException`;
    // matching on the name classifies either without an ambiguous import.
    if (error.runtimeType.toString().contains('TimeoutException')) {
      return LiveKitDisconnectCause.network;
    }
    return LiveKitDisconnectCause.unknown;
  }

  // ── Room configuration ────────────────────────────────────────────────────

  /// Stable LiveKit 2.11 viewer profile.
  ///
  /// `adaptiveStream` is what picks the simulcast layer: the SDK measures the
  /// mounted `VideoTrackRenderer`, converts it to physical pixels and asks the
  /// SFU for the matching layer. Nothing else may call `setVideoQuality` or
  /// `setVideoDimensions` on a remote publication — 2.11 merges a manual
  /// preference with the adaptive dimensions by taking the *smaller* of the
  /// two (`publication/track_settings.dart`), so any manual value is a ceiling,
  /// never a floor.
  ///
  /// `dynacast` stays off: it is a publisher-side optimisation with no benefit
  /// to a subscribe-only viewer, and enabling it previously made the host track
  /// disappear on Android when the codec was renegotiated.
  static const _roomOptions = RoomOptions(
    adaptiveStream: true,
    dynacast: false,
    defaultAudioCaptureOptions: AudioCaptureOptions(
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
      voiceIsolation: true,
      stopAudioCaptureOnMute: false,
    ),
    defaultAudioPublishOptions: AudioPublishOptions(dtx: true, red: true),
    defaultVideoPublishOptions: VideoPublishOptions(
      simulcast: true,
      backupVideoCodec: BackupVideoCodec(enabled: false),
    ),
  );

  /// `autoSubscribe` is the default and is what makes the viewer receive the
  /// host track without a round trip; the explicit value documents that the
  /// subscribe-only viewer depends on it. Timeouts are left at the SDK
  /// defaults (10s connection) rather than tuned to a number we cannot
  /// justify on a mobile network.
  static const _connectOptions = ConnectOptions(autoSubscribe: true);

  Future<void> _preferMediaSpeaker() async {
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(true, force: false);
    } catch (error) {
      debugPrint('Live audio route selection failed: $error');
    }
  }

  // ── Track helpers ─────────────────────────────────────────────────────────

  Future<void> _retryRemoteSubscription(
    Room room,
    TrackSubscriptionExceptionEvent event, {
    int? battleGeneration,
    int? primaryGeneration,
  }) async {
    // The SDK raises this when a track arrives before its metadata. Retrying
    // immediately loses to the same race, so wait for the metadata round trip
    // the SDK is already waiting on before asking again.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (primaryGeneration != null &&
        !_isCurrent(room, primaryGeneration)) {
      return;
    }
    if (battleGeneration != null) {
      if (battleGeneration != _battleConnectionGeneration) return;
      if (!identical(_battleRoom, room)) return;
    }
    final participant = event.participant;
    if (participant == null) return;
    final publication = participant.trackPublications[event.sid];
    if (publication is! RemoteTrackPublication || publication.subscribed) {
      return;
    }
    try {
      await publication.subscribe();
    } catch (error) {
      debugPrint('LiveKit remote track resubscribe failed: $error');
    }
  }

  /// Safety net for publications the server did not auto-subscribe us to.
  /// With [ConnectOptions.autoSubscribe] this is normally a no-op.
  Future<void> _ensureRemoteTracksSubscribed(Room room) async {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.trackPublications.values) {
        if (publication.subscribed) continue;
        try {
          await publication.subscribe();
        } catch (error) {
          debugPrint('LiveKit remote track subscribe failed: $error');
        }
      }
    }
  }

  /// The publication the viewer is actually watching, or null.
  ///
  /// Muted and SFU-paused publications are deliberately included: they are
  /// still the active track, the renderer stays attached to them, and treating
  /// them as "gone" is what previously tore down healthy rooms whenever a host
  /// covered their camera.
  RemoteTrackPublication<RemoteVideoTrack>? _primaryVideoPublication(
    Room room,
  ) {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        if (publication.subscribed && publication.track != null) {
          return publication;
        }
      }
    }
    return null;
  }

  RemoteVideoTrack? _firstRemoteVideoTrack(Room room) {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (publication.subscribed && !publication.muted && track != null) {
          return track;
        }
      }
    }
    return null;
  }

  /// Pre-subscribe the opponent before the PK split is revealed. This avoids
  /// building one live tile while the second room still has no video track.
  Future<bool> _waitForBattleVideo(Room room, {required int generation}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (_battleRoom != room || generation != _battleConnectionGeneration) {
        return false;
      }
      await _ensureRemoteTracksSubscribed(room);
      if (_firstRemoteVideoTrack(room) != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _firstRemoteVideoTrack(room) != null;
  }

  Future<num?> _receiverVideoProgress(RemoteVideoTrack track) async {
    final stats = await track.getReceiverStats();
    if (stats == null) return null;
    return stats.framesDecoded ??
        stats.framesReceived ??
        stats.packetsReceived ??
        stats.bytesReceived;
  }

  // ── Primary media watchdog ────────────────────────────────────────────────

  void _startPrimaryVideoWatchdog(Room room, int generation) {
    _stopPrimaryVideoWatchdog();
    _primaryVideoProgress.reset();
    _primaryVideoHealthTimer = Timer.periodic(_kMediaHealthTick, (_) {
      if (_primaryHealthCheckInFlight || !_isCurrent(room, generation)) return;
      _primaryHealthCheckInFlight = true;
      unawaited(
        _samplePrimaryVideo(room, generation).whenComplete(() {
          _primaryHealthCheckInFlight = false;
        }),
      );
    });
  }

  /// Samples inbound video only when every non-failure explanation for frames
  /// not advancing has been ruled out:
  ///
  /// * the room is connected (a reconnect handles itself),
  /// * a video publication exists and is subscribed,
  /// * the host has not muted it,
  /// * the SFU has not paused it for bandwidth (`StreamState.paused`),
  /// * a renderer is attached, so adaptive stream has not paused it for
  ///   invisibility.
  ///
  /// Anything else is a legitimate reason for a still picture and must never
  /// cost the viewer their connection.
  Future<void> _samplePrimaryVideo(Room room, int generation) async {
    try {
      if (room.connectionState != ConnectionState.connected) return;
      final publication = _primaryVideoPublication(room);
      final track = publication?.track;
      if (publication == null || track == null) {
        _primaryVideoProgress.reset();
        return;
      }
      // `enabled` is false exactly when adaptive stream has told the SFU to
      // stop sending because no visible renderer is registered for the track.
      if (publication.muted ||
          !publication.enabled ||
          publication.streamState == StreamState.paused) {
        _primaryVideoProgress.reset();
        return;
      }
      final progress = await _receiverVideoProgress(track);
      if (!_isCurrent(room, generation)) return;
      if (!_primaryVideoProgress.addSample(progress)) return;
      _reportPrimaryVideoStall(room, generation);
    } catch (error) {
      debugPrint('Viewer inbound health sample unavailable: $error');
    }
  }

  void _reportPrimaryVideoStall(Room room, int generation) {
    if (!_isCurrent(room, generation)) return;
    _stopPrimaryVideoWatchdog();
    _trace?.markDisconnect(
      LiveKitDisconnectCause.mediaStalled,
      detail: 'framesDecoded frozen for '
          '${_kStalledSampleLimit * _kMediaHealthTick.inSeconds}s '
          'while room=connected',
    );
    // Policy lives above the SDK: the viewer BLoC obtains a fresh join token
    // and replaces the Room. livekit_client 2.11 exposes no ICE-restart
    // trigger, so reusing dead transport is not an option.
    _emit(
      LiveKitConnectionState.disconnected,
      generation: generation,
      cause: LiveKitDisconnectCause.mediaStalled,
      detail: 'inbound_video_stalled',
    );
  }

  void _stopPrimaryVideoWatchdog() {
    _primaryVideoHealthTimer?.cancel();
    _primaryVideoHealthTimer = null;
    _primaryVideoProgress.reset();
  }

  // ── Room release ──────────────────────────────────────────────────────────

  /// Closes a room we no longer own, without letting it delay anything.
  Future<void> _releaseRoom(Room room, {required String label}) async {
    try {
      await room
          .disconnect()
          .timeout(_kGracefulLeaveTimeout, onTimeout: () {});
    } catch (error) {
      debugPrint('LiveKit $label graceful leave failed: $error');
    }
    try {
      await room.dispose();
    } catch (error) {
      debugPrint('LiveKit $label dispose failed: $error');
    }
  }

  /// Retires the current primary room.
  ///
  /// While [LiveAudioSession] is held, LiveKit's Android audio session is in
  /// manual mode and `Room._cleanUp()` can no longer stop it, so the release
  /// shares no mutable state with the room that replaces it and is allowed to
  /// finish in the background. That is what keeps a dead socket from adding
  /// seconds to the next join. Without the session held, the release is
  /// awaited so teardown ordering stays exactly as the SDK expects.
  Future<void> _retirePrimaryRoom() async {
    _stopPrimaryVideoWatchdog();
    final room = _room;
    _room = null;
    _roomGeneration = -1;
    _publishing = false;
    _streamUrl = null;
    if (room == null) return;
    final release = _releaseRoom(room, label: 'primary');
    if (_holdsAudioSession) {
      _trackBackgroundRelease(release);
      return;
    }
    await release;
  }

  void _trackBackgroundRelease(Future<void> release) {
    late final Future<void> tracked;
    tracked = release.whenComplete(() => _pendingReleases.remove(tracked));
    _pendingReleases.add(tracked);
  }

  Future<void> _drainPendingReleases() async {
    while (_pendingReleases.isNotEmpty) {
      await Future.wait(_pendingReleases.toList(growable: false));
    }
  }

  // ── Primary connect ───────────────────────────────────────────────────────

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
    String? mockStreamUrl,
    LiveMediaHints? mediaHints,
  }) {
    // Bumped before any await so a connect already in flight — including one
    // still queued behind a teardown — recognises itself as superseded.
    final generation = ++_primaryGeneration;
    _roomName = roomName;
    final trace = LiveSessionTrace(
      liveId: roomName,
      roomName: roomName,
      generation: generation,
    );
    _trace = trace;
    trace.mark(
      'connect requested',
      detail: 'urlPresent=${url.isNotEmpty} tokenPresent=${token.isNotEmpty}',
    );
    _emit(LiveKitConnectionState.connecting, generation: generation);
    return _serializePrimary(
      () => _connectPrimary(
        url: url,
        token: token,
        roomName: roomName,
        mockStreamUrl: mockStreamUrl,
        mediaHints: mediaHints,
        generation: generation,
        trace: trace,
      ),
    );
  }

  Future<void> _connectPrimary({
    required String url,
    required String token,
    required String roomName,
    required String? mockStreamUrl,
    required LiveMediaHints? mediaHints,
    required int generation,
    required LiveSessionTrace trace,
  }) async {
    if (generation != _primaryGeneration) {
      trace.mark('connect superseded before start');
      return;
    }

    // Taken before the old room is retired: a guest upgrade replaces the
    // primary room mid-live and that teardown must not drop the session.
    // Holding the session is also what makes the background release safe.
    try {
      await _acquireAudioSession();
    } catch (error) {
      debugPrint('LiveKit audio session unavailable: $error');
    }

    await _retireBattleRoom();
    await _retirePrimaryRoom();
    trace.mark('previous room released');

    if (generation != _primaryGeneration) {
      trace.mark('connect superseded during release');
      return;
    }

    if (url.isEmpty || token.isEmpty) {
      await _releaseAudioSession();
      _emit(
        LiveKitConnectionState.failed,
        generation: generation,
        cause: LiveKitDisconnectCause.unauthorized,
        detail: 'missing url/token',
      );
      throw StateError('LiveKit url/token missing — re-join the live');
    }

    _url = url;
    _token = token;
    _mediaHints = mediaHints ?? LiveMediaHints.defaultsForRole('viewer');
    _roomName = roomName;

    final room = Room(roomOptions: _roomOptions);
    _attachPrimaryListeners(room, generation, trace);
    // Own the room before connect() starts emitting lifecycle callbacks.
    _room = room;
    _roomGeneration = generation;

    try {
      await _runWithLiveKitErrorGuard(
        () => room.connect(url, token, connectOptions: _connectOptions),
      );
    } catch (error, stackTrace) {
      final cause = _causeForConnectError(error);
      trace.markDisconnect(cause, detail: 'connect threw ${error.runtimeType}');
      debugPrint('❌ LiveKit connect failed: $error\n$stackTrace');
      if (generation == _primaryGeneration) {
        _room = null;
        _roomGeneration = -1;
        await _releaseAudioSession();
        _emit(
          LiveKitConnectionState.failed,
          generation: generation,
          cause: cause,
          detail: error.toString(),
        );
      }
      // Never dispose through `_room`: by this point it may already belong to
      // a newer attempt. Only the room this call created is released.
      unawaited(_releaseRoom(room, label: 'failed primary'));
      rethrow;
    }

    if (generation != _primaryGeneration) {
      trace.mark('connect superseded after signalling');
      unawaited(_releaseRoom(room, label: 'superseded primary'));
      return;
    }

    _streamUrl = mockStreamUrl;
    unawaited(_preferMediaSpeaker());
    // Publications that already existed when we joined are auto-subscribed by
    // the server; this covers the rare case where one was rejected.
    unawaited(_ensureRemoteTracksSubscribed(room));
    // `RoomConnectedEvent` has normally already emitted `connected`; this
    // makes the post-condition of connect() explicit for callers that awaited
    // it and covers an event delivered before our listener was attached.
    _emit(LiveKitConnectionState.connected, generation: generation);
    _startPrimaryVideoWatchdog(room, generation);
    trace.mark('connect completed');
  }

  void _attachPrimaryListeners(
    Room room,
    int generation,
    LiveSessionTrace trace,
  ) {
    room.events
      ..on<RoomConnectedEvent>((_) {
        if (!_isCurrent(room, generation)) return;
        trace.mark('room connected');
        // Signalling is up: release the renderer now so texture creation
        // overlaps track subscription instead of following it. The renderer
        // paints the live's poster through VideoTrackRenderer's
        // placeholderBuilder until the first decoded frame arrives.
        _emit(LiveKitConnectionState.connected, generation: generation);
      })
      ..on<RoomDisconnectedEvent>((event) {
        if (!_isCurrent(room, generation)) return;
        final cause = _causeFor(event.reason);
        trace.markDisconnect(cause, detail: 'sdkReason=${event.reason?.name}');
        _stopPrimaryVideoWatchdog();
        _emit(
          LiveKitConnectionState.disconnected,
          generation: generation,
          cause: cause,
          detail: event.reason?.name,
        );
      })
      ..on<ReconnectingEvent>((_) {
        if (!_isCurrent(room, generation)) return;
        trace.mark('reconnecting');
        _stopPrimaryVideoWatchdog();
        _emit(LiveKitConnectionState.reconnecting, generation: generation);
      })
      ..on<RoomReconnectedEvent>((_) {
        if (!_isCurrent(room, generation)) return;
        trace.mark('reconnected');
        unawaited(_completePrimaryReconnect(room, generation));
      })
      ..on<ParticipantConnectedEvent>((event) {
        if (!_isCurrent(room, generation)) return;
        trace.mark(
          'participant connected',
          detail: 'identity=${event.participant.identity}',
        );
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        if (!_isCurrent(room, generation)) return;
        // The host leaving is not a viewer disconnect. The room stays up and
        // the poster is shown until a track returns or the backend ends the
        // live over Socket.IO.
        trace.mark(
          'participant disconnected',
          detail: 'identity=${event.participant.identity}',
        );
      })
      ..on<TrackPublishedEvent>((event) {
        if (!_isCurrent(room, generation)) return;
        trace.mark(
          'track published',
          detail: 'sid=${event.publication.sid} kind=${event.publication.kind}',
        );
        if (!event.publication.subscribed) {
          unawaited(_ensureRemoteTracksSubscribed(room));
        }
      })
      ..on<TrackSubscribedEvent>((event) {
        if (!_isCurrent(room, generation)) return;
        if (event.track is RemoteAudioTrack) {
          unawaited(_preferMediaSpeaker());
          return;
        }
        if (event.track is! RemoteVideoTrack) return;
        final publication = event.publication;
        trace.mark(
          'video track subscribed',
          detail:
              'sid=${publication.sid}'
              ' mime=${publication.mimeType}'
              ' simulcast=${publication.simulcasted}'
              ' published=${publication.dimensions?.width}'
              'x${publication.dimensions?.height}',
        );
        // A track that arrives before the renderer is mounted is fine: the
        // publication is held by the Room, the player picks it up from the
        // Room's ChangeNotifier on the next frame, and adaptive stream
        // recomputes the layer as soon as a view registers.
        _primaryVideoProgress.reset();
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (!_isCurrent(room, generation)) return;
        trace.mark('track unsubscribed', detail: 'sid=${event.publication.sid}');
        _primaryVideoProgress.reset();
      })
      ..on<TrackMutedEvent>((event) {
        if (!_isCurrent(room, generation)) return;
        trace.mark('track muted', detail: 'sid=${event.publication.sid}');
        _primaryVideoProgress.reset();
      })
      ..on<TrackUnmutedEvent>((event) {
        if (!_isCurrent(room, generation)) return;
        trace.mark('track unmuted', detail: 'sid=${event.publication.sid}');
        _primaryVideoProgress.reset();
      })
      ..on<TrackStreamStateUpdatedEvent>((event) {
        if (!_isCurrent(room, generation)) return;
        trace.mark(
          'stream state',
          detail:
              'sid=${event.publication.sid} state=${event.streamState.name}',
        );
        // The SFU pausing a layer for bandwidth is normal behaviour, not a
        // stall. Restart the baseline so resuming does not look frozen.
        _primaryVideoProgress.reset();
      })
      ..on<TrackSubscriptionExceptionEvent>((event) {
        if (!_isCurrent(room, generation)) return;
        trace.mark(
          'track subscription failed',
          detail: 'sid=${event.sid} reason=${event.reason.name}',
        );
        unawaited(
          _retryRemoteSubscription(
            room,
            event,
            primaryGeneration: generation,
          ),
        );
      });
  }

  /// A native reconnect preserves the Room, its participants and its
  /// subscriptions. Nothing needs rebuilding — re-assert the audio route,
  /// restore this device's publications if it is on stage, and resume health
  /// sampling. Absence of a remote video track here is not a failure: the host
  /// may simply have their camera off.
  Future<void> _completePrimaryReconnect(Room room, int generation) async {
    if (!_isCurrent(room, generation)) return;
    _emit(LiveKitConnectionState.connected, generation: generation);
    _startPrimaryVideoWatchdog(room, generation);
    unawaited(_preferMediaSpeaker());
    unawaited(_ensureRemoteTracksSubscribed(room));
    if (_publishing) {
      final hints = _mediaHints ?? LiveMediaHints.defaultsForRole('guest');
      try {
        await _restoreStageTracks(room, hints);
      } catch (error) {
        debugPrint('Guest republish after reconnect failed: $error');
      }
    }
  }

  // ── Battle room ───────────────────────────────────────────────────────────

  void _queueBattleRecovery({
    required Room room,
    required String url,
    required String token,
    required String roomName,
  }) {
    final generation = _battleConnectionGeneration;
    unawaited(
      _serializeBattleOperation(() async {
        await _recoverBattleRoom(
          room: room,
          url: url,
          token: token,
          roomName: roomName,
          generation: generation,
        );
        if (generation == _battleConnectionGeneration &&
            _battleRoom == room &&
            room.connectionState == ConnectionState.connected) {
          _setBattleState(LiveKitConnectionState.connected);
        } else if (generation == _battleConnectionGeneration &&
            _battleRoom == room &&
            room.connectionState == ConnectionState.disconnected) {
          _setBattleState(LiveKitConnectionState.failed);
        }
      }),
    );
  }

  void _startBattleVideoWatchdog({
    required Room room,
    required String url,
    required String token,
    required String roomName,
  }) {
    _stopBattleVideoWatchdog();
    _battleVideoProgress.reset();
    _battleVideoHealthTimer = Timer.periodic(_kMediaHealthTick, (_) {
      if (_battleHealthCheckInFlight || _battleRoom != room) return;
      _battleHealthCheckInFlight = true;
      unawaited(
        _sampleBattleVideo(
          room: room,
          url: url,
          token: token,
          roomName: roomName,
        ).whenComplete(() {
          _battleHealthCheckInFlight = false;
        }),
      );
    });
  }

  Future<void> _sampleBattleVideo({
    required Room room,
    required String url,
    required String token,
    required String roomName,
  }) async {
    final generation = _battleConnectionGeneration;
    try {
      final track = _firstRemoteVideoTrack(room);
      if (_battleRoom != room || generation != _battleConnectionGeneration) {
        return;
      }
      if (track == null) {
        await _ensureRemoteTracksSubscribed(room);
        if (!_battleVideoProgress.addMissingTrackSample()) return;
      } else {
        final progress = await _receiverVideoProgress(track);
        if (_battleRoom != room ||
            generation != _battleConnectionGeneration ||
            !_battleVideoProgress.addSample(progress)) {
          return;
        }
      }
      debugPrint('🔴 Battle opponent video stalled: $roomName');
      _stopBattleVideoWatchdog();
      await _serializeBattleOperation(
        () => _restartStalledBattleRoom(
          room: room,
          url: url,
          token: token,
          roomName: roomName,
          generation: generation,
        ),
      );
    } catch (error) {
      debugPrint('Battle inbound health sample unavailable: $error');
    }
  }

  Future<void> _restartStalledBattleRoom({
    required Room room,
    required String url,
    required String token,
    required String roomName,
    required int generation,
  }) async {
    if (_battleRoom != room ||
        _battleRecoveryRoom == room ||
        generation != _battleConnectionGeneration) {
      return;
    }
    _battleRecoveryRoom = room;
    var failed = false;
    try {
      await room.disconnect().timeout(
        _kGracefulLeaveTimeout,
        onTimeout: () {},
      );
      if (_battleRoom != room || generation != _battleConnectionGeneration) {
        return;
      }
      await _runWithLiveKitErrorGuard(
        () => room.connect(url, token, connectOptions: _connectOptions),
      );
      if (_battleRoom != room || generation != _battleConnectionGeneration) {
        unawaited(_releaseRoom(room, label: 'stale battle'));
        return;
      }
      await _ensureRemoteTracksSubscribed(room);
      await _preferMediaSpeaker();
      _setBattleState(LiveKitConnectionState.connected);
      _startBattleVideoWatchdog(
        room: room,
        url: url,
        token: token,
        roomName: roomName,
      );
    } catch (error) {
      failed = true;
      debugPrint('Battle stalled-room restart failed: $error');
    } finally {
      if (_battleRecoveryRoom == room) _battleRecoveryRoom = null;
    }
    if (failed &&
        _battleRoom == room &&
        generation == _battleConnectionGeneration) {
      _queueBattleRecovery(
        room: room,
        url: url,
        token: token,
        roomName: roomName,
      );
    }
  }

  void _stopBattleVideoWatchdog() {
    _battleVideoHealthTimer?.cancel();
    _battleVideoHealthTimer = null;
    _battleVideoProgress.reset();
  }

  /// A normal LiveKit reconnect preserves the Room and its tracks. On some
  /// Android networks the SDK exhausts that reconnect and emits a terminal
  /// disconnect instead; keeping the dead Room made one PK tile stay blank
  /// until the battle ended. Re-use the still-valid battle JWT for a few
  /// bounded reconnect attempts and restore every remote subscription.
  Future<void> _recoverBattleRoom({
    required Room room,
    required String url,
    required String token,
    required String roomName,
    required int generation,
  }) async {
    if (_battleRoom != room ||
        _battleRecoveryRoom == room ||
        generation != _battleConnectionGeneration) {
      return;
    }
    _battleRecoveryRoom = room;
    const retryDelays = <Duration>[
      Duration(milliseconds: 250),
      Duration(milliseconds: 900),
      Duration(milliseconds: 1800),
    ];
    try {
      for (var attempt = 0; attempt < retryDelays.length; attempt++) {
        await Future<void>.delayed(retryDelays[attempt]);
        if (_battleRoom != room || generation != _battleConnectionGeneration) {
          return;
        }
        if (room.connectionState == ConnectionState.connected) {
          await _ensureRemoteTracksSubscribed(room);
          _setBattleState(LiveKitConnectionState.connected);
          return;
        }
        if (room.connectionState != ConnectionState.disconnected) return;
        try {
          debugPrint(
            '🔄 Battle LiveKit terminal reconnect '
            '${attempt + 1}/${retryDelays.length}: $roomName',
          );
          await _runWithLiveKitErrorGuard(
            () => room.connect(url, token, connectOptions: _connectOptions),
          );
          if (_battleRoom != room ||
              generation != _battleConnectionGeneration) {
            unawaited(_releaseRoom(room, label: 'stale battle'));
            return;
          }
          await _ensureRemoteTracksSubscribed(room);
          await _preferMediaSpeaker();
          debugPrint('🔗 Battle LiveKit media restored: $roomName');
          return;
        } catch (error) {
          debugPrint('Battle LiveKit reconnect attempt failed: $error');
        }
      }
    } finally {
      if (_battleRecoveryRoom == room) _battleRecoveryRoom = null;
    }
  }

  @override
  Future<void> connectBattle({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) {
    final generation = ++_battleConnectionGeneration;
    _setBattleState(LiveKitConnectionState.connecting);
    return _serializeBattleOperation(
      () => _connectBattle(
        url: url,
        token: token,
        roomName: roomName,
        mediaHints: mediaHints,
        generation: generation,
      ),
    );
  }

  Future<void> _connectBattle({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
    required int generation,
  }) async {
    await _retireBattleRoom();
    if (url.isEmpty || token.isEmpty) {
      throw StateError('Opponent LiveKit url/token missing');
    }
    final room = Room(roomOptions: _roomOptions);
    room.events
      ..on<RoomDisconnectedEvent>((event) {
        if (_battleRoom != room ||
            generation != _battleConnectionGeneration) {
          return;
        }
        _setBattleState(LiveKitConnectionState.disconnected);
        debugPrint(
          '🔴 Battle LiveKit terminal disconnect: $roomName '
          'reason=${event.reason?.name}',
        );
        if (_causeFor(event.reason).isRecoverable) {
          _queueBattleRecovery(
            room: room,
            url: url,
            token: token,
            roomName: roomName,
          );
        }
      })
      ..on<ReconnectingEvent>((_) {
        if (_battleRoom != room ||
            generation != _battleConnectionGeneration) {
          return;
        }
        _setBattleState(LiveKitConnectionState.reconnecting);
      })
      ..on<RoomReconnectedEvent>((_) {
        if (_battleRoom != room ||
            generation != _battleConnectionGeneration) {
          return;
        }
        _setBattleState(LiveKitConnectionState.connected);
        unawaited(_preferMediaSpeaker());
        unawaited(_ensureRemoteTracksSubscribed(room));
        _startBattleVideoWatchdog(
          room: room,
          url: url,
          token: token,
          roomName: roomName,
        );
      })
      ..on<TrackSubscribedEvent>((event) {
        if (_battleRoom != room ||
            generation != _battleConnectionGeneration) {
          return;
        }
        if (event.track is RemoteAudioTrack) unawaited(_preferMediaSpeaker());
      })
      ..on<TrackSubscriptionExceptionEvent>((event) {
        if (_battleRoom != room ||
            generation != _battleConnectionGeneration) {
          return;
        }
        unawaited(
          _retryRemoteSubscription(room, event, battleGeneration: generation),
        );
      });

    try {
      await _runWithLiveKitErrorGuard(
        () => room.connect(url, token, connectOptions: _connectOptions),
      );
      await _preferMediaSpeaker();
    } catch (_) {
      unawaited(_releaseRoom(room, label: 'failed battle'));
      rethrow;
    }

    if (generation != _battleConnectionGeneration) {
      unawaited(_releaseRoom(room, label: 'superseded battle'));
      return;
    }
    _battleRoom = room;
    await _ensureRemoteTracksSubscribed(room);
    final videoReady = await _waitForBattleVideo(room, generation: generation);
    debugPrint(
      videoReady
          ? 'Battle video subscribed before PK reveal: $roomName'
          : 'Battle video not published within preload window: $roomName',
    );
    if (generation != _battleConnectionGeneration) {
      await _retireBattleRoom();
      return;
    }
    _setBattleState(LiveKitConnectionState.connected);
    _startBattleVideoWatchdog(
      room: room,
      url: url,
      token: token,
      roomName: roomName,
    );
  }

  @override
  Future<void> disconnectBattle() {
    _battleConnectionGeneration++;
    if (_battleRoom != null) {
      _battleStateController.add(LiveKitConnectionState.disconnected);
    }
    return _serializeBattleOperation(_retireBattleRoom);
  }

  Future<void> _retireBattleRoom() async {
    _stopBattleVideoWatchdog();
    final room = _battleRoom;
    _battleRoom = null;
    if (room == null) return;
    final release = _releaseRoom(room, label: 'battle');
    if (_holdsAudioSession) {
      _trackBackgroundRelease(release);
      return;
    }
    await release;
  }

  void _setBattleState(LiveKitConnectionState next) {
    if (_battleStateController.isClosed) return;
    _battleStateController.add(next);
  }

  // ── Guest stage ───────────────────────────────────────────────────────────

  var _publishing = false;

  @override
  bool get isPublishing => _publishing;

  @override
  Future<void> prepareStage() => _ensureCapturePermissions();

  @override
  Future<void> joinStage({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {
    if (url.isEmpty || token.isEmpty) {
      throw StateError('Guest publish url/token missing');
    }

    // The viewer app is subscribe-only, so it has never asked for the camera
    // or the mic. Going on stage is the first moment it needs them, and
    // setCameraEnabled() on Android without CAMERA granted fails without ever
    // opening the lens — the guest joins and stays a black tile.
    await _ensureCapturePermissions();

    // A fresh connect, not an upgrade: the viewer's token carries no publish
    // grant, so the room has to be re-established with the one the server
    // issued on accept before the camera can go out.
    final hints = mediaHints ?? LiveMediaHints.defaultsForRole('guest');
    if (!hints.canPublish) {
      throw StateError('الخادم لم يمنح الضيف صلاحية نشر الكاميرا والمايك.');
    }
    await connect(
      url: url,
      token: token,
      roomName: roomName,
      mediaHints: hints,
    );

    final room = _room;
    if (room == null) {
      throw StateError('LiveKit room unavailable after joining the stage');
    }
    try {
      await _restoreStageTracks(room, hints);
      _publishing = true;
    } catch (e, st) {
      debugPrint('❌ Guest publish failed: $e\n$st');
      // Stay in the room as a viewer rather than dropping them out entirely.
      _publishing = false;
      rethrow;
    }
  }

  Future<void> _restoreStageTracks(Room room, LiveMediaHints hints) async {
    if (!identical(_room, room)) return;
    final local = room.localParticipant;
    if (local == null) {
      throw StateError('LiveKit local participant unavailable');
    }

    // Keep the existing audio source alive across mute/unmute and explicitly
    // use the refreshed role hints for the camera publication.
    await local.setMicrophoneEnabled(true);
    await local.setCameraEnabled(true);

    for (var attempt = 0; attempt < 10; attempt++) {
      if (!identical(_room, room)) return;
      if (_stagePublicationsReady(local)) {
        await _preferMediaSpeaker();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    // One controlled republish handles camera sources that were lost while
    // replacing the viewer token with the guest token.
    await local.setCameraEnabled(false);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await local.setCameraEnabled(true);
    for (var attempt = 0; attempt < 8; attempt++) {
      if (_stagePublicationsReady(local)) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final videoReady = local.videoTrackPublications.any(
      (publication) => !publication.muted && publication.track != null,
    );
    throw StateError(
      'لم يكتمل نشر ${!videoReady ? 'الكاميرا' : 'المايك'} للضيف.',
    );
  }

  static bool _stagePublicationsReady(LocalParticipant local) {
    final audioReady = local.audioTrackPublications.any(
      (publication) => !publication.muted && publication.track != null,
    );
    final videoReady = local.videoTrackPublications.any(
      (publication) => !publication.muted && publication.track != null,
    );
    return audioReady && videoReady;
  }

  /// Requests camera + mic, throwing a message the room can show verbatim.
  Future<void> _ensureCapturePermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    final camera = statuses[Permission.camera];
    final mic = statuses[Permission.microphone];

    if (camera != null && camera.isPermanentlyDenied) {
      throw StateError(
        'صلاحية الكاميرا مرفوضة نهائياً. فعّلها من إعدادات التطبيق للانضمام '
        'إلى المسرح.',
      );
    }
    if (camera == null || !camera.isGranted) {
      throw StateError('لا يمكن الانضمام إلى المسرح بدون صلاحية الكاميرا.');
    }
    if (mic == null || !mic.isGranted) {
      if (mic?.isPermanentlyDenied == true) {
        throw StateError(
          'صلاحية الميكروفون مرفوضة نهائياً. فعّلها من إعدادات التطبيق.',
        );
      }
      throw StateError('لا يمكن الانضمام إلى المسرح بدون صلاحية الميكروفون.');
    }
  }

  @override
  Future<void> leaveStage() async {
    final room = _room;
    _publishing = false;
    if (room == null) return;
    try {
      await room.localParticipant?.setCameraEnabled(false);
      await room.localParticipant?.setMicrophoneEnabled(false);
    } catch (e, st) {
      debugPrint('LiveKit leaveStage error: $e\n$st');
    }
  }

  @override
  Future<void> setStageMicrophoneEnabled(bool enabled) async {
    if (!_publishing) return;
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> setStageCameraEnabled(bool enabled) async {
    if (!_publishing) return;
    await _room?.localParticipant?.setCameraEnabled(enabled);
  }

  // ── Teardown ──────────────────────────────────────────────────────────────

  @override
  Future<void> disconnect() {
    final generation = ++_primaryGeneration;
    _trace?.mark('disconnect requested');
    _stopPrimaryVideoWatchdog();
    _emit(
      LiveKitConnectionState.disconnected,
      generation: generation,
      cause: LiveKitDisconnectCause.clientInitiated,
    );
    return _serializePrimary(() async {
      await _retireBattleRoom();
      // Ownership of the Android audio session goes back to LiveKit *before*
      // the last room closes, so the SDK's own automatic teardown is what
      // finally frees it (see LiveAudioSession).
      await _releaseAudioSession();
      await _retirePrimaryRoom();
      await _drainPendingReleases();
      _roomName = null;
      _url = null;
      _token = null;
      _mediaHints = null;
      _trace = null;
    });
  }

  @override
  Future<void> reconnect() async {
    final url = _url;
    final token = _token;
    final roomName = _roomName;
    final mediaHints = _mediaHints;
    final wasPublishing = _publishing;
    if (url == null || token == null || roomName == null) {
      _emit(
        LiveKitConnectionState.failed,
        generation: _primaryGeneration,
        cause: LiveKitDisconnectCause.unauthorized,
        detail: 'no stored credentials',
      );
      return;
    }
    try {
      if (wasPublishing) {
        await joinStage(
          url: url,
          token: token,
          roomName: roomName,
          mediaHints: mediaHints,
        );
        return;
      }
      await connect(
        url: url,
        token: token,
        roomName: roomName,
        mockStreamUrl: _streamUrl,
        mediaHints: mediaHints,
      );
    } catch (error) {
      debugPrint('LiveKit reconnect failed: $error');
    }
  }

  void dispose() {
    _stopPrimaryVideoWatchdog();
    _stopBattleVideoWatchdog();
    _sessionController.close();
    _battleStateController.close();
  }
}
