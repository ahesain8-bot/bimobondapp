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
        });

      await room.connect(url, token);
      _room = room;

      // Viewer: subscribe only — no local publish.
      // Request the MEDIUM quality layer first. adaptiveStream=true (set in
      // RoomOptions above) will allow the SFU to further adjust the quality
      // up or down based on viewport + network.  Requesting MEDIUM avoids
      // stuck-on-LOW while still giving the SFU headroom to step up to HIGH
      // when supported.
      Future<void>.delayed(const Duration(milliseconds: 400), () async {
        try {
          for (final participant in room.remoteParticipants.values) {
            for (final pub in participant.videoTrackPublications) {
              if (pub.subscribed) {
                await pub.setVideoQuality(VideoQuality.MEDIUM);
              }
            }
          }
        } catch (_) {}
      });

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
