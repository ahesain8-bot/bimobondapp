import 'dart:async';

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
  }

  @override
  Future<void> disconnectBattle() async {
    calls.add('disconnect');
    _battleRoomUp = false;
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
    await repository.connectBattleOpponentMedia('opponent-2');

    expect(media.calls, [
      'disconnect',
      'connect',
      'disconnect',
      'connect',
    ]);
    expect(remote.joins, 2);
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
