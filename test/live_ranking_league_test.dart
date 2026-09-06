import 'package:flutter_test/flutter_test.dart';
import 'package:bimobondapp/features/live/data/mappers/live_host_extras_mapper.dart';

/// Feature 29 — hourly ranking, host league and the Popular badge, parsed from
/// the envelopes documented in `lives/endpoints.md` §19. Nothing here is
/// computed on the client: no promotion, no score, no badge.
void main() {
  group('global hourly leaderboard', () {
    // Verbatim shape from `GET /lives/leaderboard/hourly`.
    final documented = <String, dynamic>{
      'rank': 1,
      'score': 4520,
      'hourlyCoins': 4200,
      'isPopular': true,
      'popularReason': 'hourly_rank',
      'live': {
        'id': '764be4ec-9e90-4828-98e9-4e78280fbe91',
        'title': 'Acoustic Night & Song Requests',
        'viewers': 142,
        'user': {
          'id': 'd748f3b1-e24c-473d-82d2-8b65672abcb7',
          'username': 'sarah_singer',
          'avatarUrl': 'https://cdn.example.com/avatars/sarah.jpg',
          'hostLeagueTier': 'B2',
        },
      },
    };

    test('reads the stream nested under `live`', () {
      final entry = LiveHostExtrasMapper.leaderboardEntryFromJson(documented);
      expect(entry.rank, 1);
      expect(entry.score, 4520);
      expect(entry.coins, 4200);
      // These four all live under `live` and were dropped before.
      expect(entry.liveId, '764be4ec-9e90-4828-98e9-4e78280fbe91');
      expect(entry.title, 'Acoustic Night & Song Requests');
      expect(entry.viewers, 142);
      expect(entry.host?.username, 'sarah_singer');
      expect(entry.userId, 'd748f3b1-e24c-473d-82d2-8b65672abcb7');
      expect(entry.hostLeagueTier, 'B2');
    });

    test('the Popular badge comes from the server, not from viewers', () {
      final entry = LiveHostExtrasMapper.leaderboardEntryFromJson(documented);
      expect(entry.isPopular, true);
      expect(entry.popularReason, 'hourly_rank');

      // A busy stream with no badge stays unbadged.
      final busy = LiveHostExtrasMapper.leaderboardEntryFromJson({
        'rank': 2,
        'live': {'id': 'l-2', 'viewers': 99999},
      });
      expect(busy.isPopular, isNull);
      expect(busy.popularReason, isNull);
      expect(busy.viewers, 99999);
    });

    test('ties keep their server order via the fallback rank', () {
      final first = LiveHostExtrasMapper.leaderboardEntryFromJson({
        'score': 100,
        'live': {'id': 'l-1'},
      }, fallbackRank: 1);
      final second = LiveHostExtrasMapper.leaderboardEntryFromJson({
        'score': 100,
        'live': {'id': 'l-2'},
      }, fallbackRank: 2);
      expect(first.rank, 1);
      expect(second.rank, 2);
    });

    test('missing fields stay null rather than becoming zero', () {
      final entry = LiveHostExtrasMapper.leaderboardEntryFromJson({
        'live': {'id': 'l-9'},
      });
      expect(entry.liveId, 'l-9');
      expect(entry.score, isNull);
      expect(entry.viewers, isNull);
      expect(entry.host, isNull);
      expect(entry.hostLeagueTier, isNull);
    });
  });

  group('gifters leaderboard', () {
    test('keeps reading the flat `user` envelope', () {
      // `GET /lives/:id/leaderboard/gifters` has no `live` wrapper.
      final entry = LiveHostExtrasMapper.leaderboardEntryFromJson({
        'rank': 1,
        'totalCoins': 12500,
        'user': {
          'id': 'u-1',
          'username': 'top_fan',
          'avatarUrl': 'https://cdn.example.com/avatars/topfan.jpg',
          'isVerified': true,
          'gifterLevel': 32,
        },
      });
      expect(entry.rank, 1);
      expect(entry.coins, 12500);
      expect(entry.userId, 'u-1');
      expect(entry.displayName, 'top_fan');
      expect(entry.gifterLevel, 32);
    });
  });

  group('league tiers', () {
    test('reads the documented tier table', () {
      final tiers = LiveHostExtrasMapper.leagueTiersFromJson({
        'tiers': [
          {'tier': 'S', 'minCoins': 5000000, 'minFollowers': 200000},
          {'tier': 'D5', 'minCoins': 0, 'minFollowers': 0},
        ],
      });
      expect(tiers.map((t) => t.tier).toList(), ['S', 'D5']);
      expect(tiers.first.minCoins, 5000000);
      expect(tiers.last.minCoins, 0);
    });

    test('entries without a tier name are dropped', () {
      final tiers = LiveHostExtrasMapper.leagueTiersFromJson({
        'tiers': [
          {'minCoins': 10},
          {'tier': '', 'minCoins': 10},
          {'tier': 'B2'},
        ],
      });
      expect(tiers.length, 1);
      expect(tiers.single.tier, 'B2');
      // An absent threshold is unknown, not zero.
      expect(tiers.single.minCoins, isNull);
    });

    test('a malformed table yields an empty list, not a crash', () {
      expect(LiveHostExtrasMapper.leagueTiersFromJson({'tiers': 'nope'}), []);
      expect(LiveHostExtrasMapper.leagueTiersFromJson({}), []);
    });
  });

  group('host league progress', () {
    test('reads the documented progress envelope', () {
      final league = LiveHostExtrasMapper.hostLeagueFromJson({
        'userId': 'd748f3b1-e24c-473d-82d2-8b65672abcb7',
        'username': 'sarah_singer',
        'hostLeagueTier': 'B2',
        'totalLiveEarnedCoins': 350000,
        'followerCount': 42000,
        'nextTier': 'B1',
        'progressPercentage': 65,
      });
      expect(league!.userId, 'd748f3b1-e24c-473d-82d2-8b65672abcb7');
      expect(league.tier, 'B2');
      expect(league.nextTier, 'B1');
      expect(league.progressPercentage, 65);
      expect(league.hasTier, true);
    });

    test('an unknown tier is reported as unknown', () {
      final league = LiveHostExtrasMapper.hostLeagueFromJson({'userId': 'u-1'});
      expect(league!.hasTier, false);
      expect(league.tier, isNull);
      // No local guess at progress toward a tier we do not know.
      expect(league.progressPercentage, isNull);
      expect(league.nextTier, isNull);
    });

    test('a response without a user id is rejected', () {
      expect(
        LiveHostExtrasMapper.hostLeagueFromJson({'hostLeagueTier': 'S'}),
        isNull,
      );
      expect(LiveHostExtrasMapper.hostLeagueFromJson({}), isNull);
    });
  });
}
