import 'dart:async';

import 'package:bimobondapp/core/services/live_operation_guard.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live/data/datasources/live_interactive_remote_datasource.dart';
import 'package:bimobondapp/features/live/data/repositories/live_interactive_repository_impl.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_interactive/live_interactive_bloc.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_interactive/live_interactive_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryOperationStore implements LiveOperationStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  test('two independent Blocs/repositories send one HTTP claim', () async {
    final guard = LiveOperationGuard(MemoryOperationStore());
    var calls = 0;
    final response = Completer<http.Response>();
    final client = MockClient((request) {
      calls++;
      return response.future;
    });
    LiveInteractiveBloc room() => LiveInteractiveBloc(
      liveId: 'live',
      repository: LiveInteractiveRepositoryImpl(
        userIdProvider: () => 'user',
        operationGuard: guard,
        remote: LiveInteractiveRemoteDataSource(
          apiClient: LiveApiClient(httpClient: client),
        ),
      ),
    );
    final a = room(), b = room();
    a.add(const LiveInteractiveTreasureBoxClaimed('box'));
    b.add(const LiveInteractiveTreasureBoxClaimed('box'));
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    response.complete(
      http.Response(
        '{"id":"claim","boxId":"box","coinsWon":10,"box":{"id":"box","remainingCoins":0,"claimedCount":1}}',
        200,
      ),
    );
    await a.stream.firstWhere((state) => state.lastClaim != null);
    expect(a.state.lastClaim!.remainingCoins, 0);
    expect(b.state.lastClaim, isNull);
    await a.close();
    await b.close();
    client.close();
  });

  test(
    'uncertainty survives restart; different users, lives and boxes work',
    () async {
      final store = MemoryOperationStore();
      var guard = LiveOperationGuard(store);
      var calls = 0;
      Future<int> send() async {
        calls++;
        throw TimeoutException('after dispatch');
      }

      Future<int> run(String user, String live, String box) => guard.run(
        userId: () => user,
        liveId: live,
        operation: 'claim',
        entityId: box,
        send: send,
      );
      await expectLater(run('a', 'l', 'b'), throwsA(isA<TimeoutException>()));
      guard = LiveOperationGuard(store);
      await expectLater(
        run('a', 'l', 'b'),
        throwsA(isA<LiveOperationUnresolved>()),
      );
      expect(calls, 1);
      await expectLater(run('b', 'l', 'b'), throwsA(isA<TimeoutException>()));
      await expectLater(run('a', 'l2', 'b'), throwsA(isA<TimeoutException>()));
      await expectLater(run('a', 'l', 'b2'), throwsA(isA<TimeoutException>()));
      expect(calls, 4);
    },
  );

  test('only proven non-dispatch releases a reservation', () async {
    final guard = LiveOperationGuard(MemoryOperationStore());
    var rejected = true;
    Future<int> run() => guard.run(
      userId: () => 'user',
      liveId: 'live',
      operation: 'claim',
      entityId: 'box',
      send: () async {
        if (rejected) throw const LiveOperationNotSent('local rejection');
        return 0;
      },
    );
    await expectLater(run(), throwsA(isA<LiveOperationNotSent>()));
    rejected = false;
    expect(await run(), 0);
    await expectLater(run(), throwsA(isA<LiveOperationUnresolved>()));
  });
}
