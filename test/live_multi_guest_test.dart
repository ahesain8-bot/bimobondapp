import 'package:bimobondapp/features/live/domain/entities/live_guest.dart';
import 'package:bimobondapp/features/live/domain/entities/live_session.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host.dart';
import 'package:bimobondapp/features/live/domain/repositories/live_session_repository.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_state.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/guest_repository.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_state.dart';
import 'package:flutter_test/flutter_test.dart';

LiveGuest hostGuest(String id, String status, {String role = 'GUEST'}) =>
    LiveGuest(
      id: 'g-$id',
      liveId: 'l1',
      userId: id,
      role: role,
      status: status,
      displayName: 'Guest $id',
    );

GuestSummary viewerGuest(String id, String status) => GuestSummary(
  userId: id,
  displayName: 'Guest $id',
  role: 'GUEST',
  status: status,
);

void main() {
  group('host stage roster', () {
    const session = LiveSession(
      id: 'l1',
      title: 'test',
      host: LiveHost(id: 'h1', displayName: 'Host'),
      viewerCount: 0,
      likeCount: 0,
      galleryCurrent: 0,
      galleryTotal: 0,
      guestInviteCount: 0,
      hourlyRankingLabel: '',
      messages: [],
    );

    test('only ACTIVE guests reach the stage', () {
      final state = LiveRoomReady(
        session: session,
        guests: [
          hostGuest('u1', 'ACTIVE'),
          hostGuest('u2', 'REQUESTED'),
          hostGuest('u3', 'INVITED'),
          hostGuest('u4', 'ACTIVE'),
          hostGuest('u5', 'LEFT'),
        ],
      );

      expect(state.activeGuests.map((g) => g.userId), ['u1', 'u4']);
    });

    test('pending covers both REQUESTED and INVITED', () {
      expect(hostGuest('a', 'REQUESTED').isPending, isTrue);
      expect(hostGuest('a', 'INVITED').isPending, isTrue);
      expect(hostGuest('a', 'ACTIVE').isPending, isFalse);
      expect(hostGuest('a', 'LEFT').isPending, isFalse);
    });

    test('an empty roster leaves the stage empty', () {
      expect(const LiveRoomReady(session: session).activeGuests, isEmpty);
    });

    test(
      'realtime starts disconnected so the warning shows until proven up',
      () {
        expect(
          const LiveRoomReady(session: session).isRealtimeConnected,
          isFalse,
        );
      },
    );
  });

  group('guest invite', () {
    test('CO_HOST is recognised case-insensitively', () {
      const invite = LivePendingGuestInvite(
        liveId: 'l1',
        hostName: 'Host',
        role: 'co_host',
      );
      expect(invite.isCoHost, isTrue);
    });

    test('GUEST is not a co-host', () {
      const invite = LivePendingGuestInvite(
        liveId: 'l1',
        hostName: 'Host',
        role: 'GUEST',
      );
      expect(invite.isCoHost, isFalse);
    });
  });

  group('stage credentials', () {
    test('usable only when both url and token are present', () {
      const ok = LiveGuestStageCredentials(
        token: 't',
        url: 'wss://x',
        role: 'GUEST',
      );
      expect(ok.isUsable, isTrue);

      const noToken = LiveGuestStageCredentials(
        token: '',
        url: 'wss://x',
        role: 'GUEST',
      );
      expect(noToken.isUsable, isFalse);

      const noUrl = LiveGuestStageCredentials(
        token: 't',
        url: '',
        role: 'GUEST',
      );
      expect(
        noUrl.isUsable,
        isFalse,
        reason: 'publishing without a url would fail silently',
      );
    });
  });

  group('viewer stage state', () {
    test('only ACTIVE guests render in the viewer grid', () {
      final state = LiveViewerState(
        guests: [
          viewerGuest('u1', 'ACTIVE'),
          viewerGuest('u2', 'REQUESTED'),
          viewerGuest('u3', 'ACTIVE'),
        ],
      );

      expect(state.activeGuests.map((g) => g.userId), ['u1', 'u3']);
    });

    test('a viewer is off stage until they actually publish', () {
      expect(const LiveViewerState().isOnStage, isFalse);
      expect(const LiveViewerState().pendingGuestInvite, isNull);
    });

    test('clearing a pending invite actually removes it', () {
      const state = LiveViewerState(
        pendingGuestInvite: PendingGuestInvite(
          liveId: 'l1',
          hostName: 'Host',
          role: 'GUEST',
        ),
      );

      expect(
        state.copyWith(clearPendingGuestInvite: true).pendingGuestInvite,
        isNull,
      );
    });

    test('copyWith without the clear flag keeps the invite', () {
      const invite = PendingGuestInvite(
        liveId: 'l1',
        hostName: 'Host',
        role: 'GUEST',
      );
      const state = LiveViewerState(pendingGuestInvite: invite);

      expect(state.copyWith(isOnStage: true).pendingGuestInvite, invite);
    });
  });
}
