import 'dart:convert';

import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/core/services/live_operation_guard.dart';
import 'package:bimobondapp/features/live/data/datasources/fan_club_remote_datasource.dart';
import 'package:bimobondapp/features/live/data/repositories/fan_club_repository_impl.dart';
import 'package:bimobondapp/features/live/domain/entities/fan_club.dart';
import 'package:bimobondapp/features/live/domain/usecases/add_fan_club_emote.dart';
import 'package:bimobondapp/features/live/domain/usecases/get_fan_club.dart';
import 'package:bimobondapp/features/live/domain/usecases/get_fan_club_members.dart';
import 'package:bimobondapp/features/live/domain/usecases/get_my_fan_clubs.dart';
import 'package:bimobondapp/features/live/domain/usecases/subscribe_fan_club.dart';
import 'package:bimobondapp/features/live/domain/usecases/unsubscribe_fan_club.dart';
import 'package:bimobondapp/features/live/domain/usecases/update_fan_club.dart';
import 'package:bimobondapp/features/live/presentation/bloc/fan_club/fan_club_bloc.dart';
import 'package:bimobondapp/features/live/presentation/bloc/fan_club/fan_club_event.dart';
import 'package:bimobondapp/features/live/presentation/bloc/fan_club/fan_club_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemoryOperationStore implements LiveOperationStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

/// One club payload in the documented shape (`lives/live-p0-parity.md` §4).
String _clubBody({
  String? myTier,
  bool withPrices = true,
  String loyalty = '3',
}) {
  return jsonEncode({
    'enabled': true,
    'name': 'Inner Circle',
    'memberCount': 12,
    'isMember': myTier != null,
    'priceCoins': 50,
    'tiers': [
      {'slug': 'PREMIUM', 'name': 'Premium', if (withPrices) 'priceCoins': 300},
      {'slug': 'BASIC', 'name': 'Basic', if (withPrices) 'priceCoins': 50},
      {'slug': 'PLUS', 'name': 'Plus', if (withPrices) 'priceCoins': 150},
    ],
    'emotes': [
      {
        'code': 'fire',
        'imageUrl': '/uploads/emotes/fire.png',
        'minTier': 'PLUS',
      },
      {'code': 'hi', 'imageUrl': '/uploads/emotes/hi.png', 'minTier': 'BASIC'},
    ],
    if (myTier != null) 'membership': {'tierSlug': myTier, 'loyalty': loyalty},
  });
}

FanClubBloc _bloc({
  required http.Client client,
  required LiveOperationGuard guard,
}) {
  final api = LiveApiClient(httpClient: client);
  final repository = FanClubRepositoryImpl(
    remote: FanClubRemoteDataSource(apiClient: api),
  );
  return FanClubBloc(
    getFanClub: GetFanClub(repository),
    getFanClubMembers: GetFanClubMembers(repository),
    getMyFanClubs: GetMyFanClubs(repository),
    subscribeFanClub: SubscribeFanClub(repository),
    unsubscribeFanClub: UnsubscribeFanClub(repository),
    updateFanClub: UpdateFanClub(repository),
    addFanClubEmote: AddFanClubEmote(repository),
    apiClient: api,
    operationGuard: guard,
    userId: () => 'viewer-1',
  );
}

Future<FanClubReady> _loaded(FanClubBloc bloc) async {
  bloc.add(const FanClubLoaded(creatorId: 'creator-1'));
  return await bloc.stream.firstWhere((s) => s is FanClubReady && !s.busy)
      as FanClubReady;
}

