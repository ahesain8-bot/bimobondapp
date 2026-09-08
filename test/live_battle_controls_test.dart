import 'dart:async';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bimobondapp/core/models/live_battle.dart';
import 'package:bimobondapp/features/live/domain/repositories/live_session_repository.dart';
import 'package:bimobondapp/features/live/presentation/widgets/room/live_battle_controls.dart';

LiveBattle battle({String id = 'pk', String? teammate}) => LiveBattle.fromJson({
  'id': id,
  'live1Id': 'captain-a',
  'live2Id': 'captain-b',
  'live3Id': teammate,
  'live4Id': null,
  'mode': 'TEAM',
  'status': 'ACTIVE',
  'live1Score': 20,
  'live2Score': 10,
  'openSlots': [if (teammate == null) 1, 2],
});

class Repository extends Fake implements LiveSessionRepository {
  final calls = <Map<String, Object?>>[];
  Completer<LiveBattle>? pending;
  @override
  Future<List<LiveBattleOpponent>> loadBattleOpponents(
    String liveId, {
    int limit = 20,
  }) async => const [
    LiveBattleOpponent(
      liveId: 'captain-b',
      title: 'Live B',
      hostId: 'user-b',
      hostName: 'B',
    ),
    LiveBattleOpponent(
      liveId: 'teammate-c',
      title: 'Live C',
      hostId: 'user-c',
      hostName: 'C',
    ),
  ];
  @override
  Future<List<LiveBattle>> loadOpenTeamBattles(String liveId) async => [
    battle(),
  ];
  @override
  Future<LiveBattle> startBattle({
    required String liveId,
    required String opponentLiveId,
    int durationSeconds = 300,
    bool teamMode = false,
    String? scoringMode,
    String? scoringGiftId,
    int? bestOf,
    String? teammateLiveId,
    String? opponentTeammateLiveId,
  }) async {
    calls.add({
      'op': 'start',
      'live': liveId,
      'opponent': opponentLiveId,
      'duration': durationSeconds,
      'team': teamMode,
      'scoring': scoringMode,
      'gift': scoringGiftId,
      'bestOf': bestOf,
      'teammate': teammateLiveId,
      'opponentTeammate': opponentTeammateLiveId,
    });
    return pending == null ? battle() : pending!.future;
  }

  @override
  Future<LiveBattle> joinBattleTeam({
    required String liveId,
    required String battleId,
    int? team,
  }) async {
    calls.add({'op': 'join', 'live': liveId, 'battle': battleId, 'team': team});
    return battle(teammate: liveId);
  }

  @override
  Future<LiveBattle> inviteBattleTeammate({
    required String liveId,
    required String battleId,
    required String teammateLiveId,
  }) async {
    calls.add({
      'op': 'invite',
      'live': liveId,
      'battle': battleId,
      'teammate': teammateLiveId,
    });
    return battle(teammate: teammateLiveId);
  }

  @override
  Future<LiveBattle?> leaveBattleTeam({
    required String liveId,
    required String battleId,
  }) async {
    calls.add({'op': 'leave', 'live': liveId, 'battle': battleId});
    return battle();
  }

  @override
  Future<LiveBattle> activateBattlePowerUp({
    required String liveId,
    required String battleId,
    required String type,
  }) async {
    calls.add({
      'op': 'power',
      'live': liveId,
      'battle': battleId,
      'type': type,
    });
    return battle();
  }

  @override
  Future<LiveBattle> activateBattleMultiplier({
    required String liveId,
    required double multiplier,
    required int durationSeconds,
  }) async {
    calls.add({
      'op': 'multiplier',
      'live': liveId,
      'multiplier': multiplier,
      'duration': durationSeconds,
    });
    return battle();
  }

