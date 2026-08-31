import 'dart:async';
import 'dart:math' as math;

import 'package:bimobondapp/app/ar_camera/ar_camera_live_track.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/services/live_audio_session.dart';
import '../../../../core/services/live_beauty_preference.dart';
import '../../../../core/services/media_progress_watchdog.dart';
import '../../../../core/services/live_video_quality_preference.dart';
import '../../../../core/models/live_media_hints.dart';
import '../../domain/entities/live_capture_profile.dart';

/// Publishes / subscribes LiveKit A/V using **server-issued** `url` + `token` only.
///
/// Never mints JWTs or stores `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET`.
/// How often the room health watchdogs sample media counters.
const Duration _kMediaHealthTick = Duration(seconds: 2);

class LivesMediaDataSource {
  Room? _room;
  Room? _battleRoom;
  Room? _battleRecoveryRoom;
  Future<void> _battleOperationQueue = Future<void>.value();
  var _battleConnectionGeneration = 0;

  /// Whether this datasource currently holds [LiveAudioSession]. Keeps the
  /// acquire/release pair balanced no matter which connect path ran.
  var _holdsAudioSession = false;
  LocalVideoTrack? _videoTrack;
  LocalAudioTrack? _audioTrack;
  var _videoPublished = false;
  var _arCameraTrackActive = false;
  Timer? _videoHealthTimer;
  var _videoHealthCheckInFlight = false;
  // 3 samples at 2s: about six seconds of a stream that decodes no frames
  // while signalling still says the room is up. Long enough that ordinary
  // rebuffering is not mistaken for a stall, short enough that the host is not
  // broadcasting a frozen picture for a quarter of a minute.
  final _videoProgress = MediaProgressWatchdog(stalledSampleLimit: 3);
  Timer? _battleVideoHealthTimer;
  var _battleVideoHealthCheckInFlight = false;
  // The opponent room is secondary and crosses another host's uplink, so it
  // gets a longer rope before its room is rebuilt.
  final _battleVideoProgress = MediaProgressWatchdog(stalledSampleLimit: 5);

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

  /// Subscribe-only room for the other host during a PK battle.
  Room? get battleRoom => _battleRoom;

  bool get isBattleRoomUsable =>
      _battleRoom != null &&
      _battleRoom!.connectionState != ConnectionState.disconnected;

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
  List<VideoParameters> _simulcastLayersFor(
    LiveCaptureProfile profile, {
    bool portrait = false,
  }) {
    return [
      for (final tier in profile.fallbacks)
        VideoParameters(
          dimensions: VideoDimensions(
            portrait ? tier.height : tier.width,
            portrait ? tier.width : tier.height,
          ),
          encoding: VideoEncoding(
            maxBitrate: tier == profile
                ? profile.maxBitrate
                : math.min(tier.maxBitrate, profile.maxBitrate),
            maxFramerate: tier.maxFps,
          ),
        ),
    ];
  }

  VideoPublishOptions _publishOptionsFor(
    LiveCaptureProfile profile, {
    bool portrait = false,
  }) {
    return VideoPublishOptions(
      // This is the proven stable Android publishing path used before the
      // regression: one codec negotiation with fixed simulcast layers.
      simulcast: true,
      backupVideoCodec: const BackupVideoCodec(enabled: false),
      videoEncoding: VideoEncoding(
        maxBitrate: profile.maxBitrate,
        maxFramerate: profile.maxFps,
      ),
      videoSimulcastLayers: _simulcastLayersFor(profile, portrait: portrait),
    );
  }

  LiveCaptureProfile _profileForHints(LiveMediaHints hints) {
    final preferred = LiveVideoQualityPreference.instance.profile;
    final server = switch (hints.maxVideoResolution.toLowerCase()) {
      '1080p' => LiveCaptureProfile.fullHd,
      '720p' => LiveCaptureProfile.hd,
      _ => LiveCaptureProfile.sd,
    };
    final preferredIndex = LiveCaptureProfile.ladder.indexOf(preferred);
    final serverIndex = LiveCaptureProfile.ladder.indexOf(server);
    final base =
        LiveCaptureProfile.ladder[math.max(preferredIndex, serverIndex)];
    final bitrate = hints.maxBitrateKbps > 0
        ? math.min(base.maxBitrate, hints.maxBitrateKbps * 1000)
        : base.maxBitrate;
    return LiveCaptureProfile(
      width: base.width,
      height: base.height,
      maxFps: base.maxFps,
      maxBitrate: bitrate,
      preset: base.preset,
      label: base.label,
    );
  }

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

