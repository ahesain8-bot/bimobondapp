import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/services/live_video_quality_preference.dart';
import '../../domain/entities/live_capture_profile.dart';

/// Publishes / subscribes LiveKit A/V using **server-issued** `url` + `token` only.
///
/// Never mints JWTs or stores `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET`.
class LivesMediaDataSource {
  Room? _room;
  LocalVideoTrack? _videoTrack;
  LocalAudioTrack? _audioTrack;
  var _videoPublished = false;

  /// The profile the camera actually opened at — not the one we asked for.
  /// Publish options and camera flips both read this so the declared layers
  /// can never claim a resolution the sensor refused.
  var _activeProfile = LiveVideoQualityPreference.instance.profile;

  /// Callback invoked when the Room fires an event the host should know about
  /// (e.g. reconnection, disconnection, renegotiation failure).
  void Function(String tag, String message)? onRoomEvent;

  bool get isConnected =>
      _room != null && (_videoTrack != null || _audioTrack != null);

  bool get isVideoPublished => _videoPublished;

  Room? get room => _room;

  /// Local camera track for [VideoTrackRenderer] preview (host/guest).
  LocalVideoTrack? get localVideoTrack => _videoTrack;

  /// Capture request for [profile] on the given lens.
  CameraCaptureOptions _captureOptionsFor(
    LiveCaptureProfile profile,
    CameraPosition position,
  ) {
    return CameraCaptureOptions(
      cameraPosition: position,
      params: VideoParameters(
        dimensions: VideoDimensions(profile.width, profile.height),
        encoding: VideoEncoding(
          maxBitrate: profile.maxBitrate,
          maxFramerate: profile.maxFps,
        ),
      ),
    );
  }

  /// Simulcast ladder for [profile], highest layer first.
  ///
  /// Every tier at or below the capture profile is declared so the SFU always
  /// has a lower layer to hand a viewer on a weak connection, and the walk
  /// stops at 480p — nothing below that is ever published.
  List<VideoParameters> _simulcastLayersFor(LiveCaptureProfile profile) {
    return [
      for (final tier in profile.fallbacks)
        VideoParameters(
          dimensions: VideoDimensions(tier.width, tier.height),
          encoding: VideoEncoding(
            maxBitrate: tier.maxBitrate,
            maxFramerate: tier.maxFps,
          ),
        ),
    ];
  }

  VideoPublishOptions _publishOptionsFor(LiveCaptureProfile profile) {
    return VideoPublishOptions(
      simulcast: true,
      backupVideoCodec: const BackupVideoCodec(enabled: false),
      videoEncoding: VideoEncoding(
        maxBitrate: profile.maxBitrate,
        maxFramerate: profile.maxFps,
      ),
      videoSimulcastLayers: _simulcastLayersFor(profile),
    );
  }

