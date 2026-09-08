import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/core/models/live_media_hints.dart';
import 'package:bimobondapp/core/models/live_media_mode.dart';
import 'package:bimobondapp/core/models/live_topic.dart';
import 'package:bimobondapp/core/network/api_endpoints.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_socket_datasource.dart';
import 'package:bimobondapp/features/live/data/mappers/live_session_mapper.dart';
import 'package:bimobondapp/features/live/domain/entities/live_share_result.dart';
import 'package:bimobondapp/features/live/domain/entities/live_studio.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/live_mapper.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/socket_mapper.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/socket_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('host gift combo payload', () {
    test('broadcaster listens to the auctionGiftCombo event alias', () {
      expect(
        LivesSocketDataSource.giftEventNames,
        contains('auctionGiftCombo'),
      );
    });

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
      expect(payload.gift?['imageUrl'], 'https://example.com/rose.png');
    });

    test('normalizes flat large-gift presentation fields', () {
      final payload = GiftComboPayload.fromMap({
        'liveId': 'l1',
        'giftId': 'dragon',
        'giftName': 'Dragon',
        'senderId': 'u1',
        'combo': 2,
        'coins': 500,
        'animationUrl': 'https://example.com/dragon.webm',
        'thumbnailUrl': 'https://example.com/dragon.png',
        'size': 'LARGE',
        'type': 'IMAGE',
      });

      expect(payload, isNotNull);
      expect(payload!.gift?['animationUrl'], 'https://example.com/dragon.webm');
      expect(payload.gift?['thumbnailUrl'], 'https://example.com/dragon.png');
      expect(payload.gift?['size'], 'LARGE');
      expect(payload.combo, 2);
    });

    test('hydrates a flat payload from the existing gift catalog', () {
      final normalized = LivesSocketDataSource.enrichGiftPayloadWithCatalog(
        {
          'liveId': 'l1',
          'giftId': 'dragon',
          'giftName': 'Dragon',
          'senderId': 'u1',
          'combo': 1,
          'coins': 500,
        },
        const GiftEntity(
          id: 'dragon',
          name: 'Dragon',
          icon: 'assets/icons/dragon.png',
          priceCoins: 500,
          animationUrl: 'https://example.com/dragon.webm',
          thumbnailUrl: 'https://example.com/dragon.png',
          size: GiftCatalogSize.large,
        ),
      );
      final payload = GiftComboPayload.fromMap(normalized);

      expect(payload, isNotNull);
      expect(payload!.gift?['animationUrl'], 'https://example.com/dragon.webm');
      expect(payload.gift?['thumbnailUrl'], 'https://example.com/dragon.png');
      expect(payload.gift?['size'], 'LARGE');
      expect(payload.gift?['type'], 'IMAGE');
    });

    test('preserves nested medium gift animation metadata', () {
      final payload = GiftComboPayload.fromMap({
        'liveId': 'l1',
        'giftId': 'star',
        'senderId': 'u1',
        'combo': 1,
        'gift': {
          'id': 'star',
          'name': 'Star',
          'animationUrl': 'https://example.com/star.json',
          'thumbnailUrl': 'https://example.com/star.png',
          'size': 'MEDIUM',
          'type': 'IMAGE',
        },
      });

      expect(payload, isNotNull);
      expect(payload!.gift?['animationUrl'], 'https://example.com/star.json');
      expect(payload.gift?['size'], 'MEDIUM');
    });

    test('normalizes an audio gift through catalog metadata', () {
      final normalized = LivesSocketDataSource.enrichGiftPayloadWithCatalog(
        {'liveId': 'l1', 'giftId': 'sound', 'senderId': 'u1', 'combo': 1},
        const GiftEntity(
          id: 'sound',
          name: 'Sound',
          icon: 'assets/icons/sound.png',
          priceCoins: 100,
          audioUrl: 'https://example.com/sound.mp3',
          color: '#4C8DFF',
          type: GiftCatalogType.audio,
          size: GiftCatalogSize.small,
        ),
      );
      final payload = GiftComboPayload.fromMap(normalized);

      expect(payload, isNotNull);
      expect(payload!.gift?['type'], 'AUDIO');
      expect(payload.gift?['audioUrl'], 'https://example.com/sound.mp3');
      expect(payload.gift?['color'], '#4C8DFF');
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
    test('uses the user fullName for live comments', () {
      final event = SocketMapper.commentEvent({
        'liveId': 'l9',
        'id': 'c9',
        'content': 'Hello',
        'user': {
          'id': 'u9',
          'username': 'user_u9',
          'fullName': 'Viewer Display Name',
        },
      }, null);

      expect(event, isA<LiveCommentEvent>());
      expect(event!.comment.userId, 'u9');
      expect(event.comment.username, 'Viewer Display Name');
    });

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

  group('viewer top supporters socket event', () {
    test('maps the first three real gifter avatars in rank order', () {
      final event = SocketMapper.topGiftersEvent({
        'liveId': 'live-1',
        'window': 'session',
        'data': [
          {
            'rank': 1,
            'user': {'id': 'u1', 'avatarUrl': 'https://cdn.test/one.jpg'},
          },
          {
            'rank': 2,
            'user': {'id': 'u2', 'avatarUrl': 'https://cdn.test/two.jpg'},
          },
          {
            'rank': 3,
            'user': {'id': 'u3', 'avatarUrl': 'https://cdn.test/three.jpg'},
          },
          {
            'rank': 4,
            'user': {'id': 'u4', 'avatarUrl': 'https://cdn.test/four.jpg'},
          },
        ],
      }, null);

      expect(event, isA<LiveTopGiftersUpdatedEvent>());
      expect(event!.avatarUrls, [
        'https://cdn.test/one.jpg',
        'https://cdn.test/two.jpg',
        'https://cdn.test/three.jpg',
      ]);
    });

    test('uses the joined live when the event omits liveId', () {
      final event = SocketMapper.topGiftersEvent({'data': const []}, 'live-2');

      expect(event!.liveId, 'live-2');
      expect(event.avatarUrls, isEmpty);
    });
  });

  group('pause / resume contract', () {
    test('LiveSessionMapper maps paused without changing LIVE status', () {
      final session = LiveSessionMapper.fromLiveJson({
        'id': 'live-1',
        'status': 'LIVE',
        'paused': true,
        'pausedAt': '2026-09-05T12:00:00.000Z',
        'viewers': 12,
        'likeCount': 3,
        'user': {'id': 'h1', 'fullName': 'Host'},
      });

      expect(session.status, 'LIVE');
      expect(session.isLive, isTrue);
      expect(session.paused, isTrue);
    });

    test('SocketMapper maps livePaused { paused, pausedAt }', () {
      final event = SocketMapper.pausedEvent({
        'liveId': 'live-1',
        'paused': true,
        'pausedAt': '2026-09-05T12:00:00.000Z',
      }, null);

      expect(event, isA<LivePausedEvent>());
      expect(event!.liveId, 'live-1');
      expect(event.paused, isTrue);
      expect(event.pausedAt, DateTime.parse('2026-09-05T12:00:00.000Z'));
    });

    test('SocketMapper maps resume as paused: false', () {
      final event = SocketMapper.pausedEvent({
        'paused': false,
      }, 'live-2');

      expect(event!.liveId, 'live-2');
      expect(event.paused, isFalse);
      expect(event.pausedAt, isNull);
    });

    test('LiveMapper keeps status LIVE and exposes paused', () {
      final live = LiveMapper.fromJson({
        'id': 'live-1',
        'status': 'LIVE',
        'paused': true,
        'title': 'Hello',
        'user': {'id': 'h1', 'fullName': 'Host'},
        'startedAt': '2026-09-05T12:00:00.000Z',
      });

      expect(live.status, LiveStatus.live);
      expect(live.isLive, isTrue);
      expect(live.paused, isTrue);
    });
  });

  group('audio rooms / scene / studio contract', () {
    test('LiveMediaMode aliases VOICE and SOUND to AUDIO', () {
      expect(LiveMediaMode.normalize('VOICE'), LiveMediaMode.audio);
      expect(LiveMediaMode.normalize('SOUND'), LiveMediaMode.audio);
      expect(LiveMediaMode.normalize('video'), LiveMediaMode.video);
      expect(LiveMediaMode.isAudio(mediaMode: 'AUDIO'), isTrue);
    });

    test('LiveSessionMapper maps AUDIO mediaMode, audioOnly, PANEL, scene', () {
      final session = LiveSessionMapper.fromLiveJson({
        'id': 'live-1',
        'status': 'LIVE',
        'mediaMode': 'AUDIO',
        'audioOnly': true,
        'layout': 'PANEL',
        'allowGuestCamera': false,
        'scene': {
          'scene': 'CAMERA',
          'cameraFacing': 'front',
          'dualCameraEnabled': false,
        },
        'user': {'id': 'h1', 'fullName': 'Host'},
      });

      expect(session.mediaMode, 'AUDIO');
      expect(session.audioOnly, isTrue);
      expect(session.isAudioOnly, isTrue);
      expect(session.layout, 'PANEL');
      expect(session.scene.scene, 'CAMERA');
    });

    test('LiveMapper audioOnly skips treating the card as camera video', () {
      final live = LiveMapper.fromJson({
        'id': 'live-1',
        'status': 'LIVE',
        'mediaMode': 'VOICE',
        'title': 'Talk',
        'user': {'id': 'h1', 'fullName': 'Host'},
        'startedAt': '2026-09-05T12:00:00.000Z',
      });

      expect(live.mediaMode, 'AUDIO');
      expect(live.audioOnly, isTrue);
      expect(live.isAudioOnly, isTrue);
    });

    test('LiveMapper maps nested scene DUAL + facing', () {
      final live = LiveMapper.fromJson({
        'id': 'live-1',
        'status': 'LIVE',
        'mediaMode': 'VIDEO',
        'scene': {
          'scene': 'DUAL',
          'cameraFacing': 'back',
          'dualCameraEnabled': true,
        },
        'user': {'id': 'h1', 'fullName': 'Host'},
        'startedAt': '2026-09-05T12:00:00.000Z',
      });

      expect(live.scene, 'DUAL');
      expect(live.cameraFacing, 'back');
      expect(live.dualCameraEnabled, isTrue);
    });

    test('LiveMediaHints.fromPayload maps audioOnly host token', () {
      final hints = LiveMediaHints.fromPayload({
        'role': 'host',
        'mediaHints': {
          'role': 'host',
          'canPublish': true,
          'audioOnly': true,
          'maxVideoResolution': null,
          'maxBitrateKbps': 0,
          'simulcast': false,
          'adaptiveStream': false,
          'dynacast': false,
        },
      }, fallbackRole: 'host');

      expect(hints.audioOnly, isTrue);
      expect(hints.canPublish, isTrue);
      expect(hints.maxBitrateKbps, 0);
      expect(hints.simulcast, isFalse);
    });

    test('LiveStudio.fromJson maps RTMP + recording + screenShare', () {
      final studio = LiveStudio.fromJson({
        'rtmpUrl': 'rtmp://livekit.example/live',
        'streamKey': 'sk-secret',
        'ingressId': 'IN_1',
        'recording': {
          'status': 'RECORDING',
          'egressId': 'EG_1',
          'autoRecord': true,
        },
        'screenShare': {'canPublish': true},
      });

      expect(studio, isNotNull);
      expect(studio!.hasRtmpCredentials, isTrue);
      expect(studio.rtmpUrl, 'rtmp://livekit.example/live');
      expect(studio.streamKey, 'sk-secret');
      expect(studio.recordingStatus, 'RECORDING');
      expect(studio.autoRecord, isTrue);
      expect(studio.canPublishScreen, isTrue);
    });

    test('LiveStudio.fromJson missing Ingress is non-fatal empty credentials', () {
      final studio = LiveStudio.fromJson({
        'rtmpUrl': null,
        'streamKey': null,
        'recording': {'status': 'NONE'},
      });

      expect(studio, isNotNull);
      expect(studio!.hasRtmpCredentials, isFalse);
      expect(studio.recordingStatus, 'NONE');
    });

    test('SocketMapper maps liveScene nested or flat payload', () {
      final nested = SocketMapper.sceneEvent({
        'liveId': 'live-1',
        'scene': {
          'scene': 'SCREEN',
          'cameraFacing': 'front',
          'dualCameraEnabled': false,
        },
      }, null);
      expect(nested, isA<LiveSceneChangedEvent>());
      expect(nested!.scene, 'SCREEN');
      expect(nested.cameraFacing, 'front');

      final flat = SocketMapper.sceneEvent({
        'scene': 'DUAL',
        'cameraFacing': 'back',
        'dualCameraEnabled': true,
      }, 'live-2');
      expect(flat!.liveId, 'live-2');
      expect(flat.scene, 'DUAL');
      expect(flat.dualCameraEnabled, isTrue);
    });

    test('SocketMapper maps liveCameraChanged { liveId, userId, facing }', () {
      final event = SocketMapper.cameraChangedEvent({
        'liveId': 'live-1',
        'userId': 'h1',
        'facing': 'back',
        'role': 'host',
      }, null);

      expect(event, isA<LiveCameraChangedEvent>());
      expect(event!.userId, 'h1');
      expect(event.facing, 'back');
      expect(event.role, 'host');
    });
  });

  group('topic / scheduledAt / share contract', () {
    test('LiveTopic.normalize trims and caps at 80', () {
      expect(LiveTopic.normalize('  late night  '), 'late night');
      expect(LiveTopic.normalize('   '), isNull);
      expect(LiveTopic.normalize('x' * 90), 'x' * 80);
    });

    test('LiveSchedule serializes UTC ISO with Z and round-trips local time', () {
      final utc = DateTime.utc(2026, 8, 25, 20, 0);
      expect(LiveSchedule.toUtcIso(utc), '2026-08-25T20:00:00.000Z');

      final local = DateTime(2026, 8, 25, 23, 0);
      final iso = LiveSchedule.toUtcIso(local);
      expect(iso.endsWith('Z'), isTrue);
      final roundTrip = DateTime.parse(iso).toLocal();
      expect(roundTrip.year, local.year);
      expect(roundTrip.month, local.month);
      expect(roundTrip.day, local.day);
      expect(roundTrip.hour, local.hour);
      expect(roundTrip.minute, local.minute);
    });

    test('LiveSessionMapper maps topic, scheduledAt, PLANNED, shareCount', () {
      final session = LiveSessionMapper.fromLiveJson({
        'id': 'live-1',
        'status': 'PLANNED',
        'topic': '  late night radio  ',
        'scheduledAt': '2026-08-25T20:00:00.000Z',
        'shareCount': 42,
        'user': {'id': 'h1', 'fullName': 'Host'},
      });

      expect(session.status, 'PLANNED');
      expect(session.isPlanned, isTrue);
      expect(session.topic, 'late night radio');
      expect(session.scheduledAt, DateTime.parse('2026-08-25T20:00:00.000Z'));
      expect(session.shareCount, 42);
    });

    test('LiveMapper maps PLANNED to scheduled and exposes topic', () {
      final live = LiveMapper.fromJson({
        'id': 'live-1',
        'status': 'PLANNED',
        'topic': 'Q&A',
        'scheduledAt': '2026-08-25T20:00:00.000Z',
        'shareCount': 3,
        'title': 'Tonight',
        'user': {'id': 'h1', 'fullName': 'Host'},
      });

      expect(live.status, LiveStatus.scheduled);
      expect(live.isLive, isFalse);
      expect(live.topic, 'Q&A');
      expect(live.shareCount, 3);
      expect(live.metadata?['topic'], 'Q&A');
      expect(live.metadata?['shareCount'], 3);
      expect(live.scheduledAt, DateTime.parse('2026-08-25T20:00:00.000Z'));
    });

    test('LiveShareResult.fromJson reads shareUrl and shareCount', () {
      final result = LiveShareResult.fromJson({
        'liveId': 'live-1',
        'shareUrl': 'https://app.example.com/lives/live-1',
        'deepLink': 'dcc://lives/live-1',
        'shareCount': 42,
      });
      expect(result.shareUrl, 'https://app.example.com/lives/live-1');
      expect(result.shareCount, 42);
    });
  });

  group('Feature #12 chat rules and moderators', () {
    test('LiveSessionMapper maps chatMode, slowModeSeconds, blockedKeywords', () {
      final session = LiveSessionMapper.fromLiveJson({
        'id': 'live-1',
        'status': 'LIVE',
        'chatMode': 'FOLLOWERS',
        'slowModeSeconds': 5,
        'blockedKeywords': ['badword', 'spam'],
        'user': {'id': 'h1', 'fullName': 'Host'},
      });

      expect(session.chatMode, 'FOLLOWERS');
      expect(session.slowModeSeconds, 5);
      expect(session.blockedKeywords, ['badword', 'spam']);
    });

    test('SocketMapper reads chat_rules_updated chatRules', () {
      final event = SocketMapper.moderationEvent({
        'liveId': 'live-1',
        'type': 'chat_rules_updated',
        'chatRules': {
          'chatMode': 'SUBSCRIBERS',
          'slowModeSeconds': 10,
          'blockedKeywords': ['x'],
        },
      }, 'live-1');

      expect(event, isNotNull);
      expect(event!.moderationType, 'chat_rules_updated');
      expect(event.chatRules?['chatMode'], 'SUBSCRIBERS');
      expect(event.chatRules?['slowModeSeconds'], 10);
    });
  });

  group('Feature #13 maxGuests default and Feature #23 houseId', () {
    test('LiveMapper defaults maxGuests to 8 and maps houseId', () {
      final live = LiveMapper.fromJson({
        'id': 'live-1',
        'status': 'LIVE',
        'houseId': 'house-9',
        'title': 'Campus',
        'user': {'id': 'h1', 'fullName': 'Host'},
        'startedAt': '2026-09-05T12:00:00.000Z',
      });

      expect(live.houseId, 'house-9');
      expect(live.metadata?['houseId'], 'house-9');
      expect(live.metadata?['maxGuests'], 8);
      expect(live.metadata?['moderatorsCanManageGuests'], isTrue);
    });

    test('LiveSessionMapper maps houseId', () {
      final session = LiveSessionMapper.fromLiveJson({
        'id': 'live-1',
        'status': 'LIVE',
        'houseId': 'house-9',
        'user': {'id': 'h1', 'fullName': 'Host'},
      });
      expect(session.houseId, 'house-9');
    });

    test('SocketMapper maps liveHouse attach and close', () {
      final attached = SocketMapper.houseEvent({
        'liveId': 'live-1',
        'houseId': 'house-9',
        'action': 'attached',
      }, 'live-1');
      expect(attached, isNotNull);
      expect(attached!.houseId, 'house-9');
      expect(attached.isClosed, isFalse);

      final closed = SocketMapper.houseEvent({
        'liveId': 'live-1',
        'houseId': 'house-9',
        'status': 'CLOSED',
      }, 'live-1');
      expect(closed!.isClosed, isTrue);
    });
  });

  group('Feature #31 profile currentLive and Feature #32 ageRestricted', () {
    test('LiveMapper maps ageRestricted on the live card', () {
      final live = LiveMapper.fromJson({
        'id': 'live-1',
        'ageRestricted': true,
        'user': {'id': 'host-1', 'fullName': 'Host'},
      });
      expect(live.ageRestricted, isTrue);
      expect(live.metadata?['ageRestricted'], isTrue);
    });

    test('LiveSessionMapper maps ageRestricted', () {
      final session = LiveSessionMapper.fromLiveJson({
        'id': 'live-1',
        'ageRestricted': true,
      });
      expect(session.ageRestricted, isTrue);
    });

    test('LiveMapper.fromProfileCurrentLive reuses LiveEntity fields', () {
      final live = LiveMapper.fromProfileCurrentLive(
        isLive: true,
        currentLive: {
          'id': 'live-9',
          'title': 'Late night',
          'coverUrl': 'https://example.com/c.jpg',
          'viewers': 42,
          'mediaMode': 'AUDIO',
          'audioOnly': true,
        },
        hostId: 'host-1',
        hostName: 'Maya',
        hostAvatar: 'https://example.com/h.jpg',
      );
      expect(live, isNotNull);
      expect(live!.id, 'live-9');
      expect(live.title, 'Late night');
      expect(live.thumbnailUrl, 'https://example.com/c.jpg');
      expect(live.viewerCount, 42);
      expect(live.audioOnly, isTrue);
      expect(live.hostId, 'host-1');
      expect(live.hostName, 'Maya');
    });

    test('LiveMapper.fromProfileCurrentLive is null when not live', () {
      expect(
        LiveMapper.fromProfileCurrentLive(
          isLive: false,
          currentLive: {'id': 'live-9'},
          hostId: 'host-1',
        ),
        isNull,
      );
    });

    test('LiveMapper.fromProfileCurrentLive is null for PLANNED', () {
      expect(
        LiveMapper.fromProfileCurrentLive(
          isLive: true,
          currentLive: {'id': 'live-9', 'status': 'PLANNED'},
          hostId: 'host-1',
        ),
        isNull,
      );
    });

    test('report live path is POST /lives/:id/report', () {
      expect(ApiEndpoints.liveReport('abc'), '/lives/abc/report');
    });
  });
}
