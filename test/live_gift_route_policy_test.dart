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
      await tester.pump(const Duration(seconds: 2));
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
}
