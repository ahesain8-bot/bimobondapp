import 'dart:async';
import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:bimobondapp/features/live/data/datasources/live_secondary_rooms.dart';
import 'package:bimobondapp/features/live/domain/entities/live_cohost.dart';

class TestRoom extends Room {
  Completer<void>? connectGate;
  Completer<void>? disconnectGate;
  bool failConnect = false;
  bool failDisconnect = false;
  int connections = 0;
  int disconnections = 0;
  int disposals = 0;
  void Function()? onDisconnect;
  final participants = <String, RemoteParticipant>{};
  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(participants);
  ConnectionState phase = ConnectionState.disconnected;
  final ownedListeners = <EventsListener<RoomEvent>>[];
  @override
  ConnectionState get connectionState => phase;
  @override
  EventsListener<RoomEvent> createListener({bool synchronized = false}) {
    final listener = super.createListener(synchronized: synchronized);
    ownedListeners.add(listener);
    return listener;
  }

  @override
  Future<void> connect(
    String url,
    String token, {
    ConnectOptions? connectOptions,
    RoomOptions? roomOptions,
    FastConnectOptions? fastConnectOptions,
  }) async {
    connections++;
    phase = ConnectionState.connecting;
    await connectGate?.future;
    if (failConnect) throw StateError('test connection failed');
    phase = ConnectionState.connected;
  }

  @override
  Future<void> disconnect() async {
    disconnections++;
    onDisconnect?.call();
    await disconnectGate?.future;
    phase = ConnectionState.disconnected;
    if (failDisconnect) throw StateError('test disconnect failed');
  }

  @override
  Future<bool> dispose() async {
    disposals++;
    return super.dispose();
  }
}

class TestVideo extends Fake implements RemoteVideoTrack {}

class TestPublication extends Fake
    implements RemoteTrackPublication<RemoteVideoTrack> {
  TestPublication(this.track, {this.source = TrackSource.camera});
  @override
  final RemoteVideoTrack track;
  @override
  final TrackSource source;
  @override
  bool subscribed = true;
  @override
  bool muted = false;
}

class TestParticipant extends Fake implements RemoteParticipant {
  TestParticipant(this.identity, this.videoTrackPublications);
  @override
  final String identity;
  @override
  final List<RemoteTrackPublication<RemoteVideoTrack>> videoTrackPublications;
}

