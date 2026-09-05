import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_remote_datasource.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_media_datasource.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_socket_datasource.dart';
import 'package:bimobondapp/features/live/data/mappers/live_session_mapper.dart';
import 'package:bimobondapp/features/live/data/repositories/live_session_repository_impl.dart';
import 'package:bimobondapp/features/live_viewer/data/datasources/http_live_remote_datasource.dart';
import 'package:bimobondapp/features/live_viewer/data/repositories/real_live_repository.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_feed/live_feed_bloc.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_feed/live_feed_event.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_feed/live_feed_state.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/get_live_feed_usecase.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/live_card.dart';

void main() {
  test('host repository keeps the server live id and requires LIVE status', () async {
    final repository = LiveSessionRepositoryImpl(
      remote: _StartResponseRemote({
        'live': _DiscoveryClient._live,
        'token': 'host-livekit-token',
        'url': 'wss://livekit.example',
        'role': 'host',
      }),
      socket: LivesSocketDataSource(idTokenProvider: () async => null),
      media: LivesMediaDataSource(),
    );

    final session = await repository.startHostSession(
      title: 'Host A public live',
      coverUrl: 'https://cdn.example/host-a.jpg',
      categoryId: 'music',
    );

    expect(session.id, 'live-host-a');
    expect(session.status, 'LIVE');
    expect(session.isLive, isTrue);
  });

  testWidgets(
    'host start response reaches the default viewer feed and is visible',
    (tester) async {
      final client = _DiscoveryClient();
      final api = LiveApiClient(httpClient: client);

      // Host-side contract: POST /lives carries the exact fields required for
      // a public immediate start.
      final startResponse = await LivesRemoteDataSource(
        apiClient: api,
      ).createAndStart(
        title: 'Host A public live',
        coverUrl: 'https://cdn.example/host-a.jpg',
        categoryId: 'music',
      );
      expect(client.requests.single.method, 'POST');
      expect(client.requests.single.url.path, '/lives');
      expect(jsonDecode(client.requestBodies.single), {
        'title': 'Host A public live',
        'startNow': true,
        'coverUrl': 'https://cdn.example/host-a.jpg',
        'categoryId': 'music',
      });

      final hostLive = Map<String, dynamic>.from(startResponse['live'] as Map);
      final hostSession = LiveSessionMapper.fromLiveJson(
        hostLive,
        liveKitToken: startResponse['token']?.toString(),
        liveKitUrl: startResponse['url']?.toString(),
        liveKitRole: startResponse['role']?.toString(),
      );
      expect(hostSession.id, 'live-host-a');
      expect(hostSession.status, 'LIVE');
      expect(hostSession.isLive, isTrue);

      // Viewer-side production path: HTTP adapter -> LiveMapper -> real
      // repository adapter -> use case -> LiveFeedBloc.
      final viewerSource = HttpLiveRemoteDataSource(apiClient: api);
      final repository = RealLiveRepository(viewerSource);
      final bloc = LiveFeedBloc(
        getLiveFeedUseCase: GetLiveFeedUseCase(repository),
      );
      addTearDown(bloc.close);

      final success = bloc.stream
          .where((state) => state is LiveFeedLoadSuccess)
          .cast<LiveFeedLoadSuccess>()
          .first;
      bloc.add(const LiveFeedLoadRequested(refresh: true));

      final feedState = await success;
      expect(feedState.lives, hasLength(1));
      expect(feedState.lives.single.id, 'live-host-a');
      expect(feedState.lives.single.status.name, 'live');
      expect(feedState.lives.single.hostName, 'Host A');

      final feedRequest = client.requests[1];
      expect(feedRequest.method, 'GET');
      expect(feedRequest.url.path, '/lives/feed');
      // No category and no followingOnly parameter means the documented
      // default For You feed: followingOnly=false.
      expect(feedRequest.url.queryParameters, {
        'page': '1',
        'limit': '20',
      });

      // The actual feed card consumes the same entity that the BLoC emitted.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveCard(live: feedState.lives.single, height: 300),
          ),
        ),
      );
      expect(find.text('@Host A'), findsOneWidget);
      // The card draws the title twice under test: once in the caption row and
      // once in the fallback cover, which stands in for the thumbnail because
      // no image loads here.
      expect(find.text('Host A public live'), findsWidgets);

      // The poster shimmer never settles, so the tree has to go before the
      // test ends.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  test('following-only is sent only when explicitly enabled', () async {
    final client = _DiscoveryClient();
    final source = HttpLiveRemoteDataSource(
      apiClient: LiveApiClient(httpClient: client),
    );

    await source.getLiveFeed(followingOnly: true);

    expect(client.requests.single.url.queryParameters, {
      'page': '1',
      'limit': '20',
      'followingOnly': 'true',
    });
  });
}

class _DiscoveryClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  final requestBodies = <String>[];

  static const _live = <String, dynamic>{
    'id': 'live-host-a',
    'userId': 'host-a',
    'user': {
      'id': 'host-a',
      'fullName': 'Host A',
      'username': 'host_a',
      'avatarUrl': 'https://cdn.example/host-a-avatar.jpg',
    },
    'title': 'Host A public live',
    'status': 'LIVE',
    'viewers': 0,
    'likeCount': 0,
    'categoryId': 'music',
    'categoryName': 'Music',
    'coverUrl': 'https://cdn.example/host-a.jpg',
    'startedAt': '2026-09-01T10:00:00Z',
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (request is http.Request) requestBodies.add(request.body);

    late final Map<String, dynamic> response;
    if (request.method == 'POST' && request.url.path == '/lives') {
      response = {
        'live': _live,
        'token': 'host-livekit-token',
        'url': 'wss://livekit.example',
        'role': 'host',
      };
    } else if (request.method == 'GET' && request.url.path == '/lives/feed') {
      response = {
        'data': [_live],
        'meta': {
          'total': 1,
          'page': int.parse(request.url.queryParameters['page'] ?? '1'),
          'limit': int.parse(request.url.queryParameters['limit'] ?? '20'),
          'totalPages': 1,
        },
      };
    } else {
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    }

    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(response))),
      200,
      request: request,
    );
  }
}

class _StartResponseRemote extends LivesRemoteDataSource {
  _StartResponseRemote(this.response);

  final Map<String, dynamic> response;

  @override
  Future<Map<String, dynamic>> createAndStart({
    required String title,
    String? coverUrl,
    String? categoryId,
  }) async => response;
}
