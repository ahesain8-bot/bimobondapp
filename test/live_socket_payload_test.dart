import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/features/live/data/mappers/live_session_mapper.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/socket_mapper.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/socket_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('host gift combo payload', () {
    test('accepts the legacy liveGift user alias and nested gift', () {
      final payload = GiftComboPayload.fromMap({
        'liveId': 'l1',
        'id': 'tx1',
        'quantity': 1,
        'user': {
          'id': 'u1',
          'fullName': 'Maya',
          'avatarUrl': 'https://example.com/maya.jpg',
        },
        'gift': {
          'id': 'rose',
          'name': 'Rose',
          'imageUrl': 'https://example.com/rose.png',
        },
      });

      expect(payload, isNotNull);
      expect(payload!.giftId, 'rose');
      expect(payload.senderId, 'u1');
      expect(payload.senderName, 'Maya');
      expect(payload.giftName, 'Rose');
    });
  });

  group('LiveSessionMapper.commentFromJson (host)', () {
    test('reads a plain liveComment payload', () {
      final message = LiveSessionMapper.commentFromJson({
        'id': 'c1',
        'content': 'مرحبا',
        'user': {'id': 'u1', 'fullName': 'Hazem Smawy', 'gifterLevel': 3},
      });

      expect(message.id, 'c1');
      expect(message.body, 'مرحبا');
      expect(message.username, 'Hazem Smawy');
      expect(message.userId, 'u1');
      expect(message.gifterLevel, 3);
    });

    test('unwraps the pinned-comment shape { comment: {...} }', () {
      final message = LiveSessionMapper.commentFromJson({
        'liveId': 'l1',
        'comment': {
          'id': 'c2',
          'content': 'pinned line',
          'isPinned': true,
          'user': {'id': 'u2', 'username': 'viewer_2'},
        },
      });

      expect(message.id, 'c2');
      expect(message.body, 'pinned line');
      expect(message.isPinned, isTrue);
      expect(message.username, 'viewer_2');
    });

    test('prefers the real name over the generated handle', () {
      final message = LiveSessionMapper.commentFromJson({
        'id': 'c3',
        'content': 'hi',
        'user': {'id': 'u3', 'username': 'user_e309173c', 'fullName': 'Maya'},
      });

      expect(message.username, 'Maya');
    });

    test('falls back to the handle when fullName is blank', () {
      final message = LiveSessionMapper.commentFromJson({
        'id': 'c4',
        'content': 'hi',
        'user': {'id': 'u4', 'username': 'user_abc', 'fullName': '   '},
      });

      expect(message.username, 'user_abc');
    });

    test('parses a nested user map that is not Map<String, dynamic>', () {
      // The regression that cost the host every viewer comment: a hard cast on
      // `source['user']` threw inside the Socket.IO handler, Socket.IO
      // swallowed it, and the feed silently stopped filling — while the host's
      // own comments still appeared because those come back over HTTP.
      final message = LiveSessionMapper.commentFromJson({
        'id': 'c6',
        'content': 'من مشاهد',
        'user': <dynamic, dynamic>{'id': 'u6', 'fullName': 'Maya'},
      });

      expect(message.username, 'Maya');
      expect(message.userId, 'u6');
      expect(message.body, 'من مشاهد');
    });

    test('unwraps a nested comment whose own user map is untyped', () {
      final message = LiveSessionMapper.commentFromJson({
        'liveId': 'l1',
        'comment': <dynamic, dynamic>{
          'id': 'c7',
          'content': 'pinned',
          'user': <dynamic, dynamic>{'id': 'u7', 'username': 'viewer_7'},
        },
      });

      expect(message.id, 'c7');
      expect(message.username, 'viewer_7');
    });

    test('survives a payload with no user object at all', () {
      final message = LiveSessionMapper.commentFromJson({
        'id': 'c5',
        'content': 'anonymous line',
      });

      expect(message.body, 'anonymous line');
      expect(message.username, isNull);
    });
  });

  group('viewer SocketMapper guest events', () {
    test('maps liveGuestInvite with the host name and role', () {
      final event = SocketMapper.guestInviteEvent({
        'liveId': 'l9',
        'role': 'CO_HOST',
        'host': {'id': 'h1', 'fullName': 'Hazem Smawy'},
      }, null);

      expect(event, isA<LiveGuestInviteEvent>());
      expect(event!.liveId, 'l9');
      expect(event.hostName, 'Hazem Smawy');
      expect(event.isCoHost, isTrue);
    });

    test('falls back to the current live id when the payload omits one', () {
      final event = SocketMapper.guestInviteEvent({
        'host': {'username': 'host_1'},
      }, 'fallback-live');

      expect(event!.liveId, 'fallback-live');
      expect(event.hostName, 'host_1');
      expect(event.isCoHost, isFalse, reason: 'GUEST is the default role');
    });

    test('drops an invite with no live id to attach it to', () {
      expect(SocketMapper.guestInviteEvent({'role': 'GUEST'}, null), isNull);
    });

    test('maps liveGuestUpdate and pulls the guest user id out', () {
      final event = SocketMapper.guestUpdateEvent({
        'liveId': 'l9',
        'type': 'joined',
        'guest': {
          'role': 'GUEST',
          'user': {'id': 'u7'},
        },
      }, null);

      expect(event!.updateType, 'joined');
      expect(event.guestUserId, 'u7');
      expect(event.affectsStage, isTrue);
    });

    test('a settings update does not count as a stage change', () {
      final event = SocketMapper.guestUpdateEvent({
        'liveId': 'l9',
        'type': 'settings',
        'settings': {'maxGuests': 4},
      }, null);

      expect(event!.affectsStage, isFalse);
    });

    test('drops an update with no type', () {
      expect(SocketMapper.guestUpdateEvent({'liveId': 'l9'}, null), isNull);
    });
  });
}