LiveCohostRoom target(String id) => LiveCohostRoom(
  liveId: id,
  token: 'test-$id',
  url: 'wss://example.invalid',
  roomName: 'room-$id',
  role: 'viewer',
);
Future<void> flush() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'overlapping syncs converge to newest roster after delayed removal',
    () async {
      final rooms = <TestRoom>[];
      final manager = LiveSecondaryRooms(
        roomFactory: () {
          final r = TestRoom();
          rooms.add(r);
          return r;
        },
      );
      await manager.sync([target('a')]);
      rooms.first.disconnectGate = Completer<void>();
      final old = manager.sync([target('b')]);
      await flush();
      final latest = manager.sync([target('c')]);
      await flush();
      rooms.first.disconnectGate!.complete();
      await Future.wait([old, latest]);
      final ids = manager.liveIds;
      await manager.disconnectAll();
      manager.dispose();
      expect(ids, ['c']);
      expect(rooms.every((r) => r.disposals == 1), true);
    },
  );

  test('old disconnect never removes reconnected live id', () async {
    final rooms = <TestRoom>[];
    final manager = LiveSecondaryRooms(
      roomFactory: () {
        final r = TestRoom();
        rooms.add(r);
        return r;
      },
    );
    await manager.connect(target('a'));
    rooms.first.disconnectGate = Completer<void>();
    final close = manager.disconnect('a');
    await flush();
    final reopen = manager.connect(target('a'));
    await flush();
    rooms.first.disconnectGate!.complete();
    await Future.wait([close, reopen]);
    final current = manager.roomFor('a');
    await manager.disconnectAll();
    manager.dispose();
    // Clean up a leaked test room before asserting; do not hide the leak.
    final disposals = rooms.map((r) => r.disposals).toList();
    for (final r in rooms.where((r) => r.disposals == 0)) {
      await r.dispose();
    }
    expect(current, same(rooms.last));
    expect(disposals, everyElement(1));
  });

  test(
    'dispose while connecting closes room and listener exactly once',
    () async {
      final room = TestRoom()..connectGate = Completer<void>();
      var acquires = 0;
      var releases = 0;
      final manager = LiveSecondaryRooms(
        roomFactory: () => room,
        acquireAudioSession: () async {
          acquires++;
        },
        releaseAudioSession: () async {
          releases++;
        },
      );
      final connecting = manager.connect(target('a'));
      await flush();
      manager.dispose();
      room.connectGate!.complete();
      await connecting;
      await flush();
      expect(manager.liveIds, isEmpty);
      expect(room.disposals, 1);
      expect(room.ownedListeners.every((l) => l.isDisposed), true);
      expect(acquires, 1);
      expect(releases, 1);
    },
  );

  test(
    'connect failure disposes listener and releases idle audio ownership',
    () async {
      final room = TestRoom()..failConnect = true;
      var acquires = 0;
      var releases = 0;
      final manager = LiveSecondaryRooms(
        roomFactory: () => room,
        acquireAudioSession: () async {
          acquires++;
        },
        releaseAudioSession: () async {
          releases++;
        },
      );
      await manager.connect(target('a'));
      final listenersDisposed = room.ownedListeners.every((l) => l.isDisposed);
      final released = releases;
      await manager.disconnectAll();
      manager.dispose();
      expect(listenersDisposed, true);
      expect(room.disposals, 1);
      expect(acquires, 1);
      expect(released, 1);
    },
  );

  test('parallel room connects acquire audio only once', () async {
    final gate = Completer<void>();
    final rooms = <TestRoom>[];
    var acquires = 0;
    var releases = 0;
    final manager = LiveSecondaryRooms(
      roomFactory: () {
        final r = TestRoom();
        rooms.add(r);
        return r;
      },
      acquireAudioSession: () async {
        acquires++;
        await gate.future;
      },
      releaseAudioSession: () async {
        releases++;
      },
    );
    final a = manager.connect(target('a'));
    final b = manager.connect(target('b'));
    await flush();
    gate.complete();
    await Future.wait([a, b]);
    await manager.disconnectAll();
    manager.dispose();
    expect(acquires, 1);
    expect(releases, 1);
  });

  test('failed disconnect still disposes room and listener', () async {
    final room = TestRoom()..failDisconnect = true;
    final manager = LiveSecondaryRooms(roomFactory: () => room);
    await manager.connect(target('a'));
    await manager.disconnect('a');
    final disposals = room.disposals;
    manager.dispose();
    if (disposals == 0) await room.dispose();
    expect(disposals, 1);
    expect(room.ownedListeners.every((l) => l.isDisposed), true);
  });
  test('new empty sync invalidates a connect in flight', () async {
    final room = TestRoom()..connectGate = Completer<void>();
    final manager = LiveSecondaryRooms(roomFactory: () => room);
    final old = manager.sync([target('a'), target('b')]);
    await flush();
    final latest = manager.sync([]);
    await flush();
    room.connectGate!.complete();
    await Future.wait([old, latest]);
    expect(manager.liveIds, isEmpty);
    expect(room.disposals, 1);
    manager.dispose();
  });

  test(
    'selection uses exact host camera identity and follows track events',
    () async {
      final guestVideo = TestVideo();
      final hostVideo = TestVideo();
      final guest = TestParticipant('guest-id', [TestPublication(guestVideo)]);
      final hostPublication = TestPublication(hostVideo);
      final host = TestParticipant('host-identity', [hostPublication]);
      final room = TestRoom()
        ..participants.addAll({'guest-id': guest, 'host-identity': host});
      final manager = LiveSecondaryRooms(roomFactory: () => room);
      await manager.connect(target('live-id'));
      expect(manager.videoTrackFor('live-id'), isNull);
      expect(manager.videoTrackFor('live-id', hostIdentity: 'live-id'), isNull);
      expect(
        manager.videoTrackFor('live-id', hostIdentity: 'host-identity'),
        same(hostVideo),
      );
      var changes = 0;
      manager.addListener(() => changes++);
      hostPublication.muted = true;
      room.events.streamCtrl.add(
        TrackMutedEvent(participant: host, publication: hostPublication),
      );
      await flush();
      expect(changes, 1);
      expect(
        manager.videoTrackFor('live-id', hostIdentity: 'host-identity'),
        isNull,
      );
      room.participants.remove('host-identity');
      room.events.streamCtrl.add(
        ParticipantDisconnectedEvent(participant: host),
      );
      await flush();
      expect(changes, 2);
      expect(
        manager.videoTrackFor('live-id', hostIdentity: 'host-identity'),
        isNull,
      );
      hostPublication.muted = false;
      room.participants['host-identity'] = host;
      room.events.streamCtrl.add(ParticipantConnectedEvent(participant: host));
      await flush();
      expect(changes, 3);
      expect(
        manager.videoTrackFor('live-id', hostIdentity: 'host-identity'),
        same(hostVideo),
      );
      await manager.disconnectAll();
      manager.dispose();
    },
  );

  test(
    'token-only sync keeps usable room but changed room name replaces it',
    () async {
      final rooms = <TestRoom>[];
      final manager = LiveSecondaryRooms(
        roomFactory: () {
          final r = TestRoom();
          rooms.add(r);
          return r;
        },
      );
      await manager.sync([target('a')]);
      await manager.sync([
        const LiveCohostRoom(
          liveId: 'a',
          token: 'new',
          url: 'wss://example.invalid',
          roomName: 'room-a',
        ),
      ]);
      expect(rooms.length, 1);
      expect(rooms.first.disconnections, 0);
      await manager.sync([
        const LiveCohostRoom(
          liveId: 'a',
          token: 'new',
          url: 'wss://example.invalid',
          roomName: 'different',
        ),
      ]);
      expect(rooms.length, 2);
      expect(rooms.first.disposals, 1);
      await manager.disconnectAll();
      manager.dispose();
    },
  );

  test('last room is disconnected after releasing final audio lease', () async {
    final calls = <String>[];
    var count = 0;
    final manager = LiveSecondaryRooms(
      roomFactory: () {
        final id = ++count;
        return TestRoom()..onDisconnect = () => calls.add('disconnect-$id');
      },
      acquireAudioSession: () async => calls.add('acquire'),
      releaseAudioSession: () async => calls.add('release'),
    );
    await manager.sync([target('a'), target('b')]);
    await manager.disconnectAll();
    manager.dispose();
    expect(calls.where((s) => s == 'acquire'), hasLength(1));
    expect(calls.where((s) => s == 'release'), hasLength(1));
    expect(
      calls.indexOf('release'),
      lessThan(calls.lastIndexWhere((s) => s.startsWith('disconnect'))),
    );
  });
  test(
    'dispose during connect releases audio before disposing final SDK room',
    () async {
      final calls = <String>[];
      final room = TestRoom()
        ..connectGate = Completer<void>()
        ..onDisconnect = () => calls.add('disconnect');
      final manager = LiveSecondaryRooms(
        roomFactory: () => room,
        acquireAudioSession: () async => calls.add('acquire'),
        releaseAudioSession: () async => calls.add('release'),
      );
      final opening = manager.connect(target('a'));
      await flush();
      manager.dispose();
      room.connectGate!.complete();
      await opening;
      await flush();
      expect(calls, ['acquire', 'release', 'disconnect']);
    },
  );
}
