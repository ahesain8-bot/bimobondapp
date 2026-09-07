import 'dart:convert';
import 'dart:async';

import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live/data/datasources/live_games_remote_datasource.dart';
import 'package:bimobondapp/features/live/data/mappers/live_game_mapper.dart';
import 'package:bimobondapp/features/live/data/repositories/live_games_repository_impl.dart';
import 'package:bimobondapp/features/live/domain/entities/live_game.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_games/live_games_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Feature 22, against `lives/live-p3-parity.md` §3. The wheel prize, the
/// lucky-draw winner and the moment a quiz answer appears are the server's.
({LiveGamesBloc bloc, List<http.Request> requests}) harness(
  Future<http.Response> Function(http.Request) handler,
) {
  final requests = <http.Request>[];
  final api = LiveApiClient(
    httpClient: MockClient((r) {
      requests.add(r);
      return handler(r);
    }),
    idTokenProvider: () async => 'mock-firebase',
  );
  return (
    bloc: LiveGamesBloc(
      repository: LiveGamesRepositoryImpl(
        remote: LiveGamesRemoteDataSource(apiClient: api),
      ),
    ),
    requests: requests,
  );
}

Future<http.Response> _catalogOr(
  http.Request r,
  Map<String, dynamic> active,
) async {
  if (r.url.path == '/lives/games/catalog') {
    return http.Response(
      jsonEncode({
        'data': [
          {'type': 'QUIZ', 'name': 'Quiz'},
          {'type': 'WHEEL', 'name': 'Wheel'},
          {'type': 'LUCKY_DRAW', 'name': 'Lucky draw'},
          {'type': 'MYSTERY_BOX', 'name': 'Not in this build'},
        ],
      }),
      200,
    );
  }
  return http.Response(jsonEncode(active), 200);
}

