import 'dart:convert';

import 'package:bimobondapp/core/models/live_battle.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_media_datasource.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_remote_datasource.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_socket_datasource.dart';
import 'package:bimobondapp/features/live/data/mappers/live_cohost_mapper.dart';
import 'package:bimobondapp/features/live/data/repositories/live_session_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Features 20 (team PK / BO3 / power-ups) and 14 (multi-room co-host),
/// against `lives/live-p1-parity.md` §6–§7 and `live-p2-parity.md` §2–§3.
({LivesRemoteDataSource remote, List<http.Request> requests}) harness(
  Future<http.Response> Function(http.Request) handler,
) {
  final requests = <http.Request>[];
  final remote = LivesRemoteDataSource(
    apiClient: LiveApiClient(
      httpClient: MockClient((r) {
        requests.add(r);
        return handler(r);
      }),
      idTokenProvider: () async => 'mock-firebase',
    ),
  );
  return (remote: remote, requests: requests);
}

LiveSessionRepositoryImpl repoFor(LivesRemoteDataSource remote) =>
    LiveSessionRepositoryImpl(
      remote: remote,
      socket: LivesSocketDataSource(idTokenProvider: () async => null),
      media: LivesMediaDataSource(),
    );

/// The 2v2 battle object, verbatim from live-p1-parity.md §7.
const _teamBattle = {
  'id': 'b1',
  'status': 'ACTIVE',
  'phase': 'BATTLE',
  'mode': 'TEAM',
  'live1Id': 'l1',
  'live2Id': 'l2',
  'live3Id': 'l3',
  'live4Id': null,
  'teams': {
    'team1': {'captainLiveId': 'l1', 'teammateLiveId': 'l3'},
    'team2': {'captainLiveId': 'l2', 'teammateLiveId': null},
  },
  'openSlots': [2],
  'live1Score': 40,
  'live2Score': 12,
  'likeScore1': 3,
  'likeScore2': 1,
};

