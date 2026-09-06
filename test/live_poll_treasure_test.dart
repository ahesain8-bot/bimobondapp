import 'package:bimobondapp/core/services/live_operation_guard.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bimobondapp/features/live/domain/entities/live_interactive.dart';
import 'package:bimobondapp/features/live/domain/repositories/live_interactive_repository.dart';
import 'package:bimobondapp/features/live/domain/repositories/live_session_repository.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_interactive/live_interactive_bloc.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_interactive/live_interactive_event.dart';

/// Feature 21 — polls and treasure boxes. Counts, percentages and coin shares
/// are all server-authoritative; this file pins the two client-side rules that
/// protect them: stale poll events and duplicate coin claims.
class FakeRepo implements LiveInteractiveRepository {
  int endPollCalls = 0, claimCalls = 0;
  Completer<LiveTreasureClaim>? claimGate;
  Object? claimError;

  @override
  Future<void> endPoll({required String liveId, required String pollId}) async {
    endPollCalls++;
  }

  @override
  Future<LiveTreasureClaim> claimTreasureBox({
    required String liveId,
    required String boxId,
  }) async {
    claimCalls++;
    if (claimGate != null) return claimGate!.future;
    if (claimError != null) throw claimError!;
    return LiveTreasureClaim(
      boxId: boxId,
      coinsWon: 50,
      claimedCount: 1,
      remainingCoins: 450,
    );
  }

