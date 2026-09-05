import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show Room;

import 'package:bimobondapp/core/models/live_media_hints.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_livekit_service.dart';
import 'package:bimobondapp/features/live_viewer/data/services/live_session_diagnostics.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/presentation/di/live_viewer_injector.dart'
    as di;
import 'package:bimobondapp/features/live_viewer/presentation/widgets/live_video_player.dart';

/// The feed keeps several pages mounted, but there is only one LiveKit room in
/// the process. Off-screen pages observing it is what previously let an
/// invisible player issue subscription and quality changes against the room
/// the viewer was actually watching.
void main() {
  late _ObservableLiveKit liveKit;

  LiveEntity live(String id) => LiveEntity(
    id: id,
    hostId: 'host-$id',
    hostName: 'Host $id',
    title: 'Live $id',
    category: 'General',
    startTime: DateTime(2026, 1, 1),
  );

  setUp(() {
    liveKit = _ObservableLiveKit();
    if (di.sl.isRegistered<LiveKitService>()) {
      di.sl.unregister<LiveKitService>();
    }
    di.sl.registerSingleton<LiveKitService>(liveKit);
  });

  tearDown(() async {
    await di.sl.unregister<LiveKitService>();
  });

  Widget host({required bool isActive, String id = 'a'}) {
    return MaterialApp(
      home: Scaffold(
        body: LiveVideoPlayer(
          live: live(id),
          isActive: isActive,
          liveKitOnly: true,
        ),
      ),
    );
  }

  /// The poster runs an indefinite shimmer (`flutter_animate`), so the tree
  /// has to be unmounted before the test ends or the binding reports its
  /// timer as leaked.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('an off-screen page never observes the room', (tester) async {
    await tester.pumpWidget(host(isActive: false));

    expect(liveKit.listeners, 0);
    await unmount(tester);
  });

  testWidgets('the visible page observes the room exactly once', (
    tester,
  ) async {
    await tester.pumpWidget(host(isActive: true));

    expect(liveKit.listeners, 1);

    // A rebuild that does not change the live or the active flag must not
    // add a second observer.
    await tester.pumpWidget(host(isActive: true));
    expect(liveKit.listeners, 1);
    await unmount(tester);
  });

  testWidgets('becoming inactive releases the observer immediately', (
    tester,
  ) async {
    await tester.pumpWidget(host(isActive: true));
    expect(liveKit.listeners, 1);

    await tester.pumpWidget(host(isActive: false));
    expect(liveKit.listeners, 0);
    await unmount(tester);
  });

  testWidgets('disposing the page releases the observer', (tester) async {
    await tester.pumpWidget(host(isActive: true));
    expect(liveKit.listeners, 1);

    await unmount(tester);
    expect(liveKit.listeners, 0);
  });

  testWidgets('a lifecycle event on the shared room never throws', (
    tester,
  ) async {
    await tester.pumpWidget(host(isActive: true));

    // No room object means no renderer: livekit_client 2.11 exposes no
    // first-frame callback, so "a subscribed track exists" is the earliest
    // honest signal and everything before it stays on the poster.
    liveKit.emit(LiveKitConnectionState.connected);
    await tester.pump();
    liveKit.emit(LiveKitConnectionState.reconnecting);
    await tester.pump();
    liveKit.emit(
      LiveKitConnectionState.disconnected,
      cause: LiveKitDisconnectCause.network,
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}

/// Counts stream subscriptions so a test can assert who is watching the room.
class _ObservableLiveKit implements LiveKitService {
  final _controller = StreamController<LiveKitSessionUpdate>.broadcast();
  var listeners = 0;

  Stream<LiveKitSessionUpdate> get _counted =>
      Stream<LiveKitSessionUpdate>.multi((controller) {
        listeners++;
        final sub = _controller.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = () {
          listeners--;
          return sub.cancel();
        };
      });

  void emit(LiveKitConnectionState state, {LiveKitDisconnectCause? cause}) {
    _controller.add(
      LiveKitSessionUpdate(state: state, generation: 1, cause: cause),
    );
  }

  @override
  Stream<LiveKitSessionUpdate> get sessionStream => _counted;

  @override
  Stream<LiveKitConnectionState> get stateStream =>
      _counted.map((update) => update.state);

  @override
  Stream<LiveKitConnectionState> get battleStateStream =>
      const Stream<LiveKitConnectionState>.empty();

  @override
  LiveKitConnectionState get state => LiveKitConnectionState.disconnected;

  @override
  String? get roomName => null;

  @override
  String? get streamUrl => null;

  @override
  LiveMediaHints? get mediaHints => null;

  @override
  Room? get room => null;

  @override
  Room? get battleRoom => null;

  @override
  bool get isPublishing => false;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
    String? mockStreamUrl,
    LiveMediaHints? mediaHints,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> reconnect() async {}

  @override
  Future<void> connectBattle({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {}

  @override
  Future<void> disconnectBattle() async {}

  @override
  Future<void> prepareStage() async {}

  @override
  Future<void> joinStage({
    required String url,
    required String token,
    required String roomName,
    LiveMediaHints? mediaHints,
  }) async {}

  @override
  Future<void> leaveStage() async {}

  @override
  Future<void> setStageMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> setStageCameraEnabled(bool enabled) async {}
}
