import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live_viewer/data/datasources/http_live_remote_datasource.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/live_mapper.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live/data/mappers/live_host_extras_mapper.dart';
import 'package:bimobondapp/core/constants/live_traffic_source.dart';

/// Feature 3 (discovery surfaces) and feature 19 (gallery ordering), against
/// the contracts in the refreshed `lives/` package.
HttpLiveRemoteDataSource source(
  Future<http.Response> Function(http.Request) handler,
) => HttpLiveRemoteDataSource(
  apiClient: LiveApiClient(
    httpClient: MockClient(handler),
    idTokenProvider: () async => 'mock-firebase',
  ),
);

Map<String, dynamic> page(List<Map<String, dynamic>> data) => {
  'data': data,
  'meta': {'page': 1, 'limit': 10, 'total': data.length, 'totalPages': 1},
};

Map<String, dynamic> liveRow({String id = 'live-1', String status = 'LIVE'}) => {
  'id': id,
  'userId': 'host-1',
  'title': 'Room',
  'status': status,
  'startedAt': '2026-08-15T12:00:00.000Z',
};

void main() {
  group('discovery surfaces use their own documented endpoints', () {
    test('nearby goes to /lives/nearby, never to the feed query', () async {
      final requests = <http.Request>[];
      final remote = source((r) async {
        requests.add(r);
        return http.Response(jsonEncode(page([liveRow()])), 200);
      });
      await remote.getNearbyFeed(latitude: 30.05, longitude: 31.24);

      final uri = requests.single.url;
      expect(uri.path, '/lives/nearby');
      expect(uri.queryParameters['latitude'], '30.05');
      expect(uri.queryParameters['longitude'], '31.24');
      expect(requests.single.method, 'GET');
    });

    test('radiusKm is clamped to the documented maximum', () async {
      final requests = <http.Request>[];
      final remote = source((r) async {
        requests.add(r);
        return http.Response(jsonEncode(page(const [])), 200);
      });
      await remote.getNearbyFeed(
        latitude: 1,
        longitude: 2,
        radiusKm: 900,
      );
      expect(requests.single.url.queryParameters['radiusKm'], '150');
    });

    test('nearby refuses impossible coordinates before sending', () async {
      var calls = 0;
      final remote = source((r) async {
        calls++;
        return http.Response(jsonEncode(page(const [])), 200);
      });
      await expectLater(
        remote.getNearbyFeed(latitude: 91, longitude: 0),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        remote.getNearbyFeed(latitude: double.nan, longitude: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(calls, 0);
    });

    test('audio goes to /lives/audio and carries topic encoded', () async {
      final requests = <http.Request>[];
      final remote = source((r) async {
        requests.add(r);
        return http.Response(jsonEncode(page(const [])), 200);
      });
      await remote.getAudioFeed(topic: 'راديو الليل');

      final uri = requests.single.url;
      expect(uri.path, '/lives/audio');
      // Arabic survives the round trip; the server does the filtering.
      expect(uri.queryParameters['topic'], 'راديو الليل');
    });

    test('topic on the main feed does not add any other parameter', () async {
      final requests = <http.Request>[];
      final remote = source((r) async {
        requests.add(r);
        return http.Response(jsonEncode(page(const [])), 200);
      });
      await remote.getLiveFeed(topic: 'music');

      final uri = requests.single.url;
      expect(uri.path, '/lives/feed');
      expect(uri.queryParameters.keys.toSet(), {'page', 'limit', 'topic'});
      // The deployed feed rejects coordinates; they belong to /lives/nearby.
      expect(uri.queryParameters.containsKey('latitude'), false);
      expect(uri.queryParameters.containsKey('longitude'), false);
    });

    test('a blank topic is omitted rather than sent empty', () async {
      final requests = <http.Request>[];
      final remote = source((r) async {
        requests.add(r);
        return http.Response(jsonEncode(page(const [])), 200);
      });
      await remote.getLiveFeed(topic: '   ');
      expect(requests.single.url.queryParameters.containsKey('topic'), false);
    });
  });

  group('an unknown live status is not assumed watchable', () {
    test('documented statuses still map as before', () {
      expect(LiveMapper.fromJson(liveRow()).status, LiveStatus.live);
      expect(
        LiveMapper.fromJson(liveRow(status: 'PLANNED')).status,
        LiveStatus.scheduled,
      );
      expect(
        LiveMapper.fromJson(liveRow(status: 'ENDED')).status,
        LiveStatus.ended,
      );
      expect(
        LiveMapper.fromJson(liveRow(status: 'BANNED')).status,
        LiveStatus.banned,
      );
    });

    test('an unrecognised or missing status is not LIVE', () {
      // Previously defaulted to LIVE, which put dead rooms in the active feed.
      expect(
        LiveMapper.fromJson(liveRow(status: 'ARCHIVED')).status,
        isNot(LiveStatus.live),
      );
      final missing = Map<String, dynamic>.from(liveRow())..remove('status');
      expect(LiveMapper.fromJson(missing).status, isNot(LiveStatus.live));
    });
  });

  group('join carries the documented traffic bucket (feature 26)', () {
    Map<String, dynamic> joined() => {
      'live': liveRow(),
      'token': 'tok',
      'url': 'wss://example.invalid',
    };

    test('an organic open sends neither bucket nor campaign', () async {
      final requests = <http.Request>[];
      final remote = source((r) async {
        requests.add(r);
        return http.Response(jsonEncode(joined()), 200);
      });
      await remote.joinLive('live-1');
      expect(requests.single.body.isEmpty, true);
    });

    test('a named surface sends its documented bucket', () async {
      final requests = <http.Request>[];
      final remote = source((r) async {
        requests.add(r);
        return http.Response(jsonEncode(joined()), 200);
      });
      await remote.joinLive(
        'live-1',
        trafficSource: LiveTrafficSource.forYou,
      );
      expect(jsonDecode(requests.single.body), {'trafficSource': 'FOR_YOU'});
    });

    test('a promoted open sends the campaign and lets the server infer', () async {
      final requests = <http.Request>[];
      final remote = source((r) async {
        requests.add(r);
        return http.Response(jsonEncode(joined()), 200);
      });
      await remote.joinLive('live-1', campaignId: 'campaign-1');
      // Documented: campaignId without a bucket means PROMOTE server-side.
      expect(jsonDecode(requests.single.body), {'campaignId': 'campaign-1'});
    });

    test('an unrecognised screen sends nothing rather than a guess', () async {
      final requests = <http.Request>[];
      final remote = source((r) async {
        requests.add(r);
        return http.Response(jsonEncode(joined()), 200);
      });
      await remote.joinLive('live-1', trafficSource: 'HOME_WIDGET');
      expect(requests.single.body.isEmpty, true);
      expect(LiveTrafficSource.normalise('HOME_WIDGET'), isNull);
    });

    test('every documented bucket is accepted and normalised', () {
      for (final bucket in LiveTrafficSource.values) {
        expect(LiveTrafficSource.normalise(bucket.toLowerCase()), bucket);
      }
      expect(LiveTrafficSource.values.contains('FOR_YOU'), true);
      expect(LiveTrafficSource.values.contains('SHARES'), true);
      expect(LiveTrafficSource.normalise('  '), isNull);
      expect(LiveTrafficSource.normalise(null), isNull);
    });
  });

  group('gallery ordering comes from the server', () {
    test('pinned and pinOrder are read from the documented item', () {
      final item = LiveHostExtrasMapper.galleryItemFromJson({
        'id': 'auction-1',
        'itemName': 'Hoodie',
        'pinned': true,
        'pinOrder': 2,
        'status': 'ACTIVE',
      });
      expect(item.id, 'auction-1');
      expect(item.pinned, true);
      expect(item.pinOrder, 2);
    });

    test('a missing pinOrder stays unknown instead of becoming zero', () {
      final item = LiveHostExtrasMapper.galleryItemFromJson({
        'id': 'auction-2',
        'itemName': 'Cap',
      });
      expect(item.pinned, false);
      expect(item.pinOrder, isNull);
    });
  });
}
