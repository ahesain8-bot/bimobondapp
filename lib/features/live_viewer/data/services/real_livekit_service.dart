import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import 'fake_livekit_service.dart' show LiveKitConnectionState, LiveKitService;

/// Real LiveKit implementation of [LiveKitService] using `livekit_client`.
///
/// The viewer connects **subscribe-only** — never publishes camera/mic.
/// `url` + `token` must come from `POST /lives/:id/join` (mobile-api.md §15).
/// Token TTL ≈ 6h — reconnect means re-joining to refresh the token.
class RealLiveKitService implements LiveKitService {
  final _stateController =
      StreamController<LiveKitConnectionState>.broadcast();

  LiveKitConnectionState _state = LiveKitConnectionState.disconnected;
  String? _roomName;
  String? _streamUrl;
  String? _url;
  String? _token;
  Room? _room;

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
  Room? get room => _room;

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
      room.events
        ..on<RoomDisconnectedEvent>((event) {
          debugPrint('🔴 LiveKit room disconnected: $roomName');
          _setState(LiveKitConnectionState.disconnected);
        })
        ..on<ReconnectingEvent>((event) {
          debugPrint('🔄 LiveKit reconnecting: $roomName');
          _setState(LiveKitConnectionState.reconnecting);
        })
        ..on<RoomReconnectedEvent>((event) {
          debugPrint('🔗 LiveKit reconnected: $roomName');
          _setState(LiveKitConnectionState.connected);
        })
        ..on<RoomConnectedEvent>((event) {
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
      _room = room;

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
      _room = null;
      _setState(LiveKitConnectionState.failed);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
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
