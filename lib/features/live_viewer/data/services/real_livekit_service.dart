import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/models/live_media_hints.dart';
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
  LiveMediaHints? _mediaHints;
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

  @override
  LiveMediaHints? get mediaHints => _mediaHints;

  /// The underlying LiveKit room — exposed for future `LiveKitVideoView`
  /// rendering of subscribed remote tracks.
  @override
  Room? get room => _room;

  @override
  Room? get battleRoom => _battleRoom;

  Future<void> _preferMediaSpeaker() async {
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(true, force: false);
    } catch (error) {
      debugPrint('Live audio route selection failed: $error');
    }
  }

  CameraCaptureOptions _cameraOptions(LiveMediaHints hints) {
    final dimensions = switch (hints.maxVideoResolution.toLowerCase()) {
      '1080p' => const VideoDimensions(1920, 1080),
      '720p' => const VideoDimensions(1280, 720),
      '360p' => const VideoDimensions(640, 360),
      _ => const VideoDimensions(854, 480),
    };
    return CameraCaptureOptions(
      cameraPosition: CameraPosition.front,
      params: VideoParameters(
        dimensions: dimensions,
        encoding: VideoEncoding(
          maxBitrate: hints.maxBitrateKbps.clamp(800, 4500) * 1000,
          maxFramerate: 30,
        ),
      ),
    );
  }

  VideoPublishOptions _videoPublishOptions(LiveMediaHints hints) {
    final capture = _cameraOptions(hints).params;
    return VideoPublishOptions(
      videoCodec: hints.preferredCodec,
      simulcast: hints.simulcast,
      backupVideoCodec: const BackupVideoCodec(enabled: false),
      videoEncoding: capture.encoding,
      videoSimulcastLayers: hints.simulcast
          ? _simulcastLayers(hints, capture)
          : const [],
      degradationPreference: DegradationPreference.maintainFramerate,
    );
  }

  List<VideoParameters> _simulcastLayers(
    LiveMediaHints hints,
    VideoParameters capture,
  ) {
    final ceiling = hints.maxBitrateKbps.clamp(800, 4500) * 1000;
    final layers = <VideoParameters>[capture];

    void addLayer(int width, int height, int bitrate) {
      if (capture.dimensions.width <= width) return;
      layers.add(
        VideoParameters(
          dimensions: VideoDimensions(width, height),
          encoding: VideoEncoding(
            maxBitrate: bitrate.clamp(300000, ceiling),
            maxFramerate: 30,
          ),
        ),
      );
    }

    addLayer(1280, 720, 2500000);
    addLayer(854, 480, 1200000);
    addLayer(640, 360, 650000);
    return layers;
  }

  RoomOptions _roomOptions(LiveMediaHints hints) => RoomOptions(
    adaptiveStream: hints.adaptiveStream,
    dynacast: hints.dynacast,
    defaultCameraCaptureOptions: _cameraOptions(hints),
    defaultAudioCaptureOptions: const AudioCaptureOptions(
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
      voiceIsolation: true,
      stopAudioCaptureOnMute: false,
    ),
    defaultAudioPublishOptions: const AudioPublishOptions(dtx: true, red: true),
    defaultVideoPublishOptions: _videoPublishOptions(hints),
  );

  Future<void> _retryRemoteSubscription(
    Room room,
    TrackSubscriptionExceptionEvent event,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (_room != room && _battleRoom != room) return;
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

  @override
  Future<void> connectBattle({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {
    await disconnectBattle();
    if (url.isEmpty || token.isEmpty) {
      throw StateError('Opponent LiveKit url/token missing');
    }
    final room = await _runWithLiveKitErrorGuard(() async {
      final hints = mediaHints ?? LiveMediaHints.defaultsForRole('viewer');
      final guardedRoom = Room(roomOptions: _roomOptions(hints));
      guardedRoom.events
        ..on<ReconnectingEvent>((_) {
          debugPrint('🔄 Battle LiveKit reconnecting: $roomName');
        })
        ..on<RoomReconnectedEvent>((_) {
          debugPrint('🔗 Battle LiveKit reconnected: $roomName');
          unawaited(_preferMediaSpeaker());
        })
        ..on<TrackSubscribedEvent>((event) {
          if (event.track is RemoteAudioTrack) {
            unawaited(_preferMediaSpeaker());
          }
        })
        ..on<TrackSubscriptionExceptionEvent>((event) {
          unawaited(_retryRemoteSubscription(guardedRoom, event));
        });
      await guardedRoom.connect(url, token);
      await _preferMediaSpeaker();
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
    LiveMediaHints? mediaHints,
  }) async {
    await disconnect();

    if (url.isEmpty || token.isEmpty) {
      _setState(LiveKitConnectionState.failed);
      throw StateError('LiveKit url/token missing — re-join the live');
    }

    _url = url;
    _token = token;
    _mediaHints = mediaHints ?? LiveMediaHints.defaultsForRole('viewer');
    _roomName = roomName;
    _setState(LiveKitConnectionState.connecting);

    try {
      await _runWithLiveKitErrorGuard(() async {
        final hints = _mediaHints!;
        final room = Room(roomOptions: _roomOptions(hints));
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
            unawaited(_preferMediaSpeaker());
            if (_publishing) {
              unawaited(_restoreStageTracks(room, hints));
            }
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
            if (ev.track is RemoteAudioTrack) {
              unawaited(_preferMediaSpeaker());
            }
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
          ..on<TrackSubscriptionExceptionEvent>((event) {
            unawaited(_retryRemoteSubscription(room, event));
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
        await _preferMediaSpeaker();
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
    if (_room != room) return;
    final local = room.localParticipant;
    if (local == null) {
      throw StateError('LiveKit local participant unavailable');
    }

    // Keep the existing audio source alive across mute/unmute and explicitly
    // use the refreshed role hints for the camera publication.
    await local.setMicrophoneEnabled(true);
    await local.setCameraEnabled(true);

    for (var attempt = 0; attempt < 10; attempt++) {
      if (_room != room) return;
      final audioReady = local.audioTrackPublications.any(
        (publication) => !publication.muted && publication.track != null,
      );
      final videoReady = local.videoTrackPublications.any(
        (publication) => !publication.muted && publication.track != null,
      );
      if (audioReady && videoReady) {
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
    var audioReady = false;
    var videoReady = false;
    for (var attempt = 0; attempt < 8; attempt++) {
      audioReady = local.audioTrackPublications.any(
        (publication) => !publication.muted && publication.track != null,
      );
      videoReady = local.videoTrackPublications.any(
        (publication) => !publication.muted && publication.track != null,
      );
      if (audioReady && videoReady) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!audioReady || !videoReady) {
      throw StateError(
        'لم يكتمل نشر ${!videoReady ? 'الكاميرا' : 'المايك'} للضيف.',
      );
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
    _mediaHints = null;
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
    final mediaHints = _mediaHints;
    final wasPublishing = _publishing;
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
        mediaHints: mediaHints,
      );
      if (wasPublishing) {
        final room = _room;
        if (room == null) {
          throw StateError('LiveKit room unavailable after reconnect');
        }
        final hints = mediaHints ?? LiveMediaHints.defaultsForRole('guest');
        await _restoreStageTracks(room, hints);
        _publishing = true;
      }
    } catch (e) {
      debugPrint('LiveKit reconnect failed: $e');
      _setState(LiveKitConnectionState.failed);
    }
  }

  void dispose() {
    _stateController.close();
  }
}