void main() {
  group('fan club tiers come from the server', () {
    test('tiers keep documented order and carry the server price', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/members')) {
          return http.Response('{"data":[]}', 200);
        }
        if (request.url.path == '/users/me/fan-clubs') {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(_clubBody(), 200);
      });
      final bloc = _bloc(
        client: client,
        guard: LiveOperationGuard(_MemoryOperationStore()),
      );
      final ready = await _loaded(bloc);

      expect(ready.club.tiers.map((t) => t.slug).toList(), [
        'BASIC',
        'PLUS',
        'PREMIUM',
      ]);
      expect(ready.club.tierBySlug('PLUS')!.priceCoins, 150);
      expect(ready.club.purchasableTiers, hasLength(3));
      await bloc.close();
      client.close();
    });

    test('a tier without a server price is never purchasable', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          fail('A tier with no price must not reach the network.');
        }
        if (request.url.path.endsWith('/members') ||
            request.url.path == '/users/me/fan-clubs') {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(_clubBody(withPrices: false), 200);
      });
      final bloc = _bloc(
        client: client,
        guard: LiveOperationGuard(_MemoryOperationStore()),
      );
      final ready = await _loaded(bloc);

      // Only BASIC keeps a price, from the documented User.fanClubPriceCoins.
      expect(ready.club.tierBySlug('BASIC')!.priceCoins, 50);
      expect(ready.club.tierBySlug('PLUS')!.isPurchasable, isFalse);

      bloc.add(const FanClubSubscribed('PLUS'));
      final next =
          await bloc.stream.firstWhere((s) => s is FanClubReady && !s.busy)
              as FanClubReady;
      expect(next.message, contains('غير متاح'));
      await bloc.close();
      client.close();
    });

    test('emotes unlock by tier rank, never by an unknown slug', () {
      const emote = FanClubEmote(code: 'fire', minTier: 'PLUS');
      expect(emote.unlockedFor('PREMIUM'), isTrue);
      expect(emote.unlockedFor('PLUS'), isTrue);
      expect(emote.unlockedFor('BASIC'), isFalse);
      expect(emote.unlockedFor('VIP'), isFalse);
      expect(emote.unlockedFor(null), isFalse);
    });
  });

  group('fan club subscribe spends coins at most once', () {
    test('sends tierSlug once and re-reads membership after', () async {
      var posts = 0;
      var subscribed = false;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/fan-club/subscribe')) {
          posts++;
          expect(jsonDecode(request.body), {'tierSlug': 'PLUS'});
          subscribed = true;
          return http.Response('{"membership":{"tierSlug":"PLUS"}}', 200);
        }
        if (request.url.path.endsWith('/members') ||
            request.url.path == '/users/me/fan-clubs') {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(
          _clubBody(myTier: subscribed ? 'PLUS' : null),
          200,
        );
      });
      final bloc = _bloc(
        client: client,
        guard: LiveOperationGuard(_MemoryOperationStore()),
      );
      await _loaded(bloc);

      bloc.add(const FanClubSubscribed('PLUS'));
      final next =
          await bloc.stream.firstWhere((s) => s is FanClubReady && !s.busy)
              as FanClubReady;

      expect(posts, 1);
      expect(next.club.myTierSlug, 'PLUS');
      expect(next.unresolvedTierSlug, isNull);
      await bloc.close();
      client.close();
    });

    test(
      'a same-or-higher active tier is not sent as a paid request',
      () async {
        final client = MockClient((request) async {
          if (request.method == 'POST') {
            fail('alreadyMember must not become a charge.');
          }
          if (request.url.path.endsWith('/members') ||
              request.url.path == '/users/me/fan-clubs') {
            return http.Response('{"data":[]}', 200);
          }
          return http.Response(_clubBody(myTier: 'PREMIUM'), 200);
        });
        final bloc = _bloc(
          client: client,
          guard: LiveOperationGuard(_MemoryOperationStore()),
        );
        await _loaded(bloc);

        bloc.add(const FanClubSubscribed('PLUS'));
        final next =
            await bloc.stream.firstWhere((s) => s is FanClubReady && !s.busy)
                as FanClubReady;
        expect(next.message, contains('بالفعل'));
        await bloc.close();
        client.close();
      },
    );

    test(
      'an uncertain purchase is not repeated and reports as unresolved',
      () async {
        var posts = 0;
        final store = _MemoryOperationStore();
        final client = MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/fan-club/subscribe')) {
            posts++;
            // A timeout-shaped failure: the server may well have charged.
            throw http.ClientException('connection closed');
          }
          if (request.url.path.endsWith('/members') ||
              request.url.path == '/users/me/fan-clubs') {
            return http.Response('{"data":[]}', 200);
          }
          return http.Response(_clubBody(), 200);
        });
        final bloc = _bloc(client: client, guard: LiveOperationGuard(store));
        await _loaded(bloc);

        bloc.add(const FanClubSubscribed('PLUS'));
        final failed =
            await bloc.stream.firstWhere((s) => s is FanClubReady && !s.busy)
                as FanClubReady;
        expect(posts, 1);
        expect(failed.unresolvedTierSlug, 'PLUS');
        expect(store.values, isNotEmpty);

        // A second attempt while unresolved must not reach the network again.
        bloc.add(const FanClubSubscribed('PLUS'));
        final blocked =
            await bloc.stream.firstWhere((s) => s is FanClubReady && !s.busy)
                as FanClubReady;
        expect(posts, 1);
        expect(blocked.unresolvedTierSlug, 'PLUS');
        await bloc.close();
        client.close();
      },
    );

    test(
      'a pending record clears once the server shows the membership active',
      () async {
        final store = _MemoryOperationStore();
        final guard = LiveOperationGuard(store);
        final key = LiveOperationGuard.keyFor(
          userId: 'viewer-1',
          liveId: 'fan-club',
          operation: 'fanClubSubscribe',
          entityId: 'creator-1:PLUS',
        );
        store.values[key] = 'pending';

        final client = MockClient((request) async {
          if (request.method == 'POST') {
            fail('Reconciliation must not send another purchase.');
          }
          if (request.url.path.endsWith('/members') ||
              request.url.path == '/users/me/fan-clubs') {
            return http.Response('{"data":[]}', 200);
          }
          // The earlier attempt did land: the viewer is a PLUS member.
          return http.Response(_clubBody(myTier: 'PLUS'), 200);
        });
        final bloc = _bloc(client: client, guard: guard);
        final ready = await _loaded(bloc);

        expect(ready.unresolvedTierSlug, isNull);
        expect(store.values.containsKey(key), isFalse);
        await bloc.close();
        client.close();
      },
    );

    test('a pending record survives when membership is still absent', () async {
      final store = _MemoryOperationStore();
      final key = LiveOperationGuard.keyFor(
        userId: 'viewer-1',
        liveId: 'fan-club',
        operation: 'fanClubSubscribe',
        entityId: 'creator-1:PLUS',
      );
      store.values[key] = 'pending';

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/members') ||
            request.url.path == '/users/me/fan-clubs') {
          return http.Response('{"data":[]}', 200);
        }
        return http.Response(_clubBody(), 200);
      });
      final bloc = _bloc(client: client, guard: LiveOperationGuard(store));
      final ready = await _loaded(bloc);

      expect(ready.unresolvedTierSlug, 'PLUS');
      expect(store.values.containsKey(key), isTrue);
      await bloc.close();
      client.close();
    });
  });

  group('host management', () {
    test('price and name reach PATCH, and a negative price never does', () {
      final api = LiveApiClient(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      final remote = FanClubRemoteDataSource(apiClient: api);
      expect(
        () => remote.updateClub('creator-1', priceCoins: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('adding an emote posts the documented body', () async {
      Map<String, dynamic>? sent;
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 201);
        }
        return http.Response(_clubBody(), 200);
      });
      final repository = FanClubRepositoryImpl(
        remote: FanClubRemoteDataSource(
          apiClient: LiveApiClient(httpClient: client),
        ),
      );
      final club = await repository.addEmote(
        'creator-1',
        code: 'fire',
        imageUrl: '/uploads/emotes/fire.png',
        minTier: 'plus',
      );

      expect(sent, {
        'code': 'fire',
        'imageUrl': '/uploads/emotes/fire.png',
        'minTier': 'PLUS',
      });
      // The refreshed club comes from a re-read, not from a guessed envelope.
      expect(club.emotes, hasLength(2));
      client.close();
    });
  });
}
