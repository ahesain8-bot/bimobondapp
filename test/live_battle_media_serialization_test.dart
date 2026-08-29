import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:bimobondapp/core/models/live_media_hints.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_media_datasource.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_remote_datasource.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_socket_datasource.dart';
import 'package:bimobondapp/features/live/data/repositories/live_session_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the order of battle-room media calls and lets the test hold a
/// connect open, so an overlapping call can be observed.
class _RecordingMedia extends LivesMediaDataSource {
  final List<String> calls = [];
  Completer<void>? holdConnect;
  bool _battleRoomUp = false;
  Room? _battleRoom;

  @override
  Room? get battleRoom => _battleRoom;

  @override
  bool get isBattleRoomUsable => _battleRoomUp;

  @override
  Future<void> connectBattleAndSubscribe({
    required String url,
    required String token,
    LiveMediaHints? mediaHints,
  }) async {
    calls.add('connect');
    final hold = holdConnect;
    if (hold != null) await hold.future;
    _battleRoomUp = true;
    _battleRoom = Room();
  }

  @override
  Future<void> disconnectBattle() async {
    calls.add('disconnect');
    _battleRoomUp = false;
    final room = _battleRoom;
    _battleRoom = null;
    await room?.dispose();
  }
}

class _StubRemote extends LivesRemoteDataSource {
  int joins = 0;

  @override
  Future<Map<String, dynamic>> join(String liveId) async {
    joins++;
    return {
      'data': {'token': 'tok-$liveId', 'url': 'wss://test'},
    };
  }

  @override
  Future<Map<String, dynamic>> leave(String liveId) async => const {};
}

void main() {
  late _RecordingMedia media;
  late _StubRemote remote;
  late LiveSessionRepositoryImpl repository;

  setUp(() {
    media = _RecordingMedia();
    remote = _StubRemote();
    repository = LiveSessionRepositoryImpl(
      remote: remote,
      socket: LivesSocketDataSource(idTokenProvider: () async => null),
      media: media,
    );
  });

  test('a re-asserted opponent while connecting does not tear the room down', () async {
    // `liveBattle` score events land on every gift, and BLoC runs handlers
    // concurrently — this is that pair of events.
    media.holdConnect = Completer<void>();
    final first = repository.connectBattleOpponentMedia('opponent-1');
    await Future<void>.delayed(Duration.zero);
    final second = repository.connectBattleOpponentMedia('opponent-1');
    await Future<void>.delayed(Duration.zero);

    expect(
      media.calls,
      ['disconnect', 'connect'],
      reason: 'the second call must wait rather than disconnect mid-connect',
    );

    media.holdConnect!.complete();
    await Future.wait([first, second]);

    expect(
      media.calls,
      ['disconnect', 'connect'],
      reason: 'once connected, re-asserting the same opponent is a no-op',
    );
    expect(remote.joins, 1);
  });

  test('a different opponent still replaces the room, in order', () async {
    await repository.connectBattleOpponentMedia('opponent-1');
    final firstRoom = repository.battleMediaRoom;
    await repository.connectBattleOpponentMedia('opponent-2');
    final secondRoom = repository.battleMediaRoom;

    expect(media.calls, [
      'disconnect',
      'connect',
      'disconnect',
      'connect',
    ]);
    expect(remote.joins, 2);
    expect(secondRoom, isA<Room>());
    expect(identical(firstRoom, secondRoom), isFalse);
  });

  test('the repository exposes the actual battle Room after connect', () async {
    expect(repository.battleMediaRoom, isNull);

    await repository.connectBattleOpponentMedia('opponent-1');

    expect(repository.battleMediaRoom, isA<Room>());
    await repository.disconnectBattleOpponentMedia();
    expect(repository.battleMediaRoom, isNull);
  });

  test('battle end queued during connect cannot leave a stale Room', () async {
    media.holdConnect = Completer<void>();
    final connecting = repository.connectBattleOpponentMedia('opponent-1');
    await Future<void>.delayed(Duration.zero);
    final ending = repository.disconnectBattleOpponentMedia();

    media.holdConnect!.complete();
    await Future.wait([connecting, ending]);

    expect(repository.battleMediaRoom, isNull);
    expect(media.calls, ['disconnect', 'connect', 'disconnect']);
  });

  test('a failed connect does not block the next one', () async {
    final hold = Completer<void>();
    media.holdConnect = hold;
    final failing = repository.connectBattleOpponentMedia('opponent-1');
    await Future<void>.delayed(Duration.zero);
    hold.completeError(StateError('boom'));

    await expectLater(failing, throwsStateError);

    media.holdConnect = null;
    await repository.connectBattleOpponentMedia('opponent-2');

    expect(
      media.calls.last,
      'connect',
      reason: 'the queue sequences, it does not latch on a failure',
    );
    expect(remote.joins, 2);
  });
}