  @override
  Future<LiveBattle> endBattle({
    required String liveId,
    required String battleId,
  }) async {
    calls.add({'op': 'end', 'live': liveId, 'battle': battleId});
    return battle().copyWith(status: 'FINISHED');
  }
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    Repository repo, {
    String liveId = 'captain-a',
    LiveBattle? current,
    ValueChanged<LiveBattle?>? onChanged,
    bool Function()? canAct,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: LiveBattleControls(
              liveId: liveId,
              repository: repo,
              battle: current,
              onChanged: onChanged ?? (_) {},
              canAct: canAct ?? () => true,
              loadGifts: () async => const [
                GiftEntity(
                  id: 'gift-rose',
                  name: 'وردة الاختبار',
                  icon: '',
                  priceCoins: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'TEAM button starts with two captains, duration, scoring and BO3',
    (tester) async {
      final repo = Repository();
      await mount(tester, repo);
      await tester.tap(find.text('TEAM 2v2'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('pk-duration')), '600');
      await tap(tester, 'pk-best-of');
      await tester.tap(find.text('أفضل ثلاث جولات · BO3').last);
      await tester.pumpAndSettle();
      await tap(tester, 'pk-scoring');
      await tester.tap(find.text('الهدايا').last);
      await tester.pumpAndSettle();
      await tap(tester, 'pk-start-captain-b');
      expect(repo.calls, [
        {
          'op': 'start',
          'live': 'captain-a',
          'opponent': 'captain-b',
          'duration': 600,
          'team': true,
          'scoring': 'GIFTS',
          'gift': null,
          'bestOf': 3,
          'teammate': null,
          'opponentTeammate': null,
        },
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('1v1 keeps existing default request', (tester) async {
    final repo = Repository();
    await mount(tester, repo);
    await tap(tester, 'pk-start-captain-b');
    expect(repo.calls.single['team'], false);
    expect(repo.calls.single['duration'], 300);
    expect(repo.calls.single['scoring'], isNull);
    expect(repo.calls.single['bestOf'], isNull);
  });

  testWidgets('invalid duration and missing selected gift send no request', (
    tester,
  ) async {
    final repo = Repository();
    await mount(tester, repo);
    await tester.enterText(find.byKey(const ValueKey('pk-duration')), '29');
    await tap(tester, 'pk-start-captain-b');
    expect(repo.calls, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('pk-duration')), '300');
    await tap(tester, 'pk-scoring');
    await tester.tap(find.text('هدية محددة').last);
    await tester.pumpAndSettle();
    await tap(tester, 'pk-start-captain-b');
    expect(repo.calls, isEmpty);
  });

  testWidgets(
    'open lobby joins explicitly selected team with broadcaster live id',
    (tester) async {
      final repo = Repository();
      await mount(tester, repo, liveId: 'teammate-c');
      await tester.tap(find.text('TEAM 2v2'));
      await tester.pumpAndSettle();
      await tap(tester, 'pk-join-pk-2');
      expect(repo.calls.single, {
        'op': 'join',
        'live': 'teammate-c',
        'battle': 'pk',
        'team': 2,
      });
    },
  );

  testWidgets('captain invites a live, uses all powers, and ends only PK', (
    tester,
  ) async {
    final repo = Repository();
    await mount(tester, repo, current: battle());
    expect(find.byKey(const ValueKey('pk-leave')), findsNothing);
    await tap(tester, 'pk-invite-teammate-c');
    expect(repo.calls.last, {
      'op': 'invite',
      'live': 'captain-a',
      'battle': 'pk',
      'teammate': 'teammate-c',
    });
    for (final type in ['STUN', 'TIME', 'GLOVE']) {
      await tap(tester, 'pk-power-$type');
      expect(repo.calls.last, {
        'op': 'power',
        'live': 'captain-a',
        'battle': 'pk',
        'type': type,
      });
    }
    await tap(tester, 'pk-multiplier');
    expect(repo.calls.last, {
      'op': 'multiplier',
      'live': 'captain-a',
      'multiplier': 2.0,
      'duration': 30,
    });
    await tap(tester, 'pk-end');
    await tap(tester, 'pk-confirm-end');
    expect(repo.calls.last, {'op': 'end', 'live': 'captain-a', 'battle': 'pk'});
  });

  testWidgets('teammate leaves through own live and clears only local PK', (
    tester,
  ) async {
    final repo = Repository();
    var called = false;
    LiveBattle? result = battle();
    await mount(
      tester,
      repo,
      liveId: 'teammate-c',
      current: battle(teammate: 'teammate-c'),
      onChanged: (value) {
        called = true;
        result = value;
      },
    );
    expect(find.byKey(const ValueKey('pk-end')), findsNothing);
    await tap(tester, 'pk-leave');
    expect(repo.calls.single, {
      'op': 'leave',
      'live': 'teammate-c',
      'battle': 'pk',
    });
    expect(called, true);
    expect(result, isNull);
  });

  testWidgets(
    'operation is not repeated while waiting; departed room ignores response',
    (tester) async {
      final repo = Repository()..pending = Completer<LiveBattle>();
      var allowed = true;
      var changed = false;
      await mount(
        tester,
        repo,
        canAct: () => allowed,
        onChanged: (_) => changed = true,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('pk-start-captain-b')),
      );
      await tester.tap(find.byKey(const ValueKey('pk-start-captain-b')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pk-start-captain-b')));
      await tester.pump();
      expect(repo.calls, hasLength(1));
      allowed = false;
      repo.pending!.complete(battle());
      await tester.pumpAndSettle();
      expect(changed, false);
    },
  );

  testWidgets('controls fit a small RTL screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester, Repository(), current: battle());
    expect(tester.takeException(), isNull);
    final team1 = tester.getCenter(find.text('الفريق 1'));
    final team2 = tester.getCenter(find.text('الفريق 2'));
    expect(team1.dx, lessThan(team2.dx));
  });
  testWidgets('specific gift sends only selected catalog id', (tester) async {
    final repo = Repository();
    await mount(tester, repo);
    await tap(tester, 'pk-scoring');
    await tester.tap(find.text('هدية محددة').last);
    await tester.pumpAndSettle();
    await tap(tester, 'pk-scoring-gift');
    await tester.tap(find.text('وردة الاختبار').last);
    await tester.pumpAndSettle();
    await tap(tester, 'pk-start-captain-b');
    expect(repo.calls.single['scoring'], 'SPECIFIC_GIFT');
    expect(repo.calls.single['gift'], 'gift-rose');
  });
}