  /// Host/guest: connect then publish camera + mic (production.md §3.4).
  Future<void> connectAndPublish({
    required String url,
    required String token,
    CameraPosition cameraPosition = CameraPosition.front,
    int maxAttempts = 6,
  }) async {
    await disconnect();

    // ── RoomOptions tuned for stable host publishing ──────────────────────
    // • dynacast FALSE: This is the CRITICAL setting. When dynacast is true,
    //   the SFU sends SubscribedQualityUpdate signals on every subscriber
    //   join/leave. The handler in room.dart processes `subscribedCodecs`
    //   which calls publishAdditionalCodecForPublication → engine.negotiate()
    //   → full SDP renegotiation. On Xiaomi's slow camera2 pipeline, if SDP
    //   munging fails → NegotiationError → fullReconnectOnNext → camera freeze.
    //   Setting dynacast:false makes room.dart:383 return early, blocking the
    //   entire subscribedCodecs path. NOTE: backupVideoCodec.enabled=false
    //   alone is NOT sufficient — publishAdditionalCodecForPublication does
    //   NOT check the enabled flag.
    // • backupVideoCodec DISABLED: defense in depth — prevents backup codec
    //   from being advertised in simulcastCodecs at publish time.
    // • adaptiveStream TRUE on the HOST (paired with viewer-side TRUE): the
    //   SFU can pick the appropriate simulcast layer per subscriber viewport.
    // • fastPublish KEPT TRUE (default): reduces initial publish latency.
    // • videoEncoding / videoSimulcastLayers: built from
    //   LiveCaptureProfile.ladder so the base layer is 1080p@30fps 4.5Mbps —
    //   the tier TikTok LIVE publishes from a capable handset. The previous
    //   720p cap was the single biggest reason our streams read as softer
    //   than theirs on a modern phone. Layers descend 1080p → 720p → 480p and
    //   stop there (480p MINIMUM PER M2 PRODUCT REQUIREMENT — never publish
    //   below 854×480, so no 360p/180p can appear anywhere in the pipeline).
    //   Rid ordering in LiveKit 2.11.0 utils.dart sorts presets by area
    //   ascending, so declaring them highest-first here is safe: the SDK
    //   re-sorts before assigning 'q'/'h'/'f'.
    //   Explicit sizing prevents LiveKit SDK auto-defaults from picking
    //   overly conservative mid/low bitrates on some Android build targets.
    //   These are room DEFAULTS only; publishVideoTrack below passes the
    //   profile the camera actually accepted.
    final room = Room(
      roomOptions: RoomOptions(
        adaptiveStream: true,
        dynacast: false,
        defaultVideoPublishOptions: _publishOptionsFor(
          LiveVideoQualityPreference.instance.profile,
        ),
      ),
    );

    // ── Room event listeners for connection health ─────────────────────────
    room.events
      ..on<RoomDisconnectedEvent>((event) {
        debugPrint(
          '🔴 [Host] LiveKit room disconnected — reason=${event.reason}',
        );
        onRoomEvent?.call('room', 'disconnected:${event.reason}');
      })
      ..on<ReconnectingEvent>((event) {
        debugPrint('🔄 [Host] LiveKit reconnecting…');
        onRoomEvent?.call('room', 'reconnecting');
      })
      ..on<RoomReconnectedEvent>((event) {
        debugPrint('🟢 [Host] LiveKit reconnected');
        onRoomEvent?.call('room', 'reconnected');
      })
      ..on<RoomConnectedEvent>((event) {
        debugPrint('🟢 [Host] LiveKit connected');
      })
      ..on<ParticipantConnectedEvent>((event) {
        debugPrint(
          '👤 [Host] Participant joined: ${event.participant.identity}',
        );
        onRoomEvent?.call(
          'room',
          'participant_joined:${event.participant.identity}',
        );
      });

    debugPrint('🔍 [Host] connectAndPublish: connecting to room...');
    await room.connect(url, token);
    _room = room;
    debugPrint(
      '🔍 [Host] connectAndPublish: room connected, name=${room.name}',
    );

    Object? audioError;
    Object? videoError;

    try {
      debugPrint('🔍 [Host] connectAndPublish: creating audio track...');
      _audioTrack = await LocalAudioTrack.create();
      debugPrint('🔍 [Host] connectAndPublish: publishing audio track...');
      await room.localParticipant?.publishAudioTrack(_audioTrack!);
      debugPrint('🔍 [Host] connectAndPublish: audio published OK');
    } catch (e, st) {
      audioError = e;
      debugPrint('🔴 [Host] LiveKit audio publish failed: $e\n$st');
    }

    try {
      Object? lastError;
      final ladder = LiveVideoQualityPreference.instance.profile.fallbacks;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        // Two passes per profile: the retry budget the Xiaomi camera2
        // pipeline needed is kept, but a sensor that refuses the host's
        // ceiling now steps down a tier instead of being asked the same
        // resolution six times.
        final profile = ladder[(attempt ~/ 2).clamp(0, ladder.length - 1)];
        try {
          debugPrint(
            '🔍 [Host] connectAndPublish: '
            'createCameraTrack attempt ${attempt + 1}/6 at ${profile.label}...',
          );
          _videoTrack = await LocalVideoTrack.createCameraTrack(
            _captureOptionsFor(profile, cameraPosition),
          );
          _activeProfile = profile;
          _videoPublished = false;
          lastError = null;
          debugPrint(
            '🔍 [Host] connectAndPublish: '
            'camera track created on attempt ${attempt + 1} '
            'at ${profile.label}',
          );

          // ============================================================
          // [DEBUG-QOS HOST 1/4] Actual CAPTURE runtime diagnostics.
          // Do NOT trust the params we passed: inspect the values the
          // camera hardware + LiveKit engine actually accepted.
          // Reads correct 2.11.0 getters only (LocalVideoTrack.currentOptions
          // → VideoCaptureOptions.params → VideoParameters.dimensions/encoding).
          // ============================================================
          try {
            final t = _videoTrack!;
            final opts = t
                .currentOptions; // VideoCaptureOptions (2.11.0 correct name, not .options)
            final params =
                opts.params; // VideoParameters (dimensions + encoding)
            final dims = params.dimensions;
            final enc = params.encoding;
            final capW = dims.width;
            final capH = dims.height;
            final capFps = enc?.maxFramerate ?? opts.maxFrameRate ?? 30;
            final capBr = enc?.maxBitrate ?? 2500000;
            debugPrint(
              '[DEBUG-QOS] HOST-CAPTURE:'
              '  position=${cameraPosition.name}'
              '  dimensions(WxH)=${capW}x$capH'
              '  requestedFps=$capFps'
              '  requestedBitrate=${(capBr / 1000).toStringAsFixed(0)}kbps'
              '  track.sid=${t.sid}'
              '  captureMaxFrameRate_opt=${opts.maxFrameRate}'
              '  (W>H => landscape; H>W => portrait).',
            );
          } catch (e) {
            debugPrint('[DEBUG-QOS] HOST-CAPTURE (read failed): $e');
          }

          break;
        } catch (e, st) {
          lastError = e;
          debugPrint(
            '🔴 [Host] LiveKit camera open attempt ${attempt + 1} '
            'failed: $e\n$st',
          );
          // No backoff after the final try: the caller is about to act on
          // the failure, and sleeping first only delays that.
          if (attempt < maxAttempts - 1) {
            await Future<void>.delayed(
              Duration(milliseconds: 500 * (attempt + 1)),
            );
          }
        }
      }
      if (_videoTrack == null) {
        throw StateError('LiveKit camera open failed: $lastError');
      }
      // Pass EXPLICIT VideoPublishOptions — L284 of SDK 2.11.0 local_participant:
      //   publishOptions ??= track.lastPublishOptions ?? room.roomOptions.defaults.
      // By passing explicitly we guarantee the layers are declared at publish
      // time regardless of any future room-default override path. The ladder
      // is derived from the profile the camera actually opened at, so we never
      // advertise a layer the sensor refused, and it always bottoms out at
      // 854×480 (M2 requirement: never publish below 480p).
      await room.localParticipant?.publishVideoTrack(
        _videoTrack!,
        publishOptions: _publishOptionsFor(_activeProfile),
      );
      _videoPublished = true;
      debugPrint('🔍 [Host] connectAndPublish: video published OK ✅');

      // ============================================================
      // [DEBUG-QOS HOST 2/4] Actual PUBLISHED simulcast layers.
      // Prove what the SFU sees — if HIGH layer is missing here,
      // the viewer CAN NEVER RECEIVE 720p no matter what viewer does.
      // Uses correct 2.11.0 API only:
      //   TrackPublication.mimeType (direct String getter, no .codec wrapper)
      //   LocalVideoTrack.lastPublishOptions.videoSimulcastLayers
      //   LocalVideoTrack.simulcastCodecs.entries (RIDs + encodings)
      //   TrackPublication.dimensions (server reported W×H from TrackInfo)
      // ============================================================
      try {
        final pubs = room.localParticipant?.videoTrackPublications ?? [];
        for (final p in pubs) {
          final lvTrack = p.track as LocalVideoTrack?;
          final sim = p.simulcasted;
          final mime = p.mimeType; // 2.11.0 direct getter (no .codec wrapper)
          final trackCodec = lvTrack?.codec; // LocalTrack.codec String
          final pubDim = p.dimensions; // server-reported dimensions

          // Published layer definitions (what we declared + SDK accepted):
          final simLayers = lvTrack?.lastPublishOptions?.videoSimulcastLayers;

          // Actual active RIDs:
          final scEntries = lvTrack?.simulcastCodecs.entries.toList() ?? [];

          debugPrint(
            '[DEBUG-QOS] HOST-PUBLISH:'
            '  sid=${p.sid}'
            '  trackId=${p.track?.mediaStreamTrack.id}'
            '  simulcasted=$sim'
            '  mime=$mime'
            '  trackCodec=$trackCodec'
            '  pubDimensions=${pubDim?.width}x${pubDim?.height}'
            '  declaredSimLayers=${simLayers == null ? "null" : simLayers.map((l) => "${l.dimensions.width}x${l.dimensions.height}@${l.encoding?.maxFramerate}fps/${l.encoding == null ? "?" : "${(l.encoding!.maxBitrate ~/ 1000)}kbps"}").toList()}'
            '  scCount=${scEntries.length}'
            '  scRIDs=${scEntries.map((e) => "${e.key}(${e.value.codec})").toList()}'
            '  encodings_per_rid=${scEntries.map((e) => "rid:${e.key} enc=${e.value.encodings?.map((en) => "rid:${en.rid ?? "f"} on:${en.active} scale:${en.scaleResolutionDownBy ?? 1.0} fps:${en.maxFramerate ?? "?"} br:${en.maxBitrate ?? "?"}").toList()}").toList()}',
          );

          if (simLayers == null || simLayers.isEmpty) {
            // Fallback: SDK stored no explicit layers (or not yet set).
            final roomOpts = room.roomOptions.defaultVideoPublishOptions;
            debugPrint(
              '[DEBUG-QOS] HOST-PUBLISH (fallback-room-publish-opts):'
              '  videoCodec=${roomOpts.videoCodec}'
              '  simulcast=${roomOpts.simulcast}'
              '  br=${roomOpts.videoEncoding?.maxBitrate}'
              '  fps=${roomOpts.videoEncoding?.maxFramerate}'
              '  simlayers.count=${roomOpts.videoSimulcastLayers.length}'
              '  layers=${roomOpts.videoSimulcastLayers.map((l) => "${l.dimensions.width}x${l.dimensions.height}@${l.encoding?.maxFramerate}").toList()}',
            );
          }
        }
      } catch (e) {
        debugPrint('[DEBUG-QOS] HOST-PUBLISH (err): $e');
      }
    } catch (e, st) {
      videoError = e;
      debugPrint('🔴 [Host] LiveKit video publish failed: $e\n$st');
    }

