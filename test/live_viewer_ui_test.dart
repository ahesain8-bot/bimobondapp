import 'package:bimobondapp/features/live_viewer/data/services/fake_livekit_service.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/guest_repository.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/tiktok_live_chrome.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/viewer_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LiveEntity _live({String layout = 'PANEL'}) => LiveEntity(
  id: 'live-1',
  hostId: 'host-1',
  hostName: 'Host',
  title: 'Live',
  category: 'General',
  startTime: DateTime(2026, 8, 24),
  metadata: {'layout': layout},
);

const _guest = GuestSummary(
  userId: 'guest-1',
  displayName: 'Guest',
  role: 'GUEST',
  status: 'ACTIVE',
);

void main() {
  testWidgets('TikTok bottom actions fit and stay LTR on a 320dp phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TikTokLiveBottomBar(
                onTypeTap: () {},
                onGiftTap: () {},
                onShareTap: () {},
                onEmojiTap: () {},
                onMultiGuestTap: () {},
                onRoseTap: () {},
                shareCount: 12,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Type...'), findsOneWidget);
    expect(find.text('🌹'), findsOneWidget);
    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
    expect(find.byIcon(Icons.reply_rounded), findsOneWidget);

    final input = tester.getRect(find.text('Type...'));
    final gift = tester.getRect(find.byIcon(Icons.card_giftcard_rounded));
    final share = tester.getRect(find.byIcon(Icons.reply_rounded));
    expect(input.left, lessThan(gift.left));
    expect(gift.left, lessThan(share.left));
  });

  testWidgets('GRID layout renders host and guest below the live header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final liveKit = FakeLiveKitService();
    addTearDown(liveKit.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ViewerStage(
            live: _live(layout: 'GRID'),
            guests: const [_guest],
            liveKit: liveKit,
            topInset: 120,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(tester.getRect(find.text('Host')).top, greaterThan(120));
    expect(
      tester.getRect(find.text('Host')).left,
      lessThan(tester.getRect(find.text('Guest')).left),
      reason: 'host remains first and on the left even in an Arabic app',
    );
  });

  testWidgets('PANEL layout uses the TikTok guest rail', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final liveKit = FakeLiveKitService();
    addTearDown(liveKit.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ViewerStage(
            live: _live(),
            guests: const [_guest],
            liveKit: liveKit,
            topInset: 100,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(tester.getRect(find.text('Guest')).left, greaterThan(200));
  });
}
