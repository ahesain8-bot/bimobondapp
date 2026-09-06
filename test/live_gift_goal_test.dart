import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bimobondapp/features/live/data/mappers/live_interactive_mapper.dart';
import 'package:bimobondapp/features/live/data/mappers/live_session_mapper.dart';
import 'package:bimobondapp/features/live/domain/entities/live_interactive.dart';
import 'package:bimobondapp/features/live/domain/repositories/live_interactive_repository.dart';
import 'package:bimobondapp/features/live/domain/repositories/live_session_repository.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_interactive/live_interactive_bloc.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_interactive/live_interactive_event.dart';

/// Feature 16 — gift goals. Every number is server-authoritative: the POST
/// response or `liveGiftGoalUpdate`. Nothing is accumulated on the client.
class FakeInteractiveRepository implements LiveInteractiveRepository {
  int createCalls = 0;
  LiveGiftGoal created = const LiveGiftGoal(
    id: 'live-1',
    title: 'Unlock Cosplay Stream',
    target: 5000,
    current: 0,
  );
  Object? createError;

  @override
  Future<LiveGiftGoal> createGiftGoal({
    required String liveId,
    String? title,
    required int target,
  }) async {
    createCalls++;
    if (createError != null) throw createError!;
    return created;
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

LiveInteractiveSocketPayload goalEvent(
  Map<String, dynamic> payload, {
  String liveId = 'live-1',
}) => LiveInteractiveSocketPayload(
  event: 'liveGiftGoalUpdate',
  liveId: liveId,
  payload: payload,
);

void main() {
  group('gift goal patch mapping', () {
    test('reads the documented POST response envelope', () {
      final goal = LiveInteractiveMapper.giftGoal({
        'id': 'live-uuid',
        'giftGoalTitle': 'Unlock Cosplay Stream 🎉',
        'giftGoalTarget': 5000,
        'giftGoalCurrent': 0,
      });
      expect(goal.id, 'live-uuid');
      expect(goal.title, 'Unlock Cosplay Stream 🎉');
      expect(goal.target, 5000);
      expect(goal.current, 0);
    });

    test('a partial update keeps the fields it does not carry', () {
      const previous = LiveGiftGoal(
        id: 'live-1',
        title: 'Song request',
        target: 5000,
        current: 1200,
      );
      final patched = LiveInteractiveMapper.giftGoalPatch({
        'giftGoalCurrent': 1800,
      }, previous);
      // A missing target is unknown, not zero.
      expect(patched!.target, 5000);
      expect(patched.title, 'Song request');
      expect(patched.current, 1800);
      expect(patched.id, 'live-1');
    });

    test('an explicit null target is the documented "no goal" state', () {
      const previous = LiveGiftGoal(
        id: 'live-1',
        title: 'Song request',
        target: 5000,
        current: 1200,
      );
      expect(
        LiveInteractiveMapper.giftGoalPatch({'giftGoalTarget': null}, previous),
        isNull,
      );
      expect(
        LiveInteractiveMapper.giftGoalPatch({'giftGoalTarget': 0}, previous),
        isNull,
      );
    });

    test('an empty payload with no previous goal stays absent', () {
      expect(
        LiveInteractiveMapper.giftGoalPatch(const <String, dynamic>{}, null),
        isNull,
      );
    });

    test('a completed goal is reported as the server sent it', () {
      final patched = LiveInteractiveMapper.giftGoalPatch({
        'giftGoalTarget': 5000,
        'giftGoalCurrent': 5200,
      }, null);
      // Not clamped in the model: the server decides what completion means.
      expect(patched!.current, 5200);
      expect(patched.target, 5000);
    });

    test('accepts a nested giftGoal envelope and extra fields', () {
      final patched = LiveInteractiveMapper.giftGoalPatch({
        'liveId': 'live-1',
        'giftGoal': {
          'id': 'live-1',
          'giftGoalTarget': 900,
          'giftGoalCurrent': 100,
          'someFutureField': true,
        },
      }, null);
      expect(patched!.target, 900);
      expect(patched.current, 100);
    });
  });

  group('gift goal from the live snapshot', () {
    // `GET /lives/:id` carries the goal, so a viewer joining mid-stream sees
    // the bar immediately instead of waiting for the next gift.
    test('reads the documented live-detail fields', () {
      final session = LiveSessionMapper.fromLiveJson({
        'id': 'live-1',
        'status': 'LIVE',
        'giftGoalTitle': 'Unlock Special Song',
        'giftGoalTarget': 10000,
        'giftGoalCurrent': 3400,
      });
      expect(session.giftGoal!.target, 10000);
      expect(session.giftGoal!.current, 3400);
      expect(session.giftGoal!.title, 'Unlock Special Song');
    });

    test('a stream without a target has no goal', () {
      final none = LiveSessionMapper.fromLiveJson({
        'id': 'live-1',
        'status': 'LIVE',
      });
      expect(none.giftGoal, isNull);
      final zero = LiveSessionMapper.fromLiveJson({
        'id': 'live-1',
        'status': 'LIVE',
        'giftGoalTarget': 0,
      });
      expect(zero.giftGoal, isNull);
    });

    test('a missing current counts as zero progress, not a missing goal', () {
      final session = LiveSessionMapper.fromLiveJson({
        'id': 'live-1',
        'status': 'LIVE',
        'giftGoalTarget': 500,
      });
      expect(session.giftGoal!.target, 500);
      expect(session.giftGoal!.current, 0);
    });
  });

  group('gift goal bloc', () {
    late FakeInteractiveRepository repo;
    late StreamController<Object> socket;
    late LiveInteractiveBloc bloc;

    setUp(() {
      repo = FakeInteractiveRepository();
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

    test('the created goal is kept instead of being discarded', () async {
      bloc.add(const LiveInteractiveGiftGoalCreated(target: 5000));
      await bloc.stream.firstWhere((s) => s.giftGoal != null);
      expect(bloc.state.giftGoal!.target, 5000);
      expect(repo.createCalls, 1);
    });

    test('a non-positive target is rejected before any request', () async {
      bloc.add(const LiveInteractiveGiftGoalCreated(target: 0));
      await bloc.stream.firstWhere((s) => s.error != null);
      expect(repo.createCalls, 0);
      expect(bloc.state.giftGoal, isNull);
    });

    test(
      'progress follows the server event, never local accumulation',
      () async {
        socket.add(
          LiveHudInteractiveEvent(
            goalEvent({'giftGoalTarget': 5000, 'giftGoalCurrent': 1000}),
          ),
        );
        await bloc.stream.firstWhere((s) => s.giftGoal != null);
        expect(bloc.state.giftGoal!.current, 1000);

        // The same gift arriving twice cannot advance the bar: the value is
        // assigned from the payload, not added to what is already there.
        socket.add(
          LiveHudInteractiveEvent(
            goalEvent({'giftGoalTarget': 5000, 'giftGoalCurrent': 1000}),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.giftGoal!.current, 1000);
      },
    );

    test('an event for another live is ignored', () async {
      socket.add(
        LiveHudInteractiveEvent(
          goalEvent({'giftGoalTarget': 5000, 'giftGoalCurrent': 1000}),
        ),
      );
      await bloc.stream.firstWhere((s) => s.giftGoal != null);

      socket.add(
        LiveHudInteractiveEvent(
          goalEvent({
            'giftGoalTarget': 999,
            'giftGoalCurrent': 999,
          }, liveId: 'live-2'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.giftGoal!.target, 5000);
      expect(bloc.state.giftGoal!.current, 1000);
    });

    test('an explicit clear removes the goal', () async {
      socket.add(
        LiveHudInteractiveEvent(
          goalEvent({'giftGoalTarget': 5000, 'giftGoalCurrent': 1000}),
        ),
      );
      await bloc.stream.firstWhere((s) => s.giftGoal != null);

      socket.add(LiveHudInteractiveEvent(goalEvent({'giftGoalTarget': null})));
      await bloc.stream.firstWhere((s) => s.giftGoal == null);
      expect(bloc.state.giftGoal, isNull);
    });

    test('starting with a snapshot goal shows it before any event', () async {
      bloc.add(
        const LiveInteractiveStarted(
          'live-1',
          giftGoal: LiveGiftGoal(
            id: 'live-1',
            title: 'Unlock Special Song',
            target: 10000,
            current: 3400,
          ),
        ),
      );
      await bloc.stream.firstWhere((s) => s.giftGoal != null);
      expect(bloc.state.giftGoal!.current, 3400);
    });

    test('a viewer re-entering sees the goal from the next update', () async {
      // A fresh bloc, as after re-entering the room, starts with no goal and
      // adopts the server value without inventing one.
      expect(bloc.state.giftGoal, isNull);
      socket.add(
        LiveHudInteractiveEvent(
          goalEvent({
            'giftGoalTitle': 'Unlock Special Song',
            'giftGoalTarget': 10000,
            'giftGoalCurrent': 3400,
          }),
        ),
      );
      await bloc.stream.firstWhere((s) => s.giftGoal != null);
      expect(bloc.state.giftGoal!.title, 'Unlock Special Song');
      expect(bloc.state.giftGoal!.current, 3400);
    });
  });
}