void main() {
  group('the team roster is read from the server', () {
    test('seats, teams and open slots parse as documented', () {
      final battle = LiveBattle.fromJson(
        Map<String, dynamic>.from(_teamBattle),
      );

      expect(battle.isTeamMode, isTrue);
      expect(battle.live3Id, 'l3');
      expect(battle.live4Id, isNull);
      expect(battle.openSlots, [2]);
      expect(battle.teamOf('l1'), 1);
      expect(battle.teamOf('l3'), 1);
      expect(battle.teamOf('l2'), 2);
      expect(battle.teamOf('stranger'), isNull);
      expect(battle.teammateOf('l1'), 'l3');
      expect(battle.teammateOf('l2'), isNull);
      expect(battle.opponentLiveIds('l1'), ['l2']);
      expect(battle.participantLiveIds, ['l1', 'l2', 'l3']);
      expect(battle.likeScore1, 3);
      expect(battle.scoreForTeam(2), 12);
    });

    test('a teammate seat also parses from the teams block alone', () {
      final battle = LiveBattle.fromJson({
        'id': 'b1',
        'status': 'ACTIVE',
        'phase': 'BATTLE',
        'mode': 'TEAM',
        'live1Id': 'l1',
        'live2Id': 'l2',
        'teams': {
          'team1': {'captainLiveId': 'l1', 'teammateLiveId': 'l3'},
          'team2': {'captainLiveId': 'l2', 'teammateLiveId': 'l4'},
        },
      });

      expect(battle.live3Id, 'l3');
      expect(battle.live4Id, 'l4');
      expect(battle.opponentLiveIds('l3'), ['l2', 'l4']);
    });

    test('a solo battle keeps its 1v1 behaviour', () {
      final battle = LiveBattle.fromJson({
        'id': 'b1',
        'status': 'ACTIVE',
        'phase': 'BATTLE',
        'live1Id': 'l1',
        'live2Id': 'l2',
        'live1Score': 5,
        'live2Score': 7,
      });

      expect(battle.isTeamMode, isFalse);
      expect(battle.live3Id, isNull);
      expect(battle.opponentLiveId('l1'), 'l2');
      expect(battle.scoreFor('l2'), 7);
      expect(battle.opponentLiveIds('l1'), ['l2']);
    });

    test('an unknown mode is treated as solo, never as a team', () {
      final battle = LiveBattle.fromJson({
        'id': 'b1',
        'status': 'ACTIVE',
        'phase': 'BATTLE',
        'mode': 'SQUAD',
        'live1Id': 'l1',
        'live2Id': 'l2',
      });

      expect(battle.isTeamMode, isFalse);
    });

    test('a score tick does not collapse a 2v2 into a 1v1', () {
      final full = LiveBattle.fromJson(Map<String, dynamic>.from(_teamBattle));
      // A `score` push carries only the scores.
      final tick = LiveBattle.fromJson({
        'id': 'b1',
        'live1Id': 'l1',
        'live2Id': 'l2',
        'live1Score': 55,
        'live2Score': 12,
        'phase': 'BATTLE',
      });

      final merged = tick.withTimingFrom(full, updateType: 'score');

      expect(merged.live1Score, 55);
      expect(merged.isTeamMode, isTrue);
      expect(merged.live3Id, 'l3');
      expect(merged.openSlots, [2]);
      expect(merged.status, 'ACTIVE');
    });

    test('a roster push that clears a seat is honoured', () {
      final full = LiveBattle.fromJson(Map<String, dynamic>.from(_teamBattle));
      final left = LiveBattle.fromJson({
        'id': 'b1',
        'status': 'ACTIVE',
        'phase': 'BATTLE',
        'mode': 'TEAM',
        'live1Id': 'l1',
        'live2Id': 'l2',
        'live3Id': null,
        'openSlots': [1, 2],
      });

      final merged = left.withTimingFrom(full, updateType: 'roster');

      expect(merged.live3Id, isNull);
      expect(merged.openSlots, [1, 2]);
    });
  });

  group('BO3 and power-ups come from the server', () {
    test('series and power-up fields parse, and stun respects its clock', () {
      final future = DateTime.now().add(const Duration(seconds: 8));
      final battle = LiveBattle.fromJson({
        'id': 'b1',
        'status': 'ACTIVE',
        'phase': 'BATTLE',
        'live1Id': 'l1',
        'live2Id': 'l2',
        'bestOf': 3,
        'roundNumber': 2,
        'wins1': 1,
        'wins2': 0,
        'powerUps': {
          'stunTeam': 2,
          'stunEndsAt': future.toIso8601String(),
          'gloveTeam': 1,
          'gloveCharges': 1,
        },
      });

      expect(battle.bestOf, 3);
      expect(battle.roundNumber, 2);
      expect(battle.wins1, 1);
      expect(battle.powerUps!.stunActiveFor(2), isTrue);
      expect(battle.powerUps!.stunActiveFor(1), isFalse);
      expect(
        battle.powerUps!.stunActiveFor(
          2,
          future.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('an absent series block leaves defaults, not zeros', () {
      final battle = LiveBattle.fromJson({
        'id': 'b1',
        'status': 'ACTIVE',
        'phase': 'BATTLE',
        'live1Id': 'l1',
        'live2Id': 'l2',
      });

      expect(battle.bestOf, 1);
      expect(battle.roundNumber, isNull);
      expect(battle.wins1, isNull);
      expect(battle.powerUps, isNull);
    });
  });

  group('team requests carry the documented bodies', () {
    test('a solo start still omits mode entirely', () async {
      Map<String, dynamic>? body;
      final h = harness((r) async {
        body = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_teamBattle), 201);
      });

      await repoFor(h.remote).startBattle(liveId: 'l1', opponentLiveId: 'l2');

      expect(body!.containsKey('mode'), isFalse);
      expect(body!['opponentLiveId'], 'l2');
    });

    test('a team start sends mode, scoring and optional seats', () async {
      Map<String, dynamic>? body;
      final h = harness((r) async {
        body = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_teamBattle), 201);
      });

      await repoFor(h.remote).startBattle(
        liveId: 'l1',
        opponentLiveId: 'l2',
        teamMode: true,
        scoringMode: 'gifts',
        bestOf: 3,
        teammateLiveId: 'l3',
      );

      expect(body!['mode'], 'TEAM');
      expect(body!['scoringMode'], 'GIFTS');
      expect(body!['bestOf'], 3);
      expect(body!['teammateLiveId'], 'l3');
    });

    test('undocumented series lengths and modes never reach the API', () {
      final h = harness((_) async {
        fail('An invalid battle request must not be sent.');
      });

      expect(
        () =>
            h.remote.startBattle(liveId: 'l1', opponentLiveId: 'l2', bestOf: 5),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => h.remote.startBattle(
          liveId: 'l1',
          opponentLiveId: 'l2',
          mode: 'SQUAD',
        ),
        throwsA(isA<ArgumentError>()),
      );
      // Teammates only make sense in a TEAM battle.
      expect(
        () => h.remote.startBattle(
          liveId: 'l1',
          opponentLiveId: 'l2',
          teammateLiveId: 'l3',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => h.remote.joinBattleTeam(liveId: 'l3', battleId: 'b1', team: 3),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => h.remote.battlePowerUp(
          liveId: 'l1',
          battleId: 'b1',
          type: 'FREEZE',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('join, invite, leave and power-up hit their own paths', () async {
      final paths = <String>[];
      final bodies = <String>[];
      final h = harness((r) async {
        paths.add(r.url.path);
        bodies.add(r.body);
        return http.Response(jsonEncode(_teamBattle), 200);
      });
      final repo = repoFor(h.remote);

      await repo.joinBattleTeam(liveId: 'l3', battleId: 'b1', team: 1);
      await repo.inviteBattleTeammate(
        liveId: 'l1',
        battleId: 'b1',
        teammateLiveId: 'l3',
      );
      await repo.leaveBattleTeam(liveId: 'l3', battleId: 'b1');
      await repo.activateBattlePowerUp(
        liveId: 'l1',
        battleId: 'b1',
        type: 'glove',
      );

      expect(paths, [
        '/lives/l3/battle/b1/join',
        '/lives/l1/battle/b1/invite',
        '/lives/l3/battle/b1/leave',
        '/lives/l1/battle/b1/power-up',
      ]);
      expect(jsonDecode(bodies[0]), {'team': 1});
      expect(jsonDecode(bodies[1]), {'teammateLiveId': 'l3'});
      expect(jsonDecode(bodies[3]), {'type': 'GLOVE'});
    });

    test('open-teams returns the lobbies with their free slots', () async {
      final h = harness((r) async {
        expect(r.url.path, '/lives/l3/battle/open-teams');
        return http.Response(
          jsonEncode({
            'data': [_teamBattle],
          }),
          200,
        );
      });

      final lobbies = await repoFor(h.remote).loadOpenTeamBattles('l3');

      expect(lobbies, hasLength(1));
      expect(lobbies.single.openSlots, [2]);
    });
  });

  group('co-host partner rooms are distinct rooms', () {
    test('cohost and cohosts[] fold into one de-duplicated list', () {
      final payload = LiveCohostMapper.payloadFromJson({
        'cohost': {'liveId': 'p1', 'token': 't1', 'url': 'wss://a'},
        'cohosts': [
          {'liveId': 'p1', 'token': 't1-again', 'url': 'wss://a'},
          {
            'liveId': 'p2',
            'token': 't2',
            'url': 'wss://b',
            'role': 'viewer',
            'host': {'id': 'u2', 'username': 'partner'},
          },
        ],
      }, selfLiveId: 'me');

      expect(payload.rooms.map((r) => r.liveId), ['p1', 'p2']);
      expect(payload.rooms.last.hostName, 'partner');
      expect(payload.rooms.last.role, 'viewer');
    });

    test('cohost video uses only an explicit LiveKit host identity', () {
      final payload = LiveCohostMapper.payloadFromJson({
        'cohost': {
          'liveId': 'partner-live',
          'token': 'subscribe-token',
          'url': 'wss://live.example.test',
          'hostId': 'application-user-id',
          'hostIdentity': 'livekit-host-identity',
        },
      });

      expect(payload.rooms.single.hostId, 'application-user-id');
      expect(payload.rooms.single.hostIdentity, 'livekit-host-identity');
    });

    test('our own room and incomplete entries are never tiled', () {
      final payload = LiveCohostMapper.payloadFromJson({
        'cohosts': [
          {'liveId': 'me', 'token': 't', 'url': 'wss://a'},
          {'liveId': 'p1', 'token': '', 'url': 'wss://a'},
          {'liveId': 'p2', 'url': 'wss://b'},
        ],
      }, selfLiveId: 'me');

      expect(payload.rooms, isEmpty);
    });

    test('at most three partner rooms are tiled', () {
      final payload = LiveCohostMapper.payloadFromJson({
        'cohosts': [
          for (var i = 0; i < 6; i++)
            {'liveId': 'p$i', 'token': 't$i', 'url': 'wss://$i'},
        ],
      });

      expect(payload.rooms, hasLength(3));
    });

    test('sessions and candidates parse with their documented states', () {
      final sessions = LiveCohostMapper.sessionsFromJson({
        'data': [
          {
            'id': 's1',
            'status': 'INVITED',
            'hostLiveId': 'l1',
            'guestLiveId': 'l2',
            'guest': {'id': 'u2', 'username': 'partner'},
          },
          {'id': 's2', 'status': 'ENDED'},
          {'status': 'ACTIVE'},
        ],
      });

      expect(sessions, hasLength(2));
      expect(sessions.first.isPending, isTrue);
      expect(sessions.first.partnerOf('l1'), 'l2');
      expect(sessions.first.partnerOf('other'), isNull);
      expect(sessions.last.status.wireValue, 'ENDED');

      final candidates = LiveCohostMapper.candidatesFromJson({
        'data': [
          {
            'live': {'id': 'l9', 'title': 'Night', 'viewers': 12},
            'user': {'id': 'u9', 'fullName': 'Nine'},
          },
          {
            'user': {'id': 'u10'},
          },
        ],
      });

      expect(candidates, hasLength(1));
      expect(candidates.single.liveId, 'l9');
      expect(candidates.single.viewers, 12);
    });
  });
}
