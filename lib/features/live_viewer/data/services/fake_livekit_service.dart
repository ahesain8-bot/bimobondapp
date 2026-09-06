import 'dart:async';

import 'package:livekit_client/livekit_client.dart' show Room;
import '../../../../core/models/live_media_hints.dart';

/// Connection states mirroring a LiveKit room lifecycle.
enum LiveKitConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Abstraction over LiveKit so the UI never talks to the SDK directly.
abstract class LiveKitService {
  LiveKitConnectionState get state;
  Stream<LiveKitConnectionState> get stateStream;
  Stream<LiveKitConnectionState> get battleStateStream =>
      const Stream<LiveKitConnectionState>.empty();
  String? get roomName;
  String? get streamUrl;
  LiveMediaHints? get mediaHints => null;

  /// The underlying LiveKit [Room] once connected (used to render remote
  /// video tracks), or null while disconnected. Fakes return null.
  Room? get room => null;

  /// Separate subscribe-only room for the other host in a PK battle.
  Room? get battleRoom => null;

  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
    String? mockStreamUrl,
    LiveMediaHints? mediaHints,
    /// When recovering the primary room mid-PK, keep the opponent room.
    bool keepBattleRoom = false,
  });

  Future<void> disconnect();
  Future<void> reconnect();

  Future<void> connectBattle({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {}

  Future<void> disconnectBattle() async {}

  /// Whether this device is publishing camera/mic into the room right now.
  bool get isPublishing => false;

  /// Requests camera/microphone before a seat request is sent so accepting the
  /// request can publish immediately instead of waiting on a system dialog.
  Future<void> prepareStage() async {}

  /// Re-joins the room with the publish credentials the server issued when the
  /// guest was accepted, then turns the camera and mic on. Subscribe-only
  /// tokens cannot publish, so this always reconnects rather than upgrading
  /// the existing connection in place.
  Future<void> joinStage({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {
    throw UnsupportedError('joinStage is not supported by this service');
  }

  /// Stops publishing but stays in the room as a viewer.
  Future<void> leaveStage() async {}

  /// Applies a host moderation command to this guest's local tracks.
  Future<void> setStageMicrophoneEnabled(bool enabled) async {}

  Future<void> setStageCameraEnabled(bool enabled) async {}
}

/// Simulates LiveKit join / leave / reconnect with realistic delays.
class FakeLiveKitService implements LiveKitService {
  final _stateController = StreamController<LiveKitConnectionState>.broadcast();
  final _battleStateController =
      StreamController<LiveKitConnectionState>.broadcast();

  LiveKitConnectionState _state = LiveKitConnectionState.disconnected;
  String? _roomName;
  String? _streamUrl;
  String? _url;
  String? _token;
  LiveMediaHints? _mediaHints;

  @override
  LiveMediaHints? get mediaHints => _mediaHints;

  @override
  Room? get room => null;

  @override
  Room? get battleRoom => null;

  @override
  Future<void> connectBattle({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {
    _setBattleState(LiveKitConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 700));
    if (token.isEmpty) {
      _setBattleState(LiveKitConnectionState.failed);
      throw Exception('Invalid LiveKit battle token');
    }
    _setBattleState(LiveKitConnectionState.connected);
  }

  @override
  Future<void> disconnectBattle() async {
    _setBattleState(LiveKitConnectionState.disconnected);
    await Future.delayed(const Duration(milliseconds: 150));
  }

  var _publishing = false;

  @override
  bool get isPublishing => _publishing;

  @override
  Future<void> prepareStage() async {}

  @override
  Future<void> joinStage({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {
    _mediaHints = mediaHints;
    _publishing = true;
  }

  @override
  Future<void> leaveStage() async {
    _publishing = false;
  }

  @override
  Future<void> setStageMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> setStageCameraEnabled(bool enabled) async {}

  /// Public sample MP4 used as the mock "live" video source.
  static const defaultMockStreamUrl =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  @override
  LiveKitConnectionState get state => _state;

  @override
  Stream<LiveKitConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<LiveKitConnectionState> get battleStateStream => _battleStateController.stream;

  @override
  String? get roomName => _roomName;

  @override
  String? get streamUrl => _streamUrl;

  void _setState(LiveKitConnectionState next) {
    _state = next;
    _stateController.add(next);
  }

  void _setBattleState(LiveKitConnectionState next) {
    _battleStateController.add(next);
  }

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
    String? mockStreamUrl,
    LiveMediaHints? mediaHints,
    bool keepBattleRoom = false,
  }) async {
    _url = url;
    _token = token;
    _mediaHints = mediaHints;
    _roomName = roomName;
    _setState(LiveKitConnectionState.connecting);

    // Simulate signaling + ICE gather.
    await Future.delayed(const Duration(milliseconds: 900));

    if (token.isEmpty) {
      _setState(LiveKitConnectionState.failed);
      throw Exception('Invalid LiveKit token');
    }

    _streamUrl = mockStreamUrl ?? defaultMockStreamUrl;
    _setState(LiveKitConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    _setState(LiveKitConnectionState.disconnected);
    await Future.delayed(const Duration(milliseconds: 150));
    _roomName = null;
    _streamUrl = null;
    _url = null;
    _token = null;
    _mediaHints = null;
  }

  @override
  Future<void> reconnect() async {
    if (_url == null || _token == null || _roomName == null) {
      _setState(LiveKitConnectionState.failed);
      return;
    }
    _setState(LiveKitConnectionState.reconnecting);
    await Future.delayed(const Duration(milliseconds: 700));
    _setState(LiveKitConnectionState.connected);
  }

  void dispose() {
    _stateController.close();
    _battleStateController.close();
  }
}