void main() {
  group('the quiz answer stays hidden until the server sends it', () {
    test('a missing correctIndex is unknown, never option zero', () {
      final game = LiveGameMapper.gameFromJson({
        'id': 'g1',
        'type': 'QUIZ',
        'status': 'ACTIVE',
        'question': 'Which one?',
        'options': ['A', 'B'],
      })!;

      expect(game.correctIndex, isNull);
      expect(game.answerRevealed, isFalse);
    });

    test('the revealed answer is used exactly as sent', () {
      final game = LiveGameMapper.gameFromJson({
        'id': 'g1',
        'type': 'QUIZ',
        'status': 'ENDED',
        'options': ['A', 'B'],
        'correctIndex': 1,
      })!;

      expect(game.answerRevealed, isTrue);
      expect(game.correctIndex, 1);
      expect(game.canPlay, isFalse);
    });
  });

  group('the catalog and game types stay inside the contract', () {
    test('an unknown catalog type is dropped rather than guessed', () {
      final entries = LiveGameMapper.catalogFromJson({
        'data': [
          {'type': 'QUIZ'},
          {'type': 'MYSTERY_BOX'},
        ],
      });

      expect(entries.map((e) => e.type), [LiveGameType.quiz]);
    });

    test('an unknown running type is never playable', () {
      final game = LiveGameMapper.gameFromJson({
        'id': 'g1',
        'type': 'MYSTERY_BOX',
        'status': 'ACTIVE',
      })!;

      expect(game.type, LiveGameType.unknown);
      expect(game.canPlay, isFalse);
    });

    test('a quiz start needs a question, options and a valid answer', () {
      final remote = LiveGamesRemoteDataSource(
        apiClient: LiveApiClient(
          httpClient: MockClient((_) async {
            fail('An invalid quiz must not reach the network.');
          }),
        ),
      );

      expect(
        () => remote.start('live-1', type: 'QUIZ', question: 'q'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => remote.start(
          'live-1',
          type: 'QUIZ',
          question: 'q',
          options: ['A', 'B'],
          correctIndex: 5,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => remote.start('live-1', type: 'WHEEL', prizes: ['only one']),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('one active game, one play per viewer', () {
    test('starting sends the documented body', () async {
      Map<String, dynamic>? sent;
      final h = harness((r) async {
        if (r.method == 'POST' && r.url.path == '/lives/live-1/games') {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 'g1',
              'type': 'WHEEL',
              'status': 'ACTIVE',
              'prizes': ['A', 'B'],
            }),
            201,
          );
        }
        return _catalogOr(r, {});
      });

      h.bloc.add(const LiveGamesStarted('live-1'));
      await h.bloc.stream.firstWhere((s) => !s.loading);

      h.bloc.add(
        const LiveGameStartRequested(
          type: LiveGameType.wheel,
          prizes: ['A', 'B'],
        ),
      );
      final state = await h.bloc.stream.firstWhere((s) => !s.busy);

      expect(sent, {
        'type': 'WHEEL',
        'prizes': ['A', 'B'],
      });
      expect(state.game!.id, 'g1');
      await h.bloc.close();
    });

    test('a second start is refused while a game is running', () async {
      var starts = 0;
      final h = harness((r) async {
        if (r.method == 'POST' && r.url.path == '/lives/live-1/games') {
          starts++;
          return http.Response('{}', 201);
        }
        return _catalogOr(r, {
          'id': 'g1',
          'type': 'LUCKY_DRAW',
          'status': 'ACTIVE',
        });
      });

      h.bloc.add(const LiveGamesStarted('live-1'));
      await h.bloc.stream.firstWhere((s) => !s.loading && s.game != null);

      h.bloc.add(const LiveGameStartRequested(type: LiveGameType.luckyDraw));
      final state = await h.bloc.stream.first;

      expect(starts, 0);
      // The refusal is the client's own, so it travels as a typed notice the
      // UI localizes rather than as a message built in the BLoC.
      expect(state.notice, LiveGamesNotice.alreadyRunning);
      await h.bloc.close();
    });

    test('a viewer plays once and a repeat sends nothing', () async {
      var plays = 0;
      var played = false;
      final h = harness((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/play')) {
          plays++;
          played = true;
          return http.Response(
            jsonEncode({
              'id': 'g1',
              'type': 'QUIZ',
              'status': 'ACTIVE',
              'options': ['A', 'B'],
              'hasPlayed': true,
              'myPlay': {'optionIndex': 1},
            }),
            200,
          );
        }
        return _catalogOr(r, {
          'id': 'g1',
          'type': 'QUIZ',
          'status': 'ACTIVE',
          'question': 'Which one?',
          'options': ['A', 'B'],
          'hasPlayed': played,
        });
      });

      h.bloc.add(const LiveGamesStarted('live-1'));
      await h.bloc.stream.firstWhere((s) => !s.loading && s.game != null);

      h.bloc.add(const LiveGamePlayRequested(optionIndex: 1));
      final after = await h.bloc.stream.firstWhere((s) => !s.busy);
      expect(plays, 1);
      expect(after.game!.myPlayed, isTrue);
      expect(after.game!.canPlay, isFalse);

      // A second tap is dropped before the network.
      h.bloc.add(const LiveGamePlayRequested(optionIndex: 0));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(plays, 1);
      await h.bloc.close();
    });

    test('an out-of-range quiz answer is never sent', () async {
      var plays = 0;
      final h = harness((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/play')) {
          plays++;
          return http.Response('{}', 200);
        }
        return _catalogOr(r, {
          'id': 'g1',
          'type': 'QUIZ',
          'status': 'ACTIVE',
          'options': ['A', 'B'],
        });
      });

      h.bloc.add(const LiveGamesStarted('live-1'));
      await h.bloc.stream.firstWhere((s) => !s.loading && s.game != null);

      h.bloc.add(const LiveGamePlayRequested(optionIndex: 7));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(plays, 0);
      await h.bloc.close();
    });

    test(
      'a new game does not inherit the previous game participation',
      () async {
        final h = harness(
          (r) => _catalogOr(r, {
            'id': 'old',
            'type': 'QUIZ',
            'status': 'ENDED',
            'options': ['A', 'B'],
            'hasPlayed': true,
            'myPlay': {'optionIndex': 1},
          }),
        );
        addTearDown(h.bloc.close);
        h.bloc.add(const LiveGamesStarted('live-1'));
        await h.bloc.stream.firstWhere((s) => !s.loading && s.game != null);
        h.bloc.add(
          const LiveGameSocketReceived({
            'id': 'new',
            'type': 'QUIZ',
            'status': 'ACTIVE',
            'options': ['C', 'D'],
          }),
        );
        final next = await h.bloc.stream.firstWhere((s) => s.game?.id == 'new');
        expect(next.game!.canPlay, isTrue);
        expect(next.game!.myOptionIndex, isNull);
      },
    );

    test(
      'a successful play with a public snapshot still prevents duplicates',
      () async {
        var plays = 0;
        final h = harness((r) async {
          if (r.method == 'POST') plays++;
          return _catalogOr(r, {
            'id': 'g1',
            'type': 'QUIZ',
            'status': 'ACTIVE',
            'options': ['A', 'B'],
          });
        });
        addTearDown(h.bloc.close);
        h.bloc.add(const LiveGamesStarted('live-1'));
        await h.bloc.stream.firstWhere((s) => !s.loading && s.game != null);
        h.bloc.add(const LiveGamePlayRequested(optionIndex: 1));
        final played = await h.bloc.stream.firstWhere((s) => !s.busy);
        expect(played.game!.canPlay, isFalse);
        expect(played.game!.myOptionIndex, 1);
        h.bloc.add(const LiveGamePlayRequested(optionIndex: 0));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(plays, 1);
      },
    );

    test('an old room failure cannot overwrite a newly opened game', () async {
      final pending = Completer<http.Response>();
      final requested = Completer<void>();
      final h = harness((r) async {
        if (r.method == 'POST') {
          requested.complete();
          return pending.future;
        }
        return _catalogOr(r, {
          'id': r.url.path.contains('live-2') ? 'g2' : 'g1',
          'type': 'QUIZ',
          'status': 'ACTIVE',
          'options': ['A', 'B'],
        });
      });
      addTearDown(h.bloc.close);
      h.bloc.add(const LiveGamesStarted('live-1'));
      await h.bloc.stream.firstWhere((s) => !s.loading && s.game != null);
      h.bloc.add(const LiveGamePlayRequested(optionIndex: 1));
      await requested.future;
      h.bloc.add(const LiveGamesStarted('live-2'));
      await h.bloc.stream.firstWhere((s) => !s.loading && s.game?.id == 'g2');
      pending.complete(http.Response('{"message":"old room failed"}', 500));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(h.bloc.state.game!.id, 'g2');
      expect(h.bloc.state.message, isNull);
      expect(h.bloc.state.busy, isFalse);
    });

    test('a late play response does not reopen an ended game', () async {
      final pending = Completer<http.Response>();
      final requested = Completer<void>();
      final active = {
        'id': 'g1',
        'type': 'QUIZ',
        'status': 'ACTIVE',
        'options': ['A', 'B'],
      };
      final h = harness((r) async {
        if (r.method == 'POST') {
          requested.complete();
          return pending.future;
        }
        return _catalogOr(r, active);
      });
      addTearDown(h.bloc.close);
      h.bloc.add(const LiveGamesStarted('live-1'));
      await h.bloc.stream.firstWhere((s) => !s.loading && s.game != null);
      h.bloc.add(const LiveGamePlayRequested(optionIndex: 1));
      await requested.future;
      h.bloc.add(
        LiveGameSocketReceived({
          ...active,
          'status': 'ENDED',
          'correctIndex': 1,
        }),
      );
      await h.bloc.stream.firstWhere((s) => s.game?.isEnded == true);
      pending.complete(http.Response(jsonEncode(active), 200));
      final result = await h.bloc.stream.firstWhere((s) => !s.busy);
      expect(result.game!.isEnded, isTrue);
      expect(result.game!.correctIndex, 1);
      expect(result.game!.myPlayed, isTrue);
    });

    test('ending reveals the server result, not a local one', () async {
      var ended = false;
      final h = harness((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/end')) {
          ended = true;
          return http.Response(
            jsonEncode({
              'id': 'g1',
              'type': 'LUCKY_DRAW',
              'status': 'ENDED',
              'winnerUserId': 'u9',
              'winnerName': 'Sara',
              'prize': 'Coins',
            }),
            200,
          );
        }
        return _catalogOr(r, {
          'id': 'g1',
          'type': 'LUCKY_DRAW',
          'status': ended ? 'ENDED' : 'ACTIVE',
        });
      });

      h.bloc.add(const LiveGamesStarted('live-1'));
      final running = await h.bloc.stream.firstWhere(
        (s) => !s.loading && s.game != null,
      );
      // Nothing is decided while the game runs.
      expect(running.game!.winnerName, isNull);
      expect(running.game!.resultPrize, isNull);

      h.bloc.add(const LiveGameEndRequested());
      final state = await h.bloc.stream.firstWhere((s) => !s.busy);

      expect(state.game!.isEnded, isTrue);
      expect(state.game!.winnerName, 'Sara');
      expect(state.game!.resultPrize, 'Coins');
      await h.bloc.close();
    });
  });
}
