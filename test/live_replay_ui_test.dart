import 'dart:convert';

import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_media_datasource.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_remote_datasource.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_socket_datasource.dart';
import 'package:bimobondapp/features/live/data/repositories/live_session_repository_impl.dart';
import 'package:bimobondapp/features/live/domain/entities/live_replay.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_replay/live_replay_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Features 24 and 25 at the screen's own layer: how often the view-counting
/// replay read happens, and that nothing publishes without being asked.
({LiveReplayBloc bloc, List<http.Request> requests}) harness(
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
  final repository = LiveSessionRepositoryImpl(
    remote: LivesRemoteDataSource(apiClient: api),
    socket: LivesSocketDataSource(idTokenProvider: () async => null),
    media: LivesMediaDataSource(),
  );
  return (
    bloc: LiveReplayBloc(repository: repository, liveId: 'live-1'),
    requests: requests,
  );
}

int replayReads(List<http.Request> requests) => requests
    .where((r) => r.method == 'GET' && r.url.path == '/lives/live-1/replay')
    .length;

const _readyReplay = {
  'enabled': true,
  'status': 'READY',
  'available': true,
  'expiresAt': '2026-12-04T10:00:00.000Z',
  'viewCount': 12,
  'url': 'https://cdn.example/replay.mp4',
};

void main() {
  group('the view-counting replay read stays under control', () {
    test('opening the screen reads the replay exactly once', () async {
      final h = harness((r) async {
        if (r.url.path.endsWith('/clips')) {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(jsonEncode(_readyReplay), 200);
      });

      h.bloc.add(const LiveReplayOpened());
      await h.bloc.stream.firstWhere((s) => !s.loading && s.replay != null);

      expect(replayReads(h.requests), 1);
      await h.bloc.close();
    });

    test('loading the clip list alone costs no replay view', () async {
      final h = harness((r) async {
        if (r.url.path.endsWith('/clips')) {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(jsonEncode(_readyReplay), 200);
      });

      h.bloc.add(const LiveReplayOpened());
      await h.bloc.stream.firstWhere((s) => !s.loading && s.replay != null);
      final before = replayReads(h.requests);

      h.bloc.add(const LiveReplayClipsRequested());
      await h.bloc.stream.first;

      expect(replayReads(h.requests), before);
      await h.bloc.close();
    });

    test('an explicit refresh is the only extra read', () async {
      final h = harness((r) async {
        if (r.url.path.endsWith('/clips')) {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(jsonEncode(_readyReplay), 200);
      });

      h.bloc.add(const LiveReplayOpened());
      await h.bloc.stream.firstWhere((s) => !s.loading && s.replay != null);
      h.bloc.add(const LiveReplayReloaded());
      await h.bloc.stream.firstWhere((s) => !s.loading);

      expect(replayReads(h.requests), 2);
      await h.bloc.close();
    });

    test('a replay that is not playable never yields a URL', () async {
      final h = harness((r) async {
        if (r.url.path.endsWith('/clips')) {
          return http.Response('{"data":[]}', 200);
        }
        // A URL present while the server says it is not available.
        return http.Response(
          jsonEncode({
            'enabled': true,
            'status': 'READY',
            'available': false,
            'url': 'https://cdn.example/replay.mp4',
          }),
          200,
        );
      });

      h.bloc.add(const LiveReplayOpened());
      final state = await h.bloc.stream.firstWhere(
        (s) => !s.loading && s.replay != null,
      );

      expect(state.replay!.isPlayable, isFalse);
      await h.bloc.close();
    });
  });

  group('clips are created and published only on request', () {
    test('creating a clip sends the chosen bounds once', () async {
      var creates = 0;
      Map<String, dynamic>? body;
      final h = harness((r) async {
        if (r.method == 'POST' && r.url.path == '/lives/live-1/clips') {
          creates++;
          body = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 'clip-1',
              'status': 'READY',
              'startSeconds': 42,
              'endSeconds': 58,
            }),
            201,
          );
        }
        if (r.url.path.endsWith('/clips')) {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(jsonEncode(_readyReplay), 200);
      });

      h.bloc.add(const LiveReplayOpened());
      await h.bloc.stream.firstWhere((s) => !s.loading && s.replay != null);

      h.bloc.add(
        const LiveReplayClipCreated(startSeconds: 42, endSeconds: 58),
      );
      final state = await h.bloc.stream.firstWhere((s) => !s.busy);

      expect(creates, 1);
      expect(body!['startSeconds'], 42);
      expect(body!['endSeconds'], 58);
      expect(state.clips.single.id, 'clip-1');
      // Creating never publishes.
      expect(state.lastPostId, isNull);
      await h.bloc.close();
    });

    test('publishing reports the post id the server returned', () async {
      final h = harness((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/post')) {
          return http.Response(
            jsonEncode({
              'id': 'clip-1',
              'status': 'POSTED',
              'postId': 'post-9',
            }),
            200,
          );
        }
        if (r.url.path.endsWith('/clips')) {
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'clip-1', 'status': 'POSTED', 'postId': 'post-9'},
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode(_readyReplay), 200);
      });

      h.bloc.add(const LiveReplayOpened());
      await h.bloc.stream.firstWhere((s) => !s.loading && s.replay != null);

      h.bloc.add(const LiveReplayClipPosted('clip-1', description: 'tonight'));
      final state = await h.bloc.stream.firstWhere((s) => !s.busy);

      expect(state.lastPostId, 'post-9');
      expect(state.clips.single.isPosted, isTrue);
      await h.bloc.close();
    });

    test(
      'a publish that returns no post id offers no post to open',
      () async {
        final h = harness((r) async {
          if (r.method == 'POST' && r.url.path.endsWith('/post')) {
            // Idempotent repeat, without a post id in the envelope.
            return http.Response(
              jsonEncode({
                'id': 'clip-1',
                'status': 'POSTED',
                'alreadyPosted': true,
              }),
              200,
            );
          }
          if (r.url.path.endsWith('/clips')) {
            return http.Response('{"data":[]}', 200);
          }
          return http.Response(jsonEncode(_readyReplay), 200);
        });

        h.bloc.add(const LiveReplayOpened());
        await h.bloc.stream.firstWhere((s) => !s.loading && s.replay != null);

        h.bloc.add(const LiveReplayClipPosted('clip-1'));
        final state = await h.bloc.stream.firstWhere((s) => !s.busy);

        expect(state.lastPostedClipId, 'clip-1');
        expect(state.lastPostId, isNull);
        await h.bloc.close();
      },
    );

    test('removing the replay re-reads the server lifecycle', () async {
      var deleted = false;
      final h = harness((r) async {
        if (r.method == 'DELETE') {
          deleted = true;
          return http.Response('{}', 200);
        }
        if (r.url.path.endsWith('/clips')) {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(
          jsonEncode(
            deleted ? {'status': 'REMOVED', 'enabled': false} : _readyReplay,
          ),
          200,
        );
      });

      h.bloc.add(const LiveReplayOpened());
      await h.bloc.stream.firstWhere((s) => !s.loading && s.replay != null);

      h.bloc.add(const LiveReplayRemoved());
      final state = await h.bloc.stream.firstWhere(
        (s) => !s.busy && s.replay?.status == LiveReplayStatus.removed,
      );

      expect(state.replay!.isGone, isTrue);
      expect(state.replay!.isPlayable, isFalse);
      await h.bloc.close();
    });
  });
}
