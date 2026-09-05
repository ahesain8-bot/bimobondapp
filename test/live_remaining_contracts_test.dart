import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live/data/datasources/live_interactive_remote_datasource.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_remote_datasource.dart';
import 'package:bimobondapp/features/live/data/mappers/live_interactive_mapper.dart';
import 'package:bimobondapp/features/live/domain/entities/live_interactive.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/socket_mapper.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/socket_event.dart';

void main() {
  test('interactive mapper preserves documented poll shape', () {
    final poll = LiveInteractiveMapper.poll({
      'id': 'poll-1',
      'liveId': 'live-1',
      'question': 'Which?',
      'options': [
        {'text': 'A', 'votes': 3, 'percentage': 60},
        {'text': 'B', 'votes': 2, 'percentage': 40},
      ],
      'totalVotes': 5,
      'status': 'ACTIVE',
      'createdAt': '2026-08-31T10:00:00Z',
    });

    expect(poll.id, 'poll-1');
    expect(poll.options.first.votes, 3);
    expect(poll.options.last.percentage, 40);
    expect(poll.createdAt, isNotNull);
  });

  test('interactive socket mapper retains event and live id', () {
    final event = SocketMapper.interactiveEvent(
      {
        'liveId': 'live-7',
        'id': 'box-1',
        'totalCoins': 100,
        'maxClaims': 5,
        'status': 'WAITING',
      },
      'liveTreasureBoxSpawned',
      null,
    );

    expect(event, isA<LiveInteractiveSocketEvent>());
    expect(event!.liveId, 'live-7');
    expect(event.payload.event, 'liveTreasureBoxSpawned');
  });

  test('gift goal create uses the documented POST body', () async {
    final client = _RecordingClient(
      jsonEncode({
        'id': 'goal-1',
        'giftGoalTitle': 'Reach it',
        'giftGoalTarget': 500,
        'giftGoalCurrent': 40,
      }),
    );
    final source = LiveInteractiveRemoteDataSource(
      apiClient: LiveApiClient(httpClient: client),
    );

    final goal = await source.createGiftGoal(
      liveId: 'live-1',
      title: 'Reach it',
      target: 500,
    );

    expect(client.request!.method, 'POST');
    expect(client.request!.url.path, '/lives/live-1/gift-goal');
    expect(jsonDecode(client.requestBody), {
      'title': 'Reach it',
      'target': 500,
    });
    expect(goal.current, 40);
  });

  test('chat rules update uses the documented PATCH body', () async {
    final client = _RecordingClient(
      jsonEncode({
        'id': 'live-1',
        'chatMode': 'FOLLOWERS',
        'slowModeSeconds': 5,
        'blockedKeywords': ['spam'],
      }),
    );
    final source = LivesRemoteDataSource(
      apiClient: LiveApiClient(httpClient: client),
    );
    await source.updateChatRules(
      'live-1',
      chatMode: 'FOLLOWERS',
      slowModeSeconds: 5,
      blockedKeywords: ['spam'],
    );
    expect(client.request!.method, 'PATCH');
    expect(client.request!.url.path, '/lives/live-1/chat-rules');
    expect(jsonDecode(client.requestBody), {
      'chatMode': 'FOLLOWERS',
      'slowModeSeconds': 5,
      'blockedKeywords': ['spam'],
    });
  });

  test('admin lives query uses documented filters', () async {
    final client = _RecordingClient(
      jsonEncode({
        'data': [],
        'meta': {'total': 0, 'page': 2, 'limit': 10, 'totalPages': 0},
      }),
    );
    final source = LiveInteractiveRemoteDataSource(
      apiClient: LiveApiClient(httpClient: client),
    );

    final page = await source.getAdminLives(
      page: 2,
      limit: 10,
      status: 'LIVE',
      userId: 'staff-target',
      search: 'music room',
    );

    expect(client.request!.method, 'GET');
    expect(client.request!.url.path, '/lives/admin/all');
    expect(client.request!.url.queryParameters, {
      'page': '2',
      'limit': '10',
      'status': 'LIVE',
      'userId': 'staff-target',
      'search': 'music room',
    });
    expect(page.items, isEmpty);
  });
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.body);

  final String body;
  http.BaseRequest? request;

  String get requestBody => (request as http.Request).body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      request: request,
    );
  }
}
