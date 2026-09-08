import 'package:bimobondapp/core/models/live_battle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LiveBattle snapshot([Map<String, dynamic> patch = const {}]) =>
      LiveBattle.fromJson({
        'id': 'pk', 'live1Id': 'a', 'live2Id': 'b',
        'live3Id': 'c', 'live4Id': 'd', 'mode': 'TEAM',
        'status': 'ACTIVE', 'phase': 'BATTLE',
        'live1Score': 80, 'live2Score': 40, 'likeScore1': 8,
        'multiplier': 2, 'bestOf': 3, 'roundNumber': 2,
        'wins1': 1, 'wins2': 0, 'openSlots': <int>[],
        'endTime': '2026-09-08T12:05:00Z',
        'powerUps': {'stunTeam': 2, 'gloveTeam': 1, 'gloveCharges': 2},
        ...patch,
      });

  test('teammates use their own team score and opposing captain', () {
    final battle = snapshot();
    expect(battle.scoreFor('c'), 80);
    expect(battle.opponentScoreFor('c'), 40);
    expect(battle.opponentLiveId('c'), 'b');
    expect(battle.opponentLiveId('d'), 'a');
    expect(battle.opponentLiveId('outsider'), isEmpty);
  });

  test('roster patch clears one seat and preserves other fields', () {
    final battle = LiveBattle.fromJson({
      'id': 'pk', 'live3Id': null, 'openSlots': [1],
    }).withTimingFrom(snapshot(), updateType: 'roster');
    expect(battle.live3Id, isNull);
    expect(battle.live4Id, 'd');
    expect(battle.live1Id, 'a');
    expect(battle.live1Score, 80);
    expect(battle.likeScore1, 8);
    expect(battle.multiplier, 2);
    expect(battle.isTeamMode, isTrue);
  });

  test('explicit zero and null are applied; absent fields survive', () {
    final battle = LiveBattle.fromJson({
      'id': 'pk', 'live1Score': 0, 'multiplierEndsAt': null,
      'powerUps': {'gloveCharges': 0, 'stunTeam': null},
    }).withTimingFrom(snapshot(), updateType: 'score');
    expect(battle.live1Score, 0);
    expect(battle.live2Score, 40);
    expect(battle.powerUps!.stunTeam, isNull);
    expect(battle.powerUps!.gloveTeam, 1);
    expect(battle.powerUps!.gloveCharges, 0);
  });

  test('finish patch preserves score, roster and series result', () {
    final battle = LiveBattle.fromJson({
      'id': 'pk', 'winnerLiveId': null,
    }).withTimingFrom(snapshot(), updateType: 'finished');
    expect(battle.isFinished, isTrue);
    expect(battle.live1Score, 80);
    expect(battle.live4Id, 'd');
    expect(battle.bestOf, 3);
    expect(battle.wins1, 1);
  });

  test('full late ACTIVE score cannot revive a finished battle', () {
    final finished = snapshot({'status': 'FINISHED'});
    expect(snapshot().withTimingFrom(finished, updateType: 'score'), finished);
  });

  test('older round cannot overwrite current round', () {
    final current = snapshot();
    expect(snapshot({'roundNumber': 1, 'wins1': 0})
        .withTimingFrom(current, updateType: 'score'), current);
  });

  test('round_finished is not a series finished event', () {
    expect(snapshot().normalizedForUpdate(updateType: 'round_finished').isActive,
        isTrue);
  });

  test('explicit empty flat seat overrides a stale nested teammate', () {
    expect(snapshot({'live3Id': null, 'teams': {
      'team1': {'teammateLiveId': 'old'},
    }}).live3Id, isNull);
  });
}
