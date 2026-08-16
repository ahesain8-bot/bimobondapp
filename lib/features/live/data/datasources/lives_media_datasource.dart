import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Publishes / subscribes LiveKit A/V using **server-issued** `url` + `token` only.
///
/// Never mints JWTs or stores `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET`.
class LivesMediaDataSource {
  Room? _room;
  LocalVideoTrack? _videoTrack;
  LocalAudioTrack? _audioTrack;
  var _videoPublished = false;

  /// Callback invoked when the Room fires an event the host should know about
  /// (e.g. reconnection, disconnection, renegotiation failure).
  void Function(String tag, String message)? onRoomEvent;

  bool get isConnected =>
      _room != null && (_videoTrack != null || _audioTrack != null);

  bool get isVideoPublished => _videoPublished;

  Room? get room => _room;

  /// Local camera track for [VideoTrackRenderer] preview (host/guest).
  LocalVideoTrack? get localVideoTrack => _videoTrack;

  /// Host/guest: connect then publish camera + mic (production.md §3.4).
  Future<void> connectAndPublish({
    required String url,
    required String token,
    CameraPosition cameraPosition = CameraPosition.front,
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
    // • videoEncoding: explicit 720p@25fps 1.6Mbps target for mobile portrait
    //   + VGA@20 700kbps mid layer + QVGA@15 300kbps low layer for simulcast.
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: false,
        defaultVideoPublishOptions: VideoPublishOptions(
          simulcast: true,
          backupVideoCodec: BackupVideoCodec(enabled: false),
          videoEncoding: VideoEncoding(
            maxBitrate: 1600000,
            maxFramerate: 25,
          ),
        ),
      ),
    );

    // ── Room event listeners for connection health ─────────────────────────
    room.events
      ..on<RoomDisconnectedEvent>((event) {
        debugPrint('🔴 [Host] LiveKit room disconnected — reason=${event.reason}');
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
    debugPrint('🔍 [Host] connectAndPublish: room connected, name=${room.name}');

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
      for (var attempt = 0; attempt < 6; attempt++) {
        try {
          debugPrint(
            '🔍 [Host] connectAndPublish: '
            'createCameraTrack attempt ${attempt + 1}/6...',
          );
          _videoTrack = await LocalVideoTrack.createCameraTrack(
            CameraCaptureOptions(
              cameraPosition: cameraPosition,
              params: const VideoParameters(
                dimensions: VideoDimensionsPresets.h720_169,
                encoding: VideoEncoding(
                  maxBitrate: 1600000,
                  maxFramerate: 25,
                ),
              ),
            ),
          );
          _videoPublished = false;
          lastError = null;
          debugPrint(
            '🔍 [Host] connectAndPublish: '
            'camera track created on attempt ${attempt + 1}',
          );
          break;
        } catch (e, st) {
          lastError = e;
          debugPrint(
            '🔴 [Host] LiveKit camera open attempt ${attempt + 1} '
            'failed: $e\n$st',
          );
          await Future<void>.delayed(
            Duration(milliseconds: 500 * (attempt + 1)),
          );
        }
      }
      if (_videoTrack == null) {
        throw StateError('LiveKit camera open failed: $lastError');
      }
      debugPrint('🔍 [Host] connectAndPublish: publishing video track...');
      await room.localParticipant?.publishVideoTrack(_videoTrack!);
      _videoPublished = true;
      debugPrint('🔍 [Host] connectAndPublish: video published OK ✅');
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
      debugPrint('🔴 [Host] connectAndPublish: video NOT published → disconnect + throw');
      await disconnect();
      throw StateError(
        'LiveKit video publish failed'
        '${videoError != null ? ': $videoError' : ''}'
        '${audioError != null ? ' (audio: $audioError)' : ''}',
      );
    }
    debugPrint('🟢 [Host] connectAndPublish: SUCCESS — room + video + audio all up');
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

    final position =
        useFront ? CameraPosition.front : CameraPosition.back;
    const params = VideoParameters(
      dimensions: VideoDimensionsPresets.h720_169,
      encoding: VideoEncoding(
        maxBitrate: 1600000,
        maxFramerate: 25,
      ),
    );

    try {
      // Fast path: restart the existing published track in place.
      await old.restartTrack(
        CameraCaptureOptions(
          cameraPosition: position,
          params: params,
        ),
      );
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

    final next = await LocalVideoTrack.createCameraTrack(
      CameraCaptureOptions(
        cameraPosition: position,
        params: params,
      ),
    );
    await room.localParticipant?.publishVideoTrack(next);
    _videoTrack = next;
    _videoPublished = true;
    return next;
  }

  Future<void> disconnect() async {
    debugPrint('🔍 [Host] disconnect() called — _room=${_room != null ? "SET" : "NULL"}, '
        '_videoTrack=${_videoTrack != null ? "SET" : "NULL"}, '
        '_audioTrack=${_audioTrack != null ? "SET" : "NULL"}');
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