  @override
  Future<LivePoll?> getActivePoll(String liveId) async => null;
  @override
  Future<List<LiveQA>> listQuestions(String liveId) async => const [];
  @override
  Future<List<LiveTreasureBox>> listTreasureBoxes(String liveId) async =>
      const [];
  @override
  Future<List<LiveAuction>> listActiveAuctions(String liveId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

Map<String, dynamic> pollJson({
  required String id,
  String status = 'ACTIVE',
  int totalVotes = 0,
}) => {
  'id': id,
  'liveId': 'live-1',
  'question': 'Which song next?',
  'status': status,
  'totalVotes': totalVotes,
  'options': [
    {'text': 'A', 'votes': totalVotes, 'percentage': 100.0},
    {'text': 'B', 'votes': 0, 'percentage': 0.0},
  ],
};

LiveHudInteractiveEvent pollEvent(
  Map<String, dynamic> payload, {
  String liveId = 'live-1',
}) => LiveHudInteractiveEvent(
  LiveInteractiveSocketPayload(
    event: 'livePollUpdated',
    liveId: liveId,
    payload: payload,
  ),
);

void main() {
  late FakeRepo repo;
  late StreamController<Object> socket;
  late LiveInteractiveBloc bloc;

  setUp(() {
    repo = FakeRepo();
    socket = StreamController<Object>.broadcast();
    bloc = LiveInteractiveBloc(
      repository: repo,
      socketEvents: socket.stream,
      liveId: 'live-1',
    );
  });

  tearDown(() async {
    await bloc.close();
    await socket.close();
  });

  group('poll events are filtered by poll id', () {
    test(
      'an active poll is shown and its counts come from the server',
      () async {
        socket.add(pollEvent(pollJson(id: 'poll-1', totalVotes: 7)));
        await bloc.stream.firstWhere((s) => s.poll != null);
        expect(bloc.state.activePoll!.id, 'poll-1');
        // Votes and percentages are read, never accumulated here.
        expect(bloc.state.poll!.totalVotes, 7);
        expect(bloc.state.poll!.options.first.percentage, 100.0);
      },
    );

    test('a late event cannot revive a poll the host already ended', () async {
      socket.add(pollEvent(pollJson(id: 'poll-1')));
      await bloc.stream.firstWhere((s) => s.poll != null);

      bloc.add(const LiveInteractivePollEnded());
      await bloc.stream.firstWhere((s) => s.poll == null);
      expect(repo.endPollCalls, 1);

      // A delayed ACTIVE snapshot for the same poll arrives afterwards.
      socket.add(pollEvent(pollJson(id: 'poll-1', totalVotes: 99)));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.poll, isNull);
      expect(bloc.state.activePoll, isNull);
    });

    test(
      'an ended event for another poll does not close the current one',
      () async {
        socket.add(pollEvent(pollJson(id: 'poll-2')));
        await bloc.stream.firstWhere((s) => s.poll != null);

        socket.add(pollEvent(pollJson(id: 'poll-1', status: 'ENDED')));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.activePoll!.id, 'poll-2');
      },
    );

    test('the poll on screen can close itself', () async {
      socket.add(pollEvent(pollJson(id: 'poll-2')));
      await bloc.stream.firstWhere((s) => s.poll != null);

      socket.add(pollEvent(pollJson(id: 'poll-2', status: 'ENDED')));
      await bloc.stream.firstWhere((s) => s.activePoll == null);
      expect(bloc.state.poll!.isActive, false);
    });

    test('a newer poll replaces the previous one', () async {
      socket.add(pollEvent(pollJson(id: 'poll-1')));
      await bloc.stream.firstWhere((s) => s.poll != null);

      socket.add(pollEvent(pollJson(id: 'poll-3')));
      await bloc.stream.firstWhere((s) => s.poll?.id == 'poll-3');
      expect(bloc.state.activePoll!.id, 'poll-3');
    });

    test('an event for another live is ignored', () async {
      socket.add(pollEvent(pollJson(id: 'poll-1')));
      await bloc.stream.firstWhere((s) => s.poll != null);

      socket.add(pollEvent(pollJson(id: 'poll-9'), liveId: 'live-2'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.poll!.id, 'poll-1');
    });

    test('an identity-less event cannot close the active poll', () async {
      socket.add(pollEvent(pollJson(id: 'poll-1')));
      await bloc.stream.firstWhere((s) => s.poll != null);

      socket.add(pollEvent({'liveId': 'live-1'}));
      await Future<void>.delayed(Duration.zero);
      // mobile-api.md: poll end emits the poll with status ENDED, not an empty object.
      expect(bloc.state.poll?.id, 'poll-1');
    });
  });

  group('treasure box claims are sent once', () {
    test('two simultaneous taps send exactly one claim', () async {
      repo.claimGate = Completer<LiveTreasureClaim>();
      bloc.add(const LiveInteractiveTreasureBoxClaimed('box-1'));
      bloc.add(const LiveInteractiveTreasureBoxClaimed('box-1'));
      await Future<void>.delayed(Duration.zero);
      expect(repo.claimCalls, 1);

      repo.claimGate!.complete(
        const LiveTreasureClaim(
          boxId: 'box-1',
          coinsWon: 50,
          claimedCount: 1,
          remainingCoins: 450,
        ),
      );
      await bloc.stream.firstWhere((s) => s.lastClaim != null);
      // The reward comes from the server response, never added locally.
      expect(bloc.state.lastClaim!.coinsWon, 50);
    });

    test('a different box is not blocked by the first', () async {
      repo.claimGate = Completer<LiveTreasureClaim>();
      bloc.add(const LiveInteractiveTreasureBoxClaimed('box-1'));
      bloc.add(const LiveInteractiveTreasureBoxClaimed('box-2'));
      await Future<void>.delayed(Duration.zero);
      expect(repo.claimCalls, 2);
      repo.claimGate!.complete(
        const LiveTreasureClaim(
          boxId: 'box-1',
          coinsWon: 10,
          claimedCount: 1,
          remainingCoins: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    });

    test('a network failure stays unresolved on another tap', () async {
      repo.claimError = Exception('network');
      bloc.add(const LiveInteractiveTreasureBoxClaimed('box-1'));
      await bloc.stream.firstWhere((s) => s.error != null);
      repo.claimError = null;
      bloc.add(const LiveInteractiveTreasureBoxClaimed('box-1'));
      await Future<void>.delayed(Duration.zero);
      expect(repo.claimCalls, 1);
      expect(bloc.state.lastClaim, isNull);
    });

    test('a proven pre-dispatch rejection permits an explicit retry', () async {
      repo.claimError = const LiveOperationNotSent('not dispatched');
      bloc.add(const LiveInteractiveTreasureBoxClaimed('box-1'));
      await bloc.stream.firstWhere((s) => s.error != null);
      expect(repo.claimCalls, 1);

      // Nothing was retried automatically; a fresh user tap is accepted.
      repo.claimError = null;
      bloc.add(const LiveInteractiveTreasureBoxClaimed('box-1'));
      await bloc.stream.firstWhere((s) => s.lastClaim != null);
      expect(repo.claimCalls, 2);
    });
  });
}
