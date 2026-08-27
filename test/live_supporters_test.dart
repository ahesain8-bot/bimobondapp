import 'package:bimobondapp/features/live/data/datasources/lives_socket_datasource.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host.dart';
import 'package:bimobondapp/features/live/domain/entities/live_session.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = LiveSession(
  id: 'live-1',
  host: LiveHost(id: 'h1', displayName: 'Host'),
  viewerCount: 0,
  likeCount: 0,
  galleryCurrent: 0,
  galleryTotal: 0,
  guestInviteCount: 0,
  hourlyRankingLabel: '',
  messages: [],
);

LiveRoomReady ready({
  List<String> supporters = const [],
  List<String> opponentSupporters = const [],
}) => LiveRoomReady(
  session: _session,
  topGifterAvatars: supporters,
  opponentTopGifterAvatars: opponentSupporters,
);

void main() {
  group('host supporter payload', () {
    test('reads avatars in rank order from the wrapped user shape', () {
      final urls = LivesSocketDataSource.avatarUrlsFrom([
        {
          'rank': 1,
          'totalCoins': 900,
          'user': {'id': 'u1', 'avatarUrl': 'https://cdn.test/one.jpg'},
        },
        {
          'rank': 2,
          'totalCoins': 400,
          'user': {'id': 'u2', 'avatarUrl': 'https://cdn.test/two.jpg'},
        },
      ]);

      expect(urls, [
        'https://cdn.test/one.jpg',
        'https://cdn.test/two.jpg',
      ]);
    });

    test('accepts a flattened entry and the legacy `avatar` key', () {
      final urls = LivesSocketDataSource.avatarUrlsFrom([
        {'id': 'u1', 'avatar': 'https://cdn.test/flat.jpg'},
      ]);

      expect(urls, ['https://cdn.test/flat.jpg']);
    });

    test('drops entries with no usable avatar instead of leaving a gap', () {
      final urls = LivesSocketDataSource.avatarUrlsFrom([
        {
          'user': {'id': 'u1', 'avatarUrl': '   '},
        },
        {
          'user': {'id': 'u2'},
        },
        {
          'user': {'id': 'u3', 'avatarUrl': 'https://cdn.test/real.jpg'},
        },
      ]);

      expect(urls, ['https://cdn.test/real.jpg']);
    });

    test('a non-list payload is empty, not an error', () {
      expect(LivesSocketDataSource.avatarUrlsFrom(null), isEmpty);
      expect(LivesSocketDataSource.avatarUrlsFrom({'data': 1}), isEmpty);
    });
  });

  group('host supporter state', () {
    test('starts empty rather than with placeholder faces', () {
      final state = ready();

      expect(state.topGifterAvatars, isEmpty);
      expect(state.opponentTopGifterAvatars, isEmpty);
    });

    test('copyWith without the fields keeps both rings', () {
      final state = ready(
        supporters: const ['a'],
        opponentSupporters: const ['b'],
      ).copyWith(isMicMuted: true);

      expect(state.topGifterAvatars, ['a']);
      expect(state.opponentTopGifterAvatars, ['b']);
    });

    test('each side updates without disturbing the other', () {
      final state = ready(
        supporters: const ['a'],
        opponentSupporters: const ['b'],
      ).copyWith(opponentTopGifterAvatars: const ['c', 'd']);

      expect(state.topGifterAvatars, ['a']);
      expect(state.opponentTopGifterAvatars, ['c', 'd']);
    });
  });
}
