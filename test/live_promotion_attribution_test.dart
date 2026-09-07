import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live_viewer/data/datasources/http_live_remote_datasource.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/live_mapper.dart';
import 'package:bimobondapp/features/live_viewer/data/models/live_dto.dart';
import 'package:bimobondapp/features/live_viewer/data/repositories/fake_live_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_feed_activation.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/get_live_feed_usecase.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_feed/live_feed_bloc.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_feed/live_feed_event.dart';

Map<String, dynamic> live({bool promoted = false}) => {
  'id': 'live-1',
  'userId': 'host-1',
  'user': {'id': 'host-1', 'fullName': 'Host'},
  'title': 'Live',
  'status': 'LIVE',
  'startedAt': '2026-09-01T00:00:00Z',
  if (promoted) ...{
    'isPromoted': true,
    'promotion': {'id': 'campaign-1', 'label': 'Promoted'},
  },
};
Map<String, dynamic> joined() => {
  'live': live(),
  'token': 'mock-livekit-token',
  'url': 'wss://example.invalid',
};
HttpLiveRemoteDataSource source(
  Future<http.Response> Function(http.Request) handler,
) => HttpLiveRemoteDataSource(
  apiClient: LiveApiClient(
    httpClient: MockClient(handler),
    idTokenProvider: () async => 'mock-firebase',
  ),
);
void main() {
  test('organic, promoted and missing optional metadata parse and copy', () {
    final organic = LiveMapper.fromJson(live());
    expect(organic.isPromoted, false);
    expect(organic.promotion, isNull);
    final promoted = LiveMapper.fromJson(live(promoted: true));
    expect(promoted.promotion!.id, 'campaign-1');
    expect(promoted.promotion!.label, 'Promoted');
    expect(promoted.copyWith(viewerCount: 42).promotion, promoted.promotion);
    expect(promoted.copyWith(clearPromotion: true).promotion, isNull);
    expect(promoted, isNot(organic));
    expect(promoted.feedEntryKey, isNot(organic.feedEntryKey));
    expect(
      LiveMapper.fromJson({...live(), 'isPromoted': true}).promotion,
      isNull,
    );
    final dto = LiveDto.fromJson({
      ...live(promoted: true),
      'hostId': 'host-1',
      'hostName': 'Host',
    });
    expect(dto.toEntity().promotion!.id, 'campaign-1');
    expect(LiveDto.fromJson(dto.toJson()).promotion, dto.promotion);
  });
  test(
    'each entry consumes once, host/opponent/unknown identity never attributed',
    () {
      final entry = LiveMapper.fromJson(live(promoted: true));
      final a = LiveFeedActivation.fromEntry(entry);
      expect(a.consume(joiningLiveId: 'opponent', viewerId: 'viewer'), isNull);
      expect(
        a.consume(joiningLiveId: entry.id, viewerId: 'viewer'),
        'campaign-1',
      );
      expect(a.consume(joiningLiveId: entry.id, viewerId: 'viewer'), isNull);
      expect(
        LiveFeedActivation.fromEntry(
          entry,
        ).consume(joiningLiveId: entry.id, viewerId: 'viewer'),
        'campaign-1',
      );
      expect(
        LiveFeedActivation.fromEntry(
          entry,
        ).consume(joiningLiveId: entry.id, viewerId: 'host-1'),
        isNull,
      );
      expect(
        LiveFeedActivation.fromEntry(entry).consume(joiningLiveId: entry.id),
        isNull,
      );
      expect(
        LiveFeedActivation.fromEntry(
          LiveMapper.fromJson(live()),
        ).consume(joiningLiveId: entry.id, viewerId: 'viewer'),
        isNull,
      );
    },
  );
  test('exact promoted join body; organic and opponent omit it', () async {
    final requests = <http.Request>[];
    final remote = source((r) async {
      requests.add(r);
      return http.Response(jsonEncode(joined()), 200);
    });
    await remote.joinLive('live-1', campaignId: 'campaign-1');
    await remote.joinLive('live-1');
    await remote.joinLive('opponent');
    expect(requests.first.url.path, endsWith('/lives/live-1/join'));
    expect(jsonDecode(requests.first.body), {'campaignId': 'campaign-1'});
    expect(requests.skip(1).every((r) => r.body.isEmpty), true);
    expect(
      requests.every(
        (r) => r.headers['authorization'] == 'Bearer mock-firebase',
      ),
      true,
    );
  });
  test(
    'billing failure in successful join is tolerated; invalid tokens/auth are not retried',
    () async {
      var calls = 0;
      final remote = source((r) async {
        calls++;
        return http.Response(
          jsonEncode({...joined(), 'billingError': true}),
          200,
        );
      });
      expect(
        (await remote.joinLive(
          'live-1',
          campaignId: 'campaign-1',
        )).liveKitToken,
        isNotEmpty,
      );
      expect(calls, 1);
      for (final status in [200, 401, 403, 404, 500]) {
        var attempts = 0;
        final bad = source((r) async {
          attempts++;
          return http.Response(jsonEncode({'live': live()}), status);
        });
        await expectLater(
          bad.joinLive('live-1', campaignId: 'campaign-1'),
          throwsA(anything),
        );
        expect(attempts, 1);
      }
    },
  );
  test(
    'concurrent organic and promoted joins cannot borrow attribution or open two connections',
    () async {
      final gate = Completer<http.Response>();
      var count = 0;
      final repo = FakeLiveRepository(
        source((r) {
          count++;
          return gate.future;
        }),
      );
      final first = repo.joinLive('live-1');
      await Future<void>.delayed(Duration.zero);
      final promoted = await repo.joinLive('live-1', campaignId: 'campaign-1');
      expect(promoted.isLeft(), true);
      expect(count, 1);
      final same = repo.joinLive('live-1');
      gate.complete(http.Response(jsonEncode(joined()), 200));
      expect((await first).isRight(), true);
      expect((await same).isRight(), true);
      expect(count, 1);
    },
  );
  test(
    'main/filtered feeds have separate cache keys and send no coordinates',
    () async {
      final requests = <http.Request>[];
      final repo = FakeLiveRepository(
        source((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({
              'data': [live()],
              'meta': {'page': 1, 'limit': 10, 'total': 1, 'totalPages': 1},
            }),
            200,
          );
        }),
      );
      await repo.getLiveFeed();
      await repo.getLiveFeed();
      expect(requests.length, 1);
      expect(
        requests[0].url.queryParameters.containsKey('followingOnly'),
        false,
      );
      await repo.getLiveFeed(followingOnly: true);
      await repo.getLiveFeed(category: 'category-1');
      expect(requests.length, 3);
      expect(requests[1].url.queryParameters['followingOnly'], 'true');
      expect(requests[2].url.queryParameters['categoryId'], 'category-1');
      // /lives/feed rejects any param outside page/limit/categoryId/
      // followingOnly — sending coordinates 400s the whole Discover screen.
      expect(
        requests.every(
          (r) =>
              !r.url.queryParameters.containsKey('latitude') &&
              !r.url.queryParameters.containsKey('longitude'),
        ),
        true,
      );
      expect(requests.every((r) => r.method == 'GET'), true);
    },
  );
  test(
    'feed preloading performs no join and keeps organic/promoted occurrences',
    () async {
      final requests = <http.Request>[];
      final repo = FakeLiveRepository(
        source((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({
              'data': [live(), live(promoted: true)],
              'meta': {'page': 1, 'limit': 10, 'total': 2, 'totalPages': 1},
            }),
            200,
          );
        }),
      );
      final bloc = LiveFeedBloc(getLiveFeedUseCase: GetLiveFeedUseCase(repo));
      final loaded = bloc.stream.firstWhere((s) => s.lives.length == 2);
      bloc.add(const LiveFeedLoadRequested(refresh: true));
      await loaded;
      expect(bloc.state.lives.map((e) => e.feedEntryKey).toSet().length, 2);
      expect(requests.every((r) => r.method == 'GET'), true);
      expect(
        requests.single.url.queryParameters.keys.toSet(),
        {'page', 'limit'},
      );
      await bloc.close();
    },
  );
}
