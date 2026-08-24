import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import 'fake_livekit_service.dart' show LiveKitConnectionState, LiveKitService;

/// Real LiveKit implementation of [LiveKitService] using `livekit_client`.
///
/// The viewer connects **subscribe-only** — never publishes camera/mic.
/// `url` + `token` must come from `POST /lives/:id/join` (mobile-api.md §15).
/// Token TTL ≈ 6h — reconnect means re-joining to refresh the token.
class RealLiveKitService implements LiveKitService {
  final _stateController = StreamController<LiveKitConnectionState>.broadcast();

  LiveKitConnectionState _state = LiveKitConnectionState.disconnected;
  String? _roomName;
  String? _streamUrl;
  String? _url;
  String? _token;
  Room? _room;
  Room? _battleRoom;

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
  Stream<LiveKitConnectionState> get stateStream => _stateController.stream;

  @override
  String? get roomName => _roomName;

  @override
  String? get streamUrl => _streamUrl;

  /// The underlying LiveKit room — exposed for future `LiveKitVideoView`
  /// rendering of subscribed remote tracks.
  @override
  Room? get room => _room;

  @override
  Room? get battleRoom => _battleRoom;

  @override
  Future<void> connectBattle({
    required String url,
    required String token,
    required String roomName,
  }) async {
    await disconnectBattle();
    if (url.isEmpty || token.isEmpty) {
      throw StateError('Opponent LiveKit url/token missing');
    }
    final room = await _runWithLiveKitErrorGuard(() async {
      final guardedRoom = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: false,
          defaultVideoPublishOptions: VideoPublishOptions(
            backupVideoCodec: BackupVideoCodec(enabled: false),
          ),
        ),
      );
      guardedRoom.events
        ..on<ReconnectingEvent>((_) {
          debugPrint('🔄 Battle LiveKit reconnecting: $roomName');
        })
        ..on<RoomReconnectedEvent>((_) {
          debugPrint('🔗 Battle LiveKit reconnected: $roomName');
        });
      await guardedRoom.connect(url, token);
      return guardedRoom;
    });
    _battleRoom = room;
  }

  @override
  Future<void> disconnectBattle() async {
    final room = _battleRoom;
    _battleRoom = null;
    if (room == null) return;
    try {
      await room.disconnect();
      await room.dispose();
    } catch (e, st) {
      debugPrint('Battle LiveKit disconnect error: $e\n$st');
    }
  }

  void _setState(LiveKitConnectionState next) {
    _state = next;
    _stateController.add(next);
  }

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
    String? mockStreamUrl,
  }) async {
    await disconnect();

    if (url.isEmpty || token.isEmpty) {
      _setState(LiveKitConnectionState.failed);
      throw StateError('LiveKit url/token missing — re-join the live');
    }

    _url = url;
    _token = token;
    _roomName = roomName;
    _setState(LiveKitConnectionState.connecting);

    try {
      await _runWithLiveKitErrorGuard(() async {
        final room = Room(
          roomOptions: const RoomOptions(
            // Let LiveKit select the highest layer that the current viewport and
            // network can sustain. Disabling this left viewers on the publisher's
            // initial/default layer and made quality unnecessarily low or unstable.
            adaptiveStream: true,
            dynacast: false,
            defaultVideoPublishOptions: VideoPublishOptions(
              backupVideoCodec: BackupVideoCodec(enabled: false),
            ),
          ),
        );
        // Own the room before connect() starts emitting lifecycle callbacks.
        // Every listener below checks identity so a late disconnect from the
        // room we just replaced cannot mark the new room disconnected.
        _room = room;
        room.events
          ..on<RoomDisconnectedEvent>((event) {
            if (_room != room) return;
            debugPrint('🔴 LiveKit room disconnected: $roomName');
            _setState(LiveKitConnectionState.disconnected);
          })
          ..on<ReconnectingEvent>((event) {
            if (_room != room) return;
            debugPrint('🔄 LiveKit reconnecting: $roomName');
            _setState(LiveKitConnectionState.reconnecting);
          })
          ..on<RoomReconnectedEvent>((event) {
            if (_room != room) return;
            debugPrint('🔗 LiveKit reconnected: $roomName');
            _setState(LiveKitConnectionState.connected);
          })
          ..on<RoomConnectedEvent>((event) {
            if (_room != room) return;
            debugPrint('🔌 LiveKit connected: $roomName');
            _setState(LiveKitConnectionState.connected);
          })
          // [DEBUG-QOS VIEWER 1/3] Remote track subscribed: print what
          // simulcast layers the remote publication actually advertises,
          // which codec is in use, and — critically — what VideoQuality
          // the viewer is currently scheduled to receive BEFORE any UI
          // touches it.  This line isolates whether adaptiveStream has
          // already picked the wrong layer before the widget tree builds.
          // NOTE: For 2.11.0, remote tracks do NOT expose `options.encodings`;
          // instead we read: publication.dimensions (from server TrackInfo),
          // publication.mimeType (direct String getter, no .codec wrapper),
          // and publication.videoQuality getter which returns the user's
          // explicit setVideoQuality preference (or HIGH if unset — note
          // this is NOT the SFU's actual forwarding decision, which is why
          // the LiveVideoPlayer renderer also probes via getReceiverStats).
          ..on<TrackSubscribedEvent>((ev) {
            if (ev.track is! RemoteVideoTrack) return;
            final p = ev.publication;
            final part = ev.participant;
            final vtrack = ev.track as RemoteVideoTrack;
            final pub = p; // RemoteTrackPublication
            final dims = pub.dimensions; // server-reported published dims
            final mime = pub.mimeType; // 2.11.0 direct getter
            final qualityPref = pub.videoQuality.name.toUpperCase();
            // Remote tracks don't expose encodings list; actual decoder dims
            // are queried via getReceiverStats() in the LiveVideoPlayer renderer
            // probe block (VIEWER-RENDERER DEBUG-QOS).
            debugPrint(
              '[DEBUG-QOS] VIEWER-TRACK-SUBSCRIBED:'
              '  room=$roomName'
              '  hostId=${part.identity}'
              '  trackSid=${vtrack.sid}'
              '  pubSid=${pub.sid}'
              '  simulcasted=${pub.simulcasted}'
              '  mime=$mime'
              '  pubDimensions=${dims?.width}x${dims?.height}'
              '  videoQualityGetter(preference)=$qualityPref'
              '  (NOTE: decoder-output dims queried separately in VIEWER-RENDERER probe via getReceiverStats())',
            );
          })
          // [DEBUG-QOS VIEWER 2/3] TrackStreamStateUpdatedEvent fires when the
          // SFU pauses the track due to bandwidth limits or resumes it.
          // (Replaces non-existent RemoteVideoTrackEvent listener that would
          // have caused compile error on livekit_client <2.13.)
          ..on<TrackStreamStateUpdatedEvent>((ev) {
            try {
              final p = ev.publication;
              debugPrint(
                '[DEBUG-QOS] VIEWER-TRACK-STREAM-STATE:'
                '  streamState=${ev.streamState.name.toUpperCase()}'
                '  pubSid=${p.sid}'
                '  videoQuality(preference)=${p.videoQuality.name.toUpperCase()}'
                '  simulcasted=${p.simulcasted}',
              );
            } catch (_) {}
          });

        await room.connect(url, token);
      });
      // Viewer: subscribe only — no local publish.
      //
      // NOTE: We intentionally do NOT call setVideoQuality() here anymore.
      // Previously `setVideoQuality(VideoQuality.MEDIUM)` was hard-capped on
      // every remote subscribed publication after 400 ms — this forced the
      // SFU to serve the 360p (mid) simulcast layer even on good Wi-Fi and
      // when the renderer is full-screen, causing heavy upscaling blur on
      // all viewer devices.  RoomOptions.adaptiveStream = true (configured
      // above) tells the engine to request the appropriate layer based on
      // the actual VideoTrackRenderer viewport dimensions (full-screen →
      // HIGH / 720p automatically) and the current available downlink.
      // This yields the same or better quality as an explicit HIGH request,
      // but still falls back cleanly on weak networks — no manual toggle
      // required and no artificial cap on good links.
      _streamUrl = mockStreamUrl;
      _setState(LiveKitConnectionState.connected);
    } catch (e, st) {
      debugPrint('❌ LiveKit connect failed: $e\n$st');
      final failedRoom = _room;
      _room = null;
      try {
        await failedRoom?.dispose();
      } catch (_) {}
      _setState(LiveKitConnectionState.failed);
      rethrow;
    }
  }

  var _publishing = false;

  @override
  bool get isPublishing => _publishing;

  @override
  Future<void> joinStage({
    required String url,
    required String token,
    required String roomName,
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
    await connect(url: url, token: token, roomName: roomName);

    final room = _room;
    if (room == null) {
      throw StateError('LiveKit room unavailable after joining the stage');
    }
    try {
      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);
      _publishing = true;
    } catch (e, st) {
      debugPrint('❌ Guest publish failed: $e\n$st');
      // Stay in the room as a viewer rather than dropping them out entirely.
      _publishing = false;
      rethrow;
    }
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
    // A muted guest is still a guest, so the mic is not a hard requirement.
    if (mic == null || !mic.isGranted) {
      debugPrint('⚠️ Joining the stage without microphone permission');
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

  @override
  Future<void> disconnect() async {
    await disconnectBattle();
    _publishing = false;
    _setState(LiveKitConnectionState.disconnected);
    final room = _room;
    _room = null;
    _streamUrl = null;
    _roomName = null;
    _url = null;
    _token = null;
    if (room != null) {
      try {
        await room.disconnect();
        await room.dispose();
      } catch (e, st) {
        debugPrint('LiveKit disconnect error: $e\n$st');
      }
    }
  }

  @override
  Future<void> reconnect() async {
    final url = _url;
    final token = _token;
    final roomName = _roomName;
    if (url == null || token == null || roomName == null) {
      _setState(LiveKitConnectionState.failed);
      return;
    }
    _setState(LiveKitConnectionState.reconnecting);
    try {
      await connect(
        url: url,
        token: token,
        roomName: roomName,
        mockStreamUrl: _streamUrl,
      );
    } catch (e) {
      debugPrint('LiveKit reconnect failed: $e');
      _setState(LiveKitConnectionState.failed);
    }
  }

  void dispose() {
    _stateController.close();
  }
}