    debugPrint(
      '🔍 [Host] connectAndPublish: '
      '_videoPublished=$_videoPublished, '
      'videoError=$videoError, audioError=$audioError',
    );

    if (!_videoPublished) {
      debugPrint(
        '🔴 [Host] connectAndPublish: video NOT published → disconnect + throw',
      );
      await disconnect();
      throw StateError(
        'LiveKit video publish failed'
        '${videoError != null ? ': $videoError' : ''}'
        '${audioError != null ? ' (audio: $audioError)' : ''}',
      );
    }
    debugPrint(
      '🟢 [Host] connectAndPublish: SUCCESS — room + video + audio all up',
    );
  }

  /// Viewer: connect and subscribe only (no publish).
  Future<void> connectAndSubscribe({
    required String url,
    required String token,
  }) async {
    await disconnect();
    // Aligned viewer options: adaptiveStream TRUE (so SFU can pick the right
    // simulcast layer per viewer viewport and network), dynacast FALSE to
    // avoid renegotiation storms, backup codec disabled (same as publisher).
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: false,
        defaultVideoPublishOptions: VideoPublishOptions(
          backupVideoCodec: BackupVideoCodec(enabled: false),
        ),
      ),
    );
    await room.connect(url, token);
    _room = room;
    // Subscribe-only: mark connected without local publish.
    _videoPublished = false;
  }

  /// Whether the LiveKit room is connected (including viewer subscribe-only).
  bool get isRoomConnected => _room != null;

  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    await _room?.localParticipant?.setCameraEnabled(enabled);
  }

  /// Flip between front/back by restarting the camera capturer when possible.
  Future<LocalVideoTrack?> flipCamera({required bool useFront}) async {
    final room = _room;
    final old = _videoTrack;
    if (room == null || old == null || !_videoPublished) return _videoTrack;

    final position = useFront ? CameraPosition.front : CameraPosition.back;
    // Flip at whatever the session is already running — dropping back to a
    // fixed 720p here would silently downgrade a 1080p stream mid-broadcast.
    final options = _captureOptionsFor(_activeProfile, position);

    try {
      // Fast path: restart the existing published track in place.
      await old.restartTrack(options);
      return old;
    } catch (e, st) {
      debugPrint('LiveKit restartTrack flip failed, republishing: $e\n$st');
    }

    final sid = old.sid;
    try {
      if (sid != null) {
        await room.localParticipant?.removePublishedTrack(sid);
      }
    } catch (e, st) {
      debugPrint('LiveKit unpublish before flip failed: $e\n$st');
    }
    try {
      await old.stop();
    } catch (_) {}
    _videoTrack = null;
    _videoPublished = false;

    final next = await LocalVideoTrack.createCameraTrack(options);
    await room.localParticipant?.publishVideoTrack(
      next,
      publishOptions: _publishOptionsFor(_activeProfile),
    );
    _videoTrack = next;
    _videoPublished = true;
    return next;
  }

  Future<void> disconnect() async {
    debugPrint(
      '🔍 [Host] disconnect() called — _room=${_room != null ? "SET" : "NULL"}, '
      '_videoTrack=${_videoTrack != null ? "SET" : "NULL"}, '
      '_audioTrack=${_audioTrack != null ? "SET" : "NULL"}',
    );
    try {
      // Fully release the native camera/audio sources. stop() alone can leave
      // flutter_webrtc's capturer cached ("camera already active ... reusing
      // VideoSource") which breaks the NEXT live with a dead video source.
      await _videoTrack?.dispose();
      _videoTrack = null;
      await _audioTrack?.dispose();
      _audioTrack = null;
      await _room?.disconnect();
      await _room?.dispose();
      _room = null;
    } catch (e, st) {
      debugPrint('LiveKit disconnect error: $e\n$st');
    } finally {
      _videoTrack = null;
      _audioTrack = null;
      _room = null;
      _videoPublished = false;
    }
  }
}
