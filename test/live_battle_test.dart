import 'package:flutter_test/flutter_test.dart';

import 'package:bimobondapp/core/models/live_battle.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/socket_mapper.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/socket_event.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_session_entity.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_state.dart';

void main() {
  group('LiveBattle', () {
    final json = <String, dynamic>{
      'id': 'battle-1',
      'live1Id': 'live-a',
      'live2Id': 'live-b',
      'live1Score': 288,
      'live2Score': 1255,
      'status': 'ACTIVE',
      'phase': 'BATTLE',
      'multiplier': 2,
      'startTime': '2026-08-24T10:00:00Z',
      'endTime': '2026-08-24T10:05:00Z',
    };

    test('orients scores and opponent id around the watched live', () {
      final battle = LiveBattle.fromJson(json);

      expect(battle.isActive, isTrue);
      expect(battle.opponentLiveId('live-a'), 'live-b');
      expect(battle.scoreFor('live-a'), 288);
      expect(battle.opponentScoreFor('live-a'), 1255);
      expect(battle.scoreFor('live-b'), 1255);
      expect(battle.multiplier, 2);
      expect(battle.endTime, isNotNull);
    });

    test('maps the liveBattle socket envelope', () {
      final event = SocketMapper.battleEvent({
        'type': 'score',
        'battle': json,
      }, 'live-a');

      expect(event, isA<LiveBattleEvent>());
      expect(event!.liveId, 'live-a');
      expect(event.updateType, 'score');
      expect(event.battle.live2Score, 1255);
    });

    test('maps battle phase envelopes that wrap their payload in data', () {
      final event = SocketMapper.battleEvent({
        'type': 'multiplier_started',
        'data': {...json, 'multiplier': 3},
      }, 'live-b');

      expect(event, isNotNull);
      expect(event!.battle.multiplier, 3);
      expect(event.battle.opponentLiveId('live-b'), 'live-a');
    });

    test('missing status never starts a battle', () {
      final battle = LiveBattle.fromJson({...json}..remove('status'));

      expect(battle.isActive, isFalse);
    });
  });

  test('stale PK metadata cannot replace an accepted guest stage', () {
    final live = LiveEntity(
      id: 'live-a',
      hostId: 'host-a',
      hostName: 'Host',
      title: 'Live',
      category: 'General',
      startTime: DateTime(2026, 8, 24),
      metadata: const {'isPk': true, 'layout': 'GRID'},
    );
    final state = LiveViewerState(session: LiveSessionEntity(live: live));

    expect(state.isPk, isFalse);
  });

  test('battle opponent maps the documented live/user shape', () {
    final opponent = LiveBattleOpponent.fromJson({
      'live': {
        'id': 'live-b',
        'title': 'مساء الخير',
        'viewers': 102,
        'user': {
          'id': 'user-b',
          'fullName': 'صاحب البث',
          'avatarUrl': 'https://example.test/avatar.jpg',
        },
      },
    });

    expect(opponent.liveId, 'live-b');
    expect(opponent.hostName, 'صاحب البث');
    expect(opponent.viewers, 102);
  });
}
