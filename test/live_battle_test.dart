import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:bimobondapp/core/models/live_battle.dart';
import 'package:bimobondapp/core/network/api_exceptions.dart';
import 'package:bimobondapp/features/live/domain/entities/live_battle_errors.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host.dart';
import 'package:bimobondapp/features/live/domain/entities/live_session.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_state.dart';
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

    test('finished socket type and victory phase end the battle', () {
      final active = LiveBattle.fromJson(json);
      final ended = LiveBattle.fromJson({
        ...json,
        'status': '',
        'phase': 'VICTORY_LAP',
      }).normalizedForUpdate(updateType: 'finished');

      expect(active.isActive, isTrue);
      expect(ended.isActive, isFalse);
      expect(ended.isFinished, isTrue);

      final merged = ended.withTimingFrom(active, updateType: 'finished');
      expect(merged.isActive, isFalse);
    });

    test('partial score tick does not resurrect a finished battle', () {
      final finished = LiveBattle.fromJson({
        ...json,
        'status': 'FINISHED',
        'phase': 'VICTORY_LAP',
      });
      final scoreTick = LiveBattle.fromJson({
        ...json,
      }..remove('status'));

      final merged = scoreTick.withTimingFrom(finished);
      expect(merged.isActive, isFalse);
      expect(merged.isFinished, isTrue);
    });

    test('classifies PK API errors without treating them as a crash', () {
      expect(
        isAlreadyInBattleError(
          BadRequestException('already in a battle', statusCode: 400),
        ),
        isTrue,
      );
      expect(
        isNoOpponentsError(
          NotFoundException('No opponents available', statusCode: 404),
        ),
        isTrue,
      );
      expect(
        isEndedLiveStartError(
          BadRequestException('Live already ended', statusCode: 400),
        ),
        isTrue,
      );
      expect(
        noOpponentsMessage(
          NotFoundException('No opponents available', statusCode: 404),
        ),
        contains('لا يوجد'),
      );
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

  test('PK layout waits until opponent media metadata is preloaded', () {
    final battle = LiveBattle.fromJson({
      'id': 'battle-1',
      'live1Id': 'live-a',
      'live2Id': 'live-b',
      'status': 'ACTIVE',
    });
    final waiting = LiveViewerState(battle: battle);
    final opponent = LiveEntity(
      id: 'live-b',
      hostId: 'host-b',
      hostName: 'Opponent',
      hostAvatar: 'https://example.test/opponent.jpg',
      title: 'PK',
      category: 'General',
      startTime: DateTime(2026, 8, 24),
    );

    expect(waiting.isPk, isFalse);
    expect(waiting.copyWith(battleOpponentLive: opponent).isPk, isTrue);
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

  test('battle opponent maps the flat opponents API shape', () {
    final opponent = LiveBattleOpponent.fromJson({
      'id': 'live-opp-1',
      'title': 'Guitar Riffs',
      'viewers': 85,
      'user': {
        'id': 'u-opp-1',
        'username': 'john_guitar',
        'avatarUrl': 'https://cdn.example.com/avatars/john.jpg',
      },
    });

    expect(opponent.liveId, 'live-opp-1');
    expect(opponent.hostName, 'john_guitar');
    expect(opponent.viewers, 85);
  });

  test('empty nested live does not drop a flat opponent id', () {
    final opponent = LiveBattleOpponent.fromJson({
      'live': <String, dynamic>{},
      'id': 'live-flat',
      'title': 'بث',
      'viewers': 3,
      'user': {'id': 'u1', 'fullName': 'Host'},
    });

    expect(opponent.liveId, 'live-flat');
    expect(opponent.hostName, 'Host');
  });

  test(
    'battle Room availability is a state transition independent of battle equality',
    () {
      final battle = LiveBattle.fromJson({
        'id': 'battle-1',
        'live1Id': 'live-a',
        'live2Id': 'live-b',
        'status': 'ACTIVE',
      });
      final beforeRoom = LiveViewerState(battle: battle);
      final room = Room();
      addTearDown(room.dispose);

      final afterRoom = beforeRoom.copyWith(battleRoom: room);

      expect(identical(afterRoom.battle, battle), isTrue);
      expect(beforeRoom.battleRoom, isNull);
      expect(identical(afterRoom.battleRoom, room), isTrue);
      expect(afterRoom, isNot(equals(beforeRoom)));

      final cleared = afterRoom.copyWith(battleRoom: null);
      expect(cleared.battleRoom, isNull);
      final replacement = Room();
      addTearDown(replacement.dispose);
      final replaced = cleared.copyWith(battleRoom: replacement);
      expect(identical(replaced.battleRoom, replacement), isTrue);
    },
  );

  test(
    'host battle Room availability is propagated without changing battle',
    () {
      final battle = LiveBattle.fromJson({
        'id': 'battle-1',
        'live1Id': 'live-a',
        'live2Id': 'live-b',
        'status': 'ACTIVE',
      });
      const session = LiveSession(
        id: 'live-a',
        host: LiveHost(id: 'host-a', displayName: 'Host', avatarUrl: ''),
        viewerCount: 1,
        likeCount: 0,
        galleryCurrent: 0,
        galleryTotal: 0,
        guestInviteCount: 0,
        hourlyRankingLabel: '',
        messages: [],
      );
      final beforeRoom = LiveRoomReady(session: session, battle: battle);
      final room = Room();
      addTearDown(room.dispose);

      final afterRoom = beforeRoom.copyWith(battleMediaRoom: room);

      expect(identical(afterRoom.battle, battle), isTrue);
      expect(identical(afterRoom.battleMediaRoom, room), isTrue);
      expect(afterRoom.copyWith(battleMediaRoom: null).battleMediaRoom, isNull);
    },
  );
}