  Future<T> _serializeBattleOperation<T>(Future<T> Function() operation) {
    final previous = _battleOperationQueue;
    final result = previous.then((_) => operation());
    // A failed reconnect must not prevent a later battle-end/disconnect from
    // running, while the original caller still receives its error.
    _battleOperationQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  void _queueBattleRecovery({
    required Room room,
    required String url,
    required String token,
  }) {
    final generation = _battleConnectionGeneration;
    unawaited(
      _serializeBattleOperation(() async {
        await _recoverBattleRoom(
          room: room,
          url: url,
          token: token,
          generation: generation,
        );
        if (generation == _battleConnectionGeneration &&
            _battleRoom == room &&
            room.connectionState == ConnectionState.disconnected) {
          onRoomEvent?.call('battle', 'failed');
        }
      }),
    );
  }

  Future<void> _preferMediaSpeaker() async {
    try {
      // TikTok-style live rooms are media playback, not private calls. Keep
      // Bluetooth/wired devices first, otherwise route to the loudspeaker.
      await AudioManager.instance.setSpeakerOutputPreferred(true, force: false);
    } catch (error) {
      debugPrint('Live audio route selection failed: $error');
    }
  }

  /// Waits briefly for proof that the camera is producing outbound frames.
  ///
  /// A successful `publishVideoTrack` only proves signalling succeeded. On
  /// some Android Camera2 devices the capture session fails asynchronously,
  /// so the publication exists but its counters remain at zero forever.
  Future<bool> _waitForOutboundVideo(
    LocalVideoTrack track, {
    Duration timeout = const Duration(milliseconds: 2200),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var sawFrameCounter = false;
    var sawAnyStats = false;
    num lastFrames = 0;
    num lastPackets = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 275));
      try {
        final stats = await track.getSenderStats();
        if (stats.isEmpty) continue;
        sawAnyStats = true;
        lastFrames = 0;
        lastPackets = 0;
        for (final layer in stats) {
          if (layer.framesSent != null) sawFrameCounter = true;
          lastFrames += layer.framesSent ?? 0;
          lastPackets += layer.packetsSent ?? 0;
        }
        if (lastFrames > 0) return true;
        // Some platforms do not expose framesSent. Packets are the best
        // available proof there and must not turn into a false failure.
        if (!sawFrameCounter && lastPackets > 0) return true;
      } catch (error) {
        debugPrint('[Host] outbound video stats unavailable: $error');
      }
    }

