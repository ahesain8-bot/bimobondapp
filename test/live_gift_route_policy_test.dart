import 'dart:async';

import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/app/home/presentation/utils/live_gift_route_policy.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/gift_animation_overlay.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/floating_gifts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the current LiveDetails route may render realtime gifts', (
    tester,
  ) async {
    BuildContext? routeContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            routeContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(isRealtimeGiftRouteCurrent(routeContext!), isTrue);
  });

  testWidgets(
    'a covered LiveDetails route drops the gift to avoid duplicate ownership',
    (tester) async {
      BuildContext? routeContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              routeContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(isRealtimeGiftRouteCurrent(routeContext!), isTrue);

      final push = Navigator.of(routeContext!).push<void>(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      );
      await tester.pumpAndSettle();

      // The covered route drops the event immediately, leaving the active live
      // room as the sole visual owner. There is no pending future or timer
      // that can replay it when the route becomes current.
      expect(isRealtimeGiftRouteCurrent(routeContext!), isFalse);

      Navigator.of(routeContext!).pop();
      await push;
      await tester.pumpAndSettle();
      expect(isRealtimeGiftRouteCurrent(routeContext!), isTrue);
    },
  );

  testWidgets(
    'the shared gift layer renders a large gift on the active route',
    (tester) async {
      final payload = GiftComboPayload.fromMap({
        'giftId': 'dragon',
        'senderId': 'viewer-1',
        'giftName': 'Dragon',
        'combo': 1,
        'animationUrl': 'https://example.com/dragon.png',
        'thumbnailUrl': 'https://example.com/dragon.png',
        'size': 'LARGE',
        'type': 'IMAGE',
      });
      expect(payload, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingGiftsLayer(
              recentGifts: const [],
              latestCombo: payload,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GiftAnimationOverlay), findsOneWidget);

      // The image hold timer used to end it here: a LARGE gift whose media is
      // a still — no `animationUrl`, so the thumbnail — was taken off screen
      // about 1.6s in, for the viewer and the broadcaster alike.
      await tester.pump(const Duration(seconds: 6));
      expect(
        find.byType(GiftAnimationOverlay),
        findsOneWidget,
        reason: 'a large gift waits for a tap, not for a timer',
      );

      // Unmounting the layer is the owner teardown that releases the entry.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      await tester.pump();
    },
  );

  testWidgets(
    'disposing the gift layer removes its owned root animation overlay',
    (tester) async {
      final payload = GiftComboPayload.fromMap({
        'giftId': 'lion',
        'senderId': 'viewer-2',
        'giftName': 'Lion',
        'combo': 1,
        'animationUrl': 'https://example.com/lion.png',
        'thumbnailUrl': 'https://example.com/lion.png',
        'size': 'LARGE',
        'type': 'IMAGE',
      });
      expect(payload, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingGiftsLayer(
              recentGifts: const [],
              latestCombo: payload,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(GiftAnimationOverlay), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      await tester.pump();

      expect(find.byType(GiftAnimationOverlay), findsNothing);
    },
  );

  testWidgets(
    'a duplicate socket event does not restart the gift already on screen',
    (tester) async {
      // One send reaches the room as a gift comment, an `auctionGiftCombo` and
      // an `auctionUpdated.lastGift`. Those payloads disagree about the
      // sender's display name, so the later ones used to tear down the running
      // animation and start it over — visible as a gift that plays for about a
      // second and vanishes.
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final owner = Object();
      Future<void> send(String senderName) => GiftAnimationOverlay.show(
            ctx,
            animationUrl: 'https://example.com/car-gold.png',
            thumbnailUrl: 'https://example.com/car-gold.png',
            senderName: senderName,
            giftName: 'CAR GOLD',
            size: 'LARGE',
            owner: owner,
            dedupeKey: 'car-gold|sender-1',
          );

      unawaited(send('Rashee'));
      await tester.pump();
      final first = tester.widget<GiftAnimationOverlay>(
        find.byType(GiftAnimationOverlay),
      );

      // Same gift, same sender, different display name — the duplicate.
      unawaited(send('User'));
      await tester.pump();

      expect(find.byType(GiftAnimationOverlay), findsOneWidget);
      expect(
        identical(
          tester.widget<GiftAnimationOverlay>(
            find.byType(GiftAnimationOverlay),
          ),
          first,
        ),
        isTrue,
        reason: 'the duplicate must not replace the running overlay',
      );

      GiftAnimationOverlay.dismiss(owner: owner);
      await tester.pump();
      await tester.pump();
    },
  );

  testWidgets(
    'a different gift still replaces the one on screen',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final owner = Object();
      unawaited(
        GiftAnimationOverlay.show(
          ctx,
          animationUrl: 'https://example.com/car-gold.png',
          giftName: 'CAR GOLD',
          size: 'LARGE',
          owner: owner,
          dedupeKey: 'car-gold|sender-1',
        ),
      );
      await tester.pump();
      final first = tester.widget<GiftAnimationOverlay>(
        find.byType(GiftAnimationOverlay),
      );

      unawaited(
        GiftAnimationOverlay.show(
          ctx,
          animationUrl: 'https://example.com/lolo.png',
          giftName: 'LOLO',
          size: 'LARGE',
          owner: owner,
          dedupeKey: 'lolo|sender-2',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(GiftAnimationOverlay), findsOneWidget);
      expect(
        identical(
          tester.widget<GiftAnimationOverlay>(
            find.byType(GiftAnimationOverlay),
          ),
          first,
        ),
        isFalse,
      );

      GiftAnimationOverlay.dismiss(owner: owner);
      await tester.pump();
      await tester.pump();
    },
  );

  testWidgets(
    'a tap ends a large gift and nothing else does',
    (tester) async {
      // A LARGE gift is presentation the viewer dismisses. It has to outlast
      // every automatic trigger — its own media ending, the image/failure hold
      // timers, the stall watchdog — and come down on a tap and nothing else.
      // The tap is consumed by that dismissal, which is why this no longer
      // asserts the tap also reaches the room underneath.
      late BuildContext ctx;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );

      final owner = Object();
      unawaited(
        GiftAnimationOverlay.show(
          ctx,
          animationUrl: 'https://example.com/car-gold.png',
          giftName: 'CAR GOLD',
          size: 'LARGE',
          owner: owner,
          dedupeKey: 'car-gold|sender-1',
        ),
      );
      await tester.pump();
      expect(find.byType(GiftAnimationOverlay), findsOneWidget);

      // Well past every hold the overlay used to arm.
      await tester.pump(const Duration(seconds: 12));
      expect(
        find.byType(GiftAnimationOverlay),
        findsOneWidget,
        reason: 'no timer or completion callback may end a large gift',
      );

      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      await tester.pump();

      expect(
        find.byType(GiftAnimationOverlay),
        findsNothing,
        reason: 'a tap is the one thing that dismisses it',
      );
    },
  );

  testWidgets(
    'shows a thumbnail while asynchronous gift media is initializing',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GiftAnimationOverlay(
            animationUrl: 'https://example.com/cold-large-gift.json',
            thumbnailUrl: 'https://example.com/cold-large-gift.png',
            size: 'LARGE',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SafeNetworkImage), findsOneWidget);
    },
  );

  testWidgets('large gifts keep the live room visible', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: GiftAnimationOverlay(
          animationUrl: 'https://example.com/large-gift.png',
          size: 'LARGE',
        ),
      ),
    );
    await tester.pump();

    final stage = tester.getSize(
      find.byKey(const ValueKey('gift-animation-stage')),
    );
    expect(stage.width, closeTo(352, 0.1));
    expect(stage.height, closeTo(384, 0.1));
    expect(stage.width, lessThan(400));
    expect(stage.height, lessThan(800 * 0.5));
  });
}
