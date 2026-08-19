import 'dart:async';

import 'package:livekit_client/livekit_client.dart' show Room;

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
  String? get roomName;
  String? get streamUrl;

  /// The underlying LiveKit [Room] once connected (used to render remote
  /// video tracks), or null while disconnected. Fakes return null.
  Room? get room => null;

  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
    String? mockStreamUrl,
  });

  Future<void> disconnect();
  Future<void> reconnect();
  void dispose();
}

/// Simulates LiveKit join / leave / reconnect with realistic delays.
class FakeLiveKitService implements LiveKitService {
  final _stateController = StreamController<LiveKitConnectionState>.broadcast();

  LiveKitConnectionState _state = LiveKitConnectionState.disconnected;
  String? _roomName;
  String? _streamUrl;
  String? _url;
  String? _token;

  @override
  Room? get room => null;

  /// Public sample MP4 used as the mock "live" video source.
  static const defaultMockStreamUrl =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  @override
  LiveKitConnectionState get state => _state;

  @override
  Stream<LiveKitConnectionState> get stateStream => _stateController.stream;

  @override
  String? get roomName => _roomName;

  @override
  String? get streamUrl => _streamUrl;

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
    _url = url;
    _token = token;
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

  @override
  void dispose() {
    _stateController.close();
  }
}

/// A proxy that switches the UI between multiple underlying [LiveKitService]
/// instances without recreating the provider.
///
/// The feed keeps one "active" room and may keep one preloaded room; this
/// proxy lets [LiveVideoPlayer] and [ActiveLiveNotifier] share the same
/// provider reference while the actual delegate changes under the hood.
class LiveKitServiceProxy implements LiveKitService {
  LiveKitService? _delegate;
  final _stateController = StreamController<LiveKitConnectionState>.broadcast();
  StreamSubscription<LiveKitConnectionState>? _sub;

  @override
  LiveKitConnectionState get state =>
      _delegate?.state ?? LiveKitConnectionState.disconnected;

  @override
  Stream<LiveKitConnectionState> get stateStream => _stateController.stream;

  @override
  Room? get room => _delegate?.room;

  @override
  String? get roomName => _delegate?.roomName;

  @override
  String? get streamUrl => _delegate?.streamUrl;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
    String? mockStreamUrl,
  }) {
    if (_delegate == null) {
      throw StateError('No LiveKit delegate set');
    }
    return _delegate!.connect(
      url: url,
      token: token,
      roomName: roomName,
      mockStreamUrl: mockStreamUrl,
    );
  }

  @override
  Future<void> disconnect() async {
    await _delegate?.disconnect();
  }

  @override
  Future<void> reconnect() => _delegate?.reconnect() ?? Future.value();

  /// Swaps the backing service and re-broadcasts its state stream.
  void setDelegate(LiveKitService? delegate) {
    if (_delegate == delegate) return;
    _sub?.cancel();
    _sub = null;
    _delegate = delegate;
    if (delegate != null) {
      _sub = delegate.stateStream.listen(_emit);
      _emit(delegate.state);
    } else {
      _emit(LiveKitConnectionState.disconnected);
    }
  }

  void _emit(LiveKitConnectionState next) {
    _stateController.add(next);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _stateController.close();
  }
}
