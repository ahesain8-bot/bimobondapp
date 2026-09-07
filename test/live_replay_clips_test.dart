import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_remote_datasource.dart';
import 'package:bimobondapp/features/live/data/mappers/live_host_extras_mapper.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_media_datasource.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_socket_datasource.dart';
import 'package:bimobondapp/features/live/data/repositories/live_session_repository_impl.dart';
import 'package:bimobondapp/features/live/domain/entities/live_replay.dart';

/// Features 24 (replay) and 25 (clips), against `lives/live-p0-parity.md` §1
/// and `lives/live-p1-parity.md` §5. Recording, storage, expiry, the replay
/// view count and the published post are all server-owned.
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

http.Response ok(Object body) => http.Response(jsonEncode(body), 200);

/// The guards under test live in the repository; socket and media are inert
/// here because no replay or clip path touches them.
LiveSessionRepositoryImpl repoFor(LivesRemoteDataSource remote) =>
    LiveSessionRepositoryImpl(
      remote: remote,
      socket: LivesSocketDataSource(idTokenProvider: () async => null),
      media: LivesMediaDataSource(),
    );

void main() {
  group('replay state is read, never assumed', () {
    // Verbatim from live-p0-parity.md §1.
    final documented = {
      'enabled': true,
      'status': 'READY',
      'available': true,
      'expiresAt': '2026-12-04T10:00:00.000Z',
      'viewCount': 12,
      'url': 'https://cdn.example.com/replay.mp4',
    };

    test('reads the documented replay object', () {
      final replay = LiveHostExtrasMapper.replayFromJson(documented);
      expect(replay.status, LiveReplayStatus.ready);
      expect(replay.enabled, true);
      expect(replay.viewCount, 12);
      expect(replay.expiresAt!.year, 2026);
      expect(replay.isPlayable, true);
    });

    test('accepts the replay nested on the live detail payload', () {
      final replay = LiveHostExtrasMapper.replayFromJson({
        'id': 'live-1',
        'status': 'ENDED',
        'replay': documented,
      });
      expect(replay.status, LiveReplayStatus.ready);
      expect(replay.url, 'https://cdn.example.com/replay.mp4');
    });

    test('a url alone is not permission to play', () {
      // Egress still running: url present, status not READY.
      final preparing = LiveHostExtrasMapper.replayFromJson({
        'enabled': true,
        'status': 'NONE',
        'url': 'https://cdn.example.com/partial.mp4',
      });
      expect(preparing.isPlayable, false);
      expect(preparing.isPreparing, true);

      // The server can refuse a specific viewer even on a READY replay.
      final refused = LiveHostExtrasMapper.replayFromJson({
        ...documented,
        'available': false,
      });
      expect(refused.isPlayable, false);
    });

    test('expired and removed replays are gone, not playable', () {
      for (final status in ['EXPIRED', 'REMOVED']) {
        final replay = LiveHostExtrasMapper.replayFromJson({
          ...documented,
          'status': status,
        });
        expect(replay.isGone, true, reason: status);
        expect(replay.isPlayable, false, reason: status);
      }
    });

    test('an unknown status is never playable', () {
      final replay = LiveHostExtrasMapper.replayFromJson({
        ...documented,
        'status': 'SOMETHING_NEW',
      });
      expect(replay.status, LiveReplayStatus.unknown);
      expect(replay.isPlayable, false);
    });

    test('a missing replay object is no replay, not an error', () {
      expect(LiveHostExtrasMapper.replayFromJson(null).status,
          LiveReplayStatus.none);
      expect(LiveHostExtrasMapper.replayFromJson(null).isPlayable, false);
    });

    test('an empty url is not a playable replay', () {
      final replay = LiveHostExtrasMapper.replayFromJson({
        'status': 'READY',
        'url': '   ',
      });
      expect(replay.isPlayable, false);
    });
  });

  group('replay transport', () {
    test('watch uses GET /lives/<id>/replay with an encoded id', () async {
      final h = harness((r) async => ok({'status': 'READY'}));
      await h.remote.replay('live 1/2');
      expect(h.requests.single.method, 'GET');
      expect(h.requests.single.url.path, '/lives/live%201%2F2/replay');
    });

    test('publish sends only the documented replayUrl body', () async {
      final h = harness((r) async => ok({'status': 'READY'}));
      await h.remote.publishReplay(
        liveId: 'live-1',
        replayUrl: 'https://cdn.example.com/r.mp4',
      );
      final req = h.requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/lives/live-1/replay');
      expect(jsonDecode(req.body), {
        'replayUrl': 'https://cdn.example.com/r.mp4',
      });
    });

    test('takedown uses DELETE', () async {
      final h = harness((r) async => ok({'success': true}));
      await h.remote.deleteReplay('live-1');
      expect(h.requests.single.method, 'DELETE');
      expect(h.requests.single.url.path, '/lives/live-1/replay');
    });

    test('a non-http replay URL is refused before any request', () async {
      final h = harness((r) async => ok({}));
      final repo = repoFor(h.remote);
      for (final bad in ['', '   ', 'javascript:alert(1)', 'not a url']) {
        await expectLater(
          repo.publishReplay(liveId: 'live-1', replayUrl: bad),
          throwsA(isA<ArgumentError>()),
          reason: bad,
        );
      }
      expect(h.requests, isEmpty);
    });
  });

  group('clips', () {
    test('create sends the documented body and encodes the id', () async {
      final h = harness((r) async => ok({'id': 'clip-1', 'status': 'READY'}));
      await h.remote.createClip(
        liveId: 'live-1',
        startSeconds: 42,
        endSeconds: 58,
        title: 'This bit',
      );
      final req = h.requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/lives/live-1/clips');
      expect(jsonDecode(req.body), {
        'startSeconds': 42,
        'endSeconds': 58,
        'title': 'This bit',
      });
    });

    test('an optional clipUrl is included only when given', () async {
      final h = harness((r) async => ok({'id': 'c', 'status': 'READY'}));
      await h.remote.createClip(
        liveId: 'live-1',
        startSeconds: 0,
        endSeconds: 5,
      );
      expect((jsonDecode(h.requests.single.body) as Map).containsKey('clipUrl'),
          false);
    });

    test('invalid bounds never reach the network', () async {
      final h = harness((r) async => ok({}));
      final repo = repoFor(h.remote);
      final cases = <List<num>>[
        [-1, 10],
        [10, 10],
        [20, 5],
      ];
      for (final c in cases) {
        await expectLater(
          repo.createClip(liveId: 'live-1', startSeconds: c[0], endSeconds: c[1]),
          throwsA(isA<ArgumentError>()),
          reason: '$c',
        );
      }
      expect(h.requests, isEmpty);
    });

    test('publish posts to the documented path', () async {
      final h = harness(
        (r) async => ok({'id': 'clip-1', 'status': 'POSTED', 'postId': 'p-1'}),
      );
      await h.remote.postClip(
        liveId: 'live-1',
        clipId: 'clip-1',
        description: 'From tonight',
      );
      final req = h.requests.single;
      expect(req.url.path, '/lives/live-1/clips/clip-1/post');
      expect(jsonDecode(req.body), {'description': 'From tonight'});
    });

    test('a repeated publish is reported, not duplicated', () {
      final clip = LiveHostExtrasMapper.clipFromJson({
        'alreadyPosted': true,
        'clip': {'id': 'clip-1', 'status': 'POSTED', 'postId': 'post-9'},
      });
      expect(clip.alreadyPosted, true);
      expect(clip.postId, 'post-9');
      // clipId, postId and liveId stay distinct identifiers.
      expect(clip.id, 'clip-1');
      expect(clip.isPosted, true);
    });

    test('clip ids and bounds are parsed, missing bounds stay unknown', () {
      final clips = LiveHostExtrasMapper.clipsFromJson({
        'data': [
          {'id': 'c1', 'status': 'PROCESSING', 'startSeconds': 42,
            'endSeconds': 58},
          {'id': 'c2', 'status': 'FAILED'},
          {'status': 'READY'}, // no id: dropped
        ],
      });
      expect(clips.map((c) => c.id).toList(), ['c1', 'c2']);
      expect(clips.first.status, LiveClipStatus.processing);
      expect(clips.first.startSeconds, 42);
      expect(clips[1].startSeconds, isNull);
      expect(clips[1].isPosted, false);
    });

    test('an unknown clip status is not treated as ready or posted', () {
      final clip = LiveHostExtrasMapper.clipFromJson({
        'id': 'c9',
        'status': 'WEIRD',
      });
      expect(clip.status, LiveClipStatus.unknown);
      expect(clip.isPosted, false);
    });

    test('a malformed list is empty, not a crash', () {
      expect(LiveHostExtrasMapper.clipsFromJson({'data': 'nope'}), isEmpty);
      expect(LiveHostExtrasMapper.clipsFromJson({}), isEmpty);
    });
  });
}