    debugPrint(
      '🔴 [Host] no outbound camera frames '
      '(stats=$sawAnyStats frames=$lastFrames packets=$lastPackets)',
    );
    return false;
  }

  void _startOutboundVideoWatchdog(Room room, LocalVideoTrack track) {
    _stopOutboundVideoWatchdog();
    _videoProgress.reset();
    _videoHealthTimer = Timer.periodic(_kMediaHealthTick, (_) {
      if (_videoHealthCheckInFlight ||
          _room != room ||
          _videoTrack != track ||
          !_videoPublished) {
        return;
      }
      _videoHealthCheckInFlight = true;
      unawaited(
        _sampleOutboundVideo(room, track).whenComplete(() {
          _videoHealthCheckInFlight = false;
        }),
      );
    });
  }

  Future<void> _sampleOutboundVideo(Room room, LocalVideoTrack track) async {
    try {
      // A host who turned their camera off stops sending frames on purpose.
      // Without this the watchdog read that as a stall and forced a full
      // reconnect, which republished the camera the host had just closed.
      if (track.muted || room.localParticipant?.isCameraEnabled() == false) {
        _videoProgress.reset();
        return;
      }
      final stats = await track.getSenderStats();
      if (_room != room || _videoTrack != track || stats.isEmpty) return;
      num frames = 0;
      num packets = 0;
      var hasFrameCounter = false;
      var hasPacketCounter = false;
      for (final layer in stats) {
        final sentFrames = layer.framesSent;
        final sentPackets = layer.packetsSent;
        if (sentFrames != null) {
          hasFrameCounter = true;
          frames += sentFrames;
        }
        if (sentPackets != null) {
          hasPacketCounter = true;
          packets += sentPackets;
        }
      }
      final progress = hasFrameCounter
          ? frames
          : (hasPacketCounter ? packets : null);
      if (!_videoProgress.addSample(progress)) return;

      debugPrint(
        '🔴 [Host] outbound video stopped advancing while room remained connected',
      );
      _stopOutboundVideoWatchdog();
      onRoomEvent?.call('room', 'disconnected:outbound_video_stalled');
    } catch (error) {
      // Stats support is platform-dependent. An unavailable sample is not a
      // disconnect and must not interrupt a healthy broadcast.
      debugPrint('[Host] outbound health sample unavailable: $error');
    }
  }

  void _stopOutboundVideoWatchdog() {
    _videoHealthTimer?.cancel();
    _videoHealthTimer = null;
    _videoProgress.reset();
  }

  /// Host/guest: connect then publish camera + mic (production.md §3.4).
  Future<void> connectAndPublish({
    required String url,
    required String token,
    CameraPosition cameraPosition = CameraPosition.front,
    int maxAttempts = 3,
    Future<void> Function()? beforeVideoCapture,
    LiveMediaHints? mediaHints,
  }) async {
    // Keep an in-progress PK subscribe up. PK is overlay + scores on the
    // same `live_{id}` publish; tearing the opponent room down here is what
    // made hosts leave their own room for 10s+ while recovering a token.
    await disconnect(keepBattleRoom: true);

    final hints = mediaHints ?? LiveMediaHints.defaultsForRole('host');
    if (!hints.canPublish) {
      throw StateError('The server did not grant media publishing permission');
    }
    // Ask the hardware what it can sustain before choosing a tier. Only ever
    // raises the ceiling above 720p, and only on a device that passes.
    await LiveVideoQualityPreference.instance.resolveDeviceDefault();
    final requestedProfile = _profileForHints(hints);

    // ── RoomOptions tuned for stable host publishing ──────────────────────
    // • dynacast stays FALSE. Enabling it made subscriber changes trigger
    //   extra codec/SDP negotiation on Android; a failed negotiation left the
    //   host preview running locally while viewers received no camera track.
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
        defaultAudioCaptureOptions: const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          voiceIsolation: true,
          stopAudioCaptureOnMute: false,
        ),
        defaultAudioPublishOptions: const AudioPublishOptions(
          dtx: true,
          red: true,
        ),
        defaultVideoPublishOptions: _publishOptionsFor(requestedProfile),
      ),
    );

    // ── Room event listeners for connection health ─────────────────────────
    room.events
      ..on<RoomDisconnectedEvent>((event) {
        if (_room != room) return;
        debugPrint(
          '🔴 [Host] LiveKit room disconnected — reason=${event.reason}',
        );
        onRoomEvent?.call('room', 'disconnected:${event.reason}');
      })
      ..on<ReconnectingEvent>((event) {
        if (_room != room) return;
        debugPrint('🔄 [Host] LiveKit reconnecting…');
        onRoomEvent?.call('room', 'reconnecting');
      })
      ..on<RoomReconnectedEvent>((event) {
        if (_room != room) return;
        debugPrint('🟢 [Host] LiveKit reconnected');
        onRoomEvent?.call('room', 'reconnected');
      })
      ..on<RoomConnectedEvent>((event) {
        if (_room != room) return;
        debugPrint('🟢 [Host] LiveKit connected');
      })
      ..on<ParticipantConnectedEvent>((event) {
        if (_room != room) return;
        debugPrint(
          '👤 [Host] Participant joined: ${event.participant.identity}',
        );
        onRoomEvent?.call(
          'room',
          'participant_joined:${event.participant.identity}',
        );
      })
      ..on<TrackSubscribedEvent>((event) {
        if (_room != room) return;
        if (event.track is RemoteAudioTrack) {
          unawaited(_preferMediaSpeaker());
        }
      });

    debugPrint('🔍 [Host] connectAndPublish: connecting to room...');
    // Own the Android audio session for the whole broadcast: the PK battle
    // room disconnecting would otherwise tear it down for this room too.
    try {
      await _acquireAudioSession();
    } catch (_) {
      try {
        await room.dispose();
      } catch (disposeError, disposeStack) {
        debugPrint(
          '🔴 [Host] failed to dispose room after audio-session failure: '
          '$disposeError\n$disposeStack',
        );
      }
      rethrow;
    }
    _room = room;
    try {
      await room.connect(url, token);
    } catch (_) {
      if (_room == room) _room = null;
      await _releaseAudioSession();
      try {
        await room.dispose();
      } catch (_) {}
      rethrow;
    }
    debugPrint(
      '🔍 [Host] connectAndPublish: room connected, name=${room.name}',
    );
    await _preferMediaSpeaker();

    Object? audioError;
    Object? videoError;

    for (var attempt = 1; attempt <= 3 && _audioTrack == null; attempt++) {
      LocalAudioTrack? candidate;
      try {
        debugPrint(
          '🔍 [Host] connectAndPublish: creating audio track '
          'attempt $attempt/3...',
        );
        candidate = await LocalAudioTrack.create(
          const AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
            voiceIsolation: true,
            stopAudioCaptureOnMute: false,
          ),
        );
        final local = room.localParticipant;
        if (local == null) {
          throw StateError('LiveKit local participant unavailable');
        }
        await local.publishAudioTrack(
          candidate,
          publishOptions: const AudioPublishOptions(dtx: true, red: true),
        );
        _audioTrack = candidate;
        audioError = null;
        debugPrint('🔍 [Host] connectAndPublish: audio published OK');
      } catch (e, st) {
        audioError = e;
        debugPrint(
          '🔴 [Host] LiveKit audio publish attempt $attempt failed: $e\n$st',
        );
        try {
          await candidate?.dispose();
        } catch (_) {}
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 180 * attempt));
        }
      }
    }

    // Room signalling and microphone setup do not need the camera, so keep the
    // Flutter preview alive through those potentially slow operations. Release
    // it exactly here, immediately before WebRTC asks Camera2 for the lens.
    // This avoids both a long black gap and the two-capturer race that froze
    // the first several seconds on Android.
    try {
      await beforeVideoCapture?.call();
    } catch (e, st) {
      debugPrint('🔴 [Host] camera handoff failed: $e\n$st');
      await disconnect();
      rethrow;
    }

    try {
      Object? lastError;
      final useExistingArCamera = await ArCameraLiveTrack.isAvailable();
      final fallbacks = requestedProfile.fallbacks;
      final ladder = <LiveCaptureProfile>[
        requestedProfile,
        ...fallbacks.skip(1),
      ];
      // The AR renderer is one stable source, so a retry here is not the
      // Camera2 "reopen the lens at a lower preset" dance — the lens stays
      // open and only the size of the output surface it draws into changes.
      // That is cheap, and it is the difference between a handset that cannot
      // sustain 1080p going live at 720p and it not going live at all. The
      // failure path below already detaches the track and waits before the
      // next attempt, so the walk is safe on this path too.
      final attemptCount = maxAttempts.clamp(1, ladder.length);
      final local = room.localParticipant;
      if (local == null) {
        throw StateError('LiveKit local participant unavailable');
      }

      for (var attempt = 0; attempt < attemptCount; attempt++) {
        final profile = ladder[attempt];
        LocalVideoTrack? candidate;
        String? publicationSid;
        try {
          debugPrint(
            '🔍 [Host] connectAndPublish: '
            'camera/publish attempt ${attempt + 1}/$attemptCount '
            'at ${profile.label}...',
          );
          if (useExistingArCamera) {
            candidate = await ArCameraLiveTrack.create(
              width: profile.height,
              height: profile.width,
              fps: profile.maxFps,
              maxBitrate: profile.maxBitrate,
              cameraPosition: cameraPosition,
            );
          } else {
            candidate = await LocalVideoTrack.createCameraTrack(
              _captureOptionsFor(profile, cameraPosition),
            );
            await LiveBeautyPreference.instance.attachTo(
              candidate.mediaStreamTrack.id,
            );
          }

          final opts = candidate.currentOptions;
          final params = opts.params;
          final dims = params.dimensions;
          final enc = params.encoding;
          debugPrint(
            '[DEBUG-QOS] HOST-CAPTURE:'
            '  position=${cameraPosition.name}'
            '  dimensions(WxH)=${dims.width}x${dims.height}'
            '  requestedFps=${enc?.maxFramerate ?? opts.maxFrameRate ?? 30}'
            '  requestedBitrate='
            '${((enc?.maxBitrate ?? 2500000) / 1000).toStringAsFixed(0)}kbps'
            '  track.sid=${candidate.sid}',
          );

          final publication = await local.publishVideoTrack(
            candidate,
            publishOptions: _publishOptionsFor(
              profile,
              portrait: useExistingArCamera,
            ),
          );
          publicationSid = publication.sid;

          // Camera2 can report success and fail its capture-session setup a
          // few milliseconds later. Do not replace the visible camera with a
          // LiveKit texture until RTC proves that real frames are leaving the
          // handset. This specifically prevents "published but black" lives.
          final hasFrames = await _waitForOutboundVideo(
            candidate,
            // The native Kotlin renderer has to create one additional shared
            // EGL output surface on first publish. A slow device/emulator can
            // present its first valid frame after ~3 seconds; the old 2.2s
            // Camera2-oriented guard detached that healthy track immediately.
            timeout: useExistingArCamera
                ? const Duration(seconds: 8)
                : const Duration(milliseconds: 2200),
          );
          if (!hasFrames) {
            throw StateError(
              'camera opened at ${profile.label} but produced no video frames',
            );
          }

          _videoTrack = candidate;
          _arCameraTrackActive = useExistingArCamera;
          _activeProfile = profile;
          _videoPublished = true;
          lastError = null;
          debugPrint(
            '🔍 [Host] connectAndPublish: video frames verified '
            'at ${profile.label} ✅',
          );
          break;
        } catch (e, st) {
          lastError = e;
          _videoTrack = null;
          _videoPublished = false;
          debugPrint(
            '🔴 [Host] LiveKit video attempt ${attempt + 1} '
            'failed: $e\n$st',
          );
          if (publicationSid != null) {
            try {
              await local.removePublishedTrack(publicationSid);
            } catch (_) {}
          }
          try {
            await candidate?.dispose();
          } catch (_) {}
          if (useExistingArCamera) {
            await ArCameraLiveTrack.detach();
            _arCameraTrackActive = false;
          }
          if (attempt < attemptCount - 1) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
        }
      }
      if (_videoTrack == null || !_videoPublished) {
        throw StateError('LiveKit camera publish failed: $lastError');
      }

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
          final lvTrack = p.track;
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

    if (!_videoPublished || _audioTrack == null) {
      debugPrint(
        '🔴 [Host] connectAndPublish: video NOT published → disconnect + throw',
      );
      await disconnect();
      throw StateError(
        'LiveKit audio/video publish failed'
        '${videoError != null ? ': $videoError' : ''}'
        '${audioError != null ? ' (audio: $audioError)' : ''}',
      );
    }
    debugPrint(
      '🟢 [Host] connectAndPublish: SUCCESS — room + video + audio all up',
    );
    _startOutboundVideoWatchdog(room, _videoTrack!);
  }

  /// Viewer: connect and subscribe only (no publish).
  Future<void> connectAndSubscribe({
    required String url,
    required String token,
    LiveMediaHints? mediaHints,
  }) async {
    await disconnect();
    // Keep viewer negotiation on the stable subscribe-only profile. In
    // particular dynacast must not be enabled by a generic server default.
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: false,
        defaultVideoPublishOptions: VideoPublishOptions(
          backupVideoCodec: BackupVideoCodec(enabled: false),
        ),
      ),
    );
    try {
      await _acquireAudioSession();
    } catch (_) {
      try {
        await room.dispose();
      } catch (disposeError, disposeStack) {
        debugPrint(
          '🔴 [Host] failed to dispose subscribe room after audio-session '
          'failure: $disposeError\n$disposeStack',
        );
      }
      rethrow;
    }
    try {
      await room.connect(url, token);
    } catch (_) {
      await _releaseAudioSession();
      rethrow;
    }
    _room = room;
    await _preferMediaSpeaker();
    // Subscribe-only: mark connected without local publish.
    _videoPublished = false;
  }

  /// Whether the LiveKit room is connected (including viewer subscribe-only).
  bool get isRoomConnected => _room != null;

  /// Joins the opponent's separate LiveKit room without touching the host's
  /// publishing room.
  Future<void> connectBattleAndSubscribe({
    required String url,
    required String token,
    LiveMediaHints? mediaHints,
  }) {
    final generation = ++_battleConnectionGeneration;
    return _serializeBattleOperation(
      () => _connectBattleAndSubscribe(
        url: url,
        token: token,
        mediaHints: mediaHints,
        generation: generation,
      ),
    );
  }

  Future<void> _connectBattleAndSubscribe({
    required String url,
    required String token,
    LiveMediaHints? mediaHints,
    required int generation,
  }) async {
    await _disconnectBattle();
    if (url.isEmpty || token.isEmpty) {
      throw StateError('Opponent LiveKit url/token missing');
    }
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: false,
        defaultVideoPublishOptions: VideoPublishOptions(
          backupVideoCodec: BackupVideoCodec(enabled: false),
        ),
      ),
    );
    room.events
      ..on<RoomDisconnectedEvent>((_) {
        if (_battleRoom != room || generation != _battleConnectionGeneration) {
          return;
        }
        debugPrint('🔴 [Host] opponent battle room disconnected');
        onRoomEvent?.call('battle', 'disconnected');
        _queueBattleRecovery(room: room, url: url, token: token);
      })
      ..on<ReconnectingEvent>((_) {
        if (_battleRoom != room || generation != _battleConnectionGeneration) {
          return;
        }
        onRoomEvent?.call('battle', 'reconnecting');
      })
      ..on<RoomReconnectedEvent>((_) {
        if (_battleRoom != room || generation != _battleConnectionGeneration) {
          return;
        }
        onRoomEvent?.call('battle', 'reconnected');
        unawaited(_ensureBattleSubscriptions(room));
        unawaited(_preferMediaSpeaker());
        _startBattleVideoWatchdog(room: room, url: url, token: token);
      })
      ..on<TrackSubscriptionExceptionEvent>((event) {
        if (generation != _battleConnectionGeneration) return;
        unawaited(_retryBattleSubscription(room, event, generation));
      })
      ..on<TrackSubscribedEvent>((event) {
        if (_battleRoom != room || generation != _battleConnectionGeneration) {
          return;
        }
        if (event.track is RemoteAudioTrack) {
          unawaited(_preferMediaSpeaker());
        }
      });
    await room.connect(url, token);
    if (generation != _battleConnectionGeneration) {
      try {
        await room.disconnect();
        await room.dispose();
      } catch (error, stackTrace) {
        debugPrint(
          '[Host] stale opponent battle room cleanup failed: '
          '$error\n$stackTrace',
        );
      }
      return;
    }
    _battleRoom = room;
    await _ensureBattleSubscriptions(room);
    if (generation != _battleConnectionGeneration) {
      await _disconnectBattle();
      return;
    }
    await _preferMediaSpeaker();
    if (generation != _battleConnectionGeneration) {
      await _disconnectBattle();
      return;
    }
    _startBattleVideoWatchdog(room: room, url: url, token: token);
  }

  Future<void> _retryBattleSubscription(
    Room room,
    TrackSubscriptionExceptionEvent event,
    int generation,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (_battleRoom != room || generation != _battleConnectionGeneration) {
      return;
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
      debugPrint('[Host] opponent track resubscribe failed: $error');
    }
  }

  Future<void> _ensureBattleSubscriptions(Room room) async {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.trackPublications.values) {
        if (publication.subscribed) continue;
        try {
          await publication.subscribe();
        } catch (error) {
          debugPrint('[Host] opponent track restore failed: $error');
        }
      }
    }
  }

  RemoteVideoTrack? _firstBattleVideoTrack(Room room) {
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

  void _startBattleVideoWatchdog({
    required Room room,
    required String url,
    required String token,
  }) {
    _stopBattleVideoWatchdog();
    _battleVideoProgress.reset();
    _battleVideoHealthTimer = Timer.periodic(_kMediaHealthTick, (_) {
      if (_battleVideoHealthCheckInFlight || _battleRoom != room) return;
      _battleVideoHealthCheckInFlight = true;
      unawaited(
        _sampleBattleVideo(room: room, url: url, token: token).whenComplete(() {
          _battleVideoHealthCheckInFlight = false;
        }),
      );
    });
  }

  Future<void> _sampleBattleVideo({
    required Room room,
    required String url,
    required String token,
  }) async {
    final generation = _battleConnectionGeneration;
    try {
      final track = _firstBattleVideoTrack(room);
      if (_battleRoom != room || generation != _battleConnectionGeneration) {
        return;
      }
      if (track == null) {
        await _ensureBattleSubscriptions(room);
        if (!_battleVideoProgress.addMissingTrackSample()) return;
      } else {
        final stats = await track.getReceiverStats();
        final progress =
            stats?.framesDecoded ??
            stats?.framesReceived ??
            stats?.packetsReceived ??
            stats?.bytesReceived;
        if (_battleRoom != room ||
            generation != _battleConnectionGeneration ||
            !_battleVideoProgress.addSample(progress)) {
          return;
        }
      }

      debugPrint(
        '🔴 [Host] opponent video stalled while battle room stayed up',
      );
      _stopBattleVideoWatchdog();
      await _serializeBattleOperation(() async {
        if (_battleRoom != room || generation != _battleConnectionGeneration) {
          return;
        }
        await room.disconnect();
        if (_battleRoom == room && generation == _battleConnectionGeneration) {
          _queueBattleRecovery(room: room, url: url, token: token);
        }
      });
    } catch (error) {
      debugPrint('[Host] opponent video health sample unavailable: $error');
    }
  }

  void _stopBattleVideoWatchdog() {
    _battleVideoHealthTimer?.cancel();
    _battleVideoHealthTimer = null;
    _battleVideoProgress.reset();
  }

  Future<void> _recoverBattleRoom({
    required Room room,
    required String url,
    required String token,
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
          await _ensureBattleSubscriptions(room);
          return;
        }
        if (room.connectionState != ConnectionState.disconnected) return;
        try {
          debugPrint(
            '🔄 [Host] opponent terminal reconnect '
            '${attempt + 1}/${retryDelays.length}',
          );
          await room.connect(url, token);
          if (_battleRoom != room ||
              generation != _battleConnectionGeneration) {
            await room.disconnect();
            return;
          }
          await _ensureBattleSubscriptions(room);
          await _preferMediaSpeaker();
          _startBattleVideoWatchdog(room: room, url: url, token: token);
          onRoomEvent?.call('battle', 'reconnected');
          return;
        } catch (error) {
          debugPrint('[Host] opponent reconnect attempt failed: $error');
        }
      }
    } finally {
      if (_battleRecoveryRoom == room) _battleRecoveryRoom = null;
    }
  }

  Future<void> disconnectBattle() {
    _battleConnectionGeneration++;
    return _serializeBattleOperation(_disconnectBattle);
  }

  Future<void> _disconnectBattle() async {
    _stopBattleVideoWatchdog();
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

  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    await _room?.localParticipant?.setCameraEnabled(enabled);
  }

  /// Flip between front/back by restarting the camera capturer when possible.
  Future<LocalVideoTrack?> flipCamera({required bool useFront}) async {
    // Android live uses the existing Kotlin AR preview as its sole source.
    // The host flips that preview through ArCameraBridge; opening a LiveKit
    // CameraX capturer here would compete for the same physical camera.
    if (_arCameraTrackActive) return _videoTrack;
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

    final local = room.localParticipant;
    if (local == null) {
      throw StateError('LiveKit local participant unavailable');
    }

    // The old track is already unpublished and stopped by this point, so a
    // failure here leaves the host broadcasting a black frame — which reads as
    // the live having dropped. Android in particular refuses to open the
    // camera for a moment after the previous capturer is released, so retry
    // the flip and then fall back to the side we came from: staying on the
    // original camera is always better than going dark mid-broadcast.
    Future<LocalVideoTrack?> publishAt(CameraPosition at) async {
      LocalVideoTrack? track;
      try {
        track = await LocalVideoTrack.createCameraTrack(
          _captureOptionsFor(_activeProfile, at),
        );
        await LiveBeautyPreference.instance.attachTo(track.mediaStreamTrack.id);
        await local.publishVideoTrack(
          track,
          publishOptions: _publishOptionsFor(_activeProfile),
        );
        _videoTrack = track;
        _videoPublished = true;
        _startOutboundVideoWatchdog(room, track);
        return track;
      } catch (e, st) {
        debugPrint('LiveKit camera publish at $at failed: $e\n$st');
        try {
          await track?.dispose();
        } catch (_) {}
        return null;
      }
    }

    final flipped =
        await publishAt(position) ??
        await Future<LocalVideoTrack?>.delayed(
          const Duration(milliseconds: 350),
          () => publishAt(position),
        );
    if (flipped != null) return flipped;

    final fallbackPosition = useFront
        ? CameraPosition.back
        : CameraPosition.front;
    final recovered = await publishAt(fallbackPosition);
    if (recovered != null) {
      throw StateError(
        'Camera flip failed; kept broadcasting on the previous camera',
      );
    }
    throw StateError('LiveKit camera flip failed and could not be recovered');
  }

  Future<void> disconnect({bool keepBattleRoom = false}) async {
    debugPrint(
      '🔍 [Host] disconnect() called — _room=${_room != null ? "SET" : "NULL"}, '
      '_videoTrack=${_videoTrack != null ? "SET" : "NULL"}, '
      '_audioTrack=${_audioTrack != null ? "SET" : "NULL"}',
    );
    _stopOutboundVideoWatchdog();
    if (!_arCameraTrackActive) {
      // Non-Android fallback only. Android publishes the already-rendered
      // Kotlin AR frame and does not install this second processor.
      await LiveBeautyPreference.instance.detach();
    }
    if (!keepBattleRoom) {
      await disconnectBattle();
    }
    // Back to LiveKit's automatic management *before* the primary room goes
    // down, so that room's own teardown is what finally frees the session.
    // Note the ordering against disconnectBattle() above: the battle room is
    // closed while we still own the session, which is the whole point.
    await _releaseAudioSession();
    final room = _room;
    // Detach ownership first: RoomDisconnectedEvent emitted by this deliberate
    // teardown must not start the host recovery loop.
    _room = null;
    try {
      // Fully release the native camera/audio sources. stop() alone can leave
      // flutter_webrtc's capturer cached ("camera already active ... reusing
      // VideoSource") which breaks the NEXT live with a dead video source.
      await _videoTrack?.dispose();
      _videoTrack = null;
      if (_arCameraTrackActive) {
        await ArCameraLiveTrack.detach();
        _arCameraTrackActive = false;
      }
      await _audioTrack?.dispose();
      _audioTrack = null;
      await room?.disconnect();
      await room?.dispose();
    } catch (e, st) {
      debugPrint('LiveKit disconnect error: $e\n$st');
    } finally {
      _videoTrack = null;
      _audioTrack = null;
      _room = null;
      _videoPublished = false;
      if (_arCameraTrackActive) {
        await ArCameraLiveTrack.detach();
        _arCameraTrackActive = false;
      }
    }
  }
}
