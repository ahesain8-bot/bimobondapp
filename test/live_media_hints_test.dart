import 'package:bimobondapp/core/models/live_media_hints.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/live_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveMediaHints', () {
    test('maps nested server policy without replacing it with defaults', () {
      final hints = LiveMediaHints.fromPayload({
        'data': {
          'role': 'GUEST',
          'mediaHints': {
            'canPublish': true,
            'adaptiveStream': false,
            'dynacast': false,
            'simulcast': true,
            'maxVideoResolution': '480p',
            'maxBitrateKbps': 1100,
            'maxSubscribeResolution': '360p',
            'codecPreference': ['vp8', 'h264'],
          },
        },
      });

      expect(hints.role, 'guest');
      expect(hints.canPublish, isTrue);
      expect(hints.adaptiveStream, isFalse);
      expect(hints.dynacast, isFalse);
      expect(hints.maxVideoResolution, '480p');
      expect(hints.maxBitrateKbps, 1100);
      expect(hints.preferredCodec, 'vp8');
      expect((hints.subscribeWidth, hints.subscribeHeight), (640, 360));
    });

    test('viewer fallback is subscribe-only', () {
      final hints = LiveMediaHints.fromPayload(
        const {},
        fallbackRole: 'viewer',
      );

      expect(hints.role, 'viewer');
      expect(hints.canPublish, isFalse);
      expect(hints.maxBitrateKbps, 0);
      expect(hints.maxSubscribeResolution, '720p');
    });

    test('guest fallback always enables publish with the guest cap', () {
      final hints = LiveMediaHints.fromPayload(const {}, fallbackRole: 'guest');

      expect(hints.canPublish, isTrue);
      expect(hints.maxVideoResolution, '480p');
      expect(hints.maxBitrateKbps, 1200);
    });
  });

  test('live mapper keeps backend layout and guest camera settings', () {
    final live = LiveMapper.fromJson({
      'id': 'live-1',
      'userId': 'host-1',
      'status': 'LIVE',
      'layout': 'grid',
      'guestsEnabled': true,
      'allowGuestCamera': false,
      'maxGuests': 4,
    });

    expect(live.metadata?['layout'], 'GRID');
    expect(live.metadata?['guestsEnabled'], isTrue);
    expect(live.metadata?['allowGuestCamera'], isFalse);
    expect(live.metadata?['maxGuests'], 4);
  });
}
