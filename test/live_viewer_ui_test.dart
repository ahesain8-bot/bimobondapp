import 'package:bimobondapp/features/live_viewer/data/services/fake_livekit_service.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/guest_repository.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/tiktok_live_chrome.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/comment_input_bar.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/tiktok_live_tokens.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/viewer_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LiveEntity _live({String layout = 'PANEL', String hostName = 'Host'}) =>
    LiveEntity(
      id: 'live-1',
      hostId: 'host-1',
      hostName: hostName,
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

void _noop(String _) {}

void main() {
  testWidgets('focused comment composer keeps a fixed layout height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CommentInputBar(onSend: _noop)),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(CommentInputBar)).height,
      TikTokLiveTokens.inputH,
    );
  });

  testWidgets('top bar displays the full real host name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: TikTokLiveTopBar(
              live: _live(hostName: 'Full Host Name'),
              topViewerAvatars: const [],
              onFollow: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Full Host Name'), findsOneWidget);
  });

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
    expect(find.text('Comment'), findsOneWidget);
    expect(find.text('🌹'), findsOneWidget);
    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);
    expect(find.byIcon(Icons.reply_rounded), findsOneWidget);

    final input = tester.getRect(find.text('Comment'));
    final gift = tester.getRect(find.byIcon(Icons.card_giftcard_rounded));
    final share = tester.getRect(find.byIcon(Icons.reply_rounded));
    expect(input.left, lessThan(gift.left));
    expect(share.left, lessThan(gift.left));
  });

  testWidgets('stale GRID layout cannot turn a guest into a battle', (
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
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(tester.getRect(find.text('Guest')).left, greaterThan(200));
    expect(find.byKey(const ValueKey('tiktok_guest_seat_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('tiktok_guest_seat_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tiktok_guest_seat_2')), findsOneWidget);
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

    final seats = [
      for (var index = 0; index < 3; index++)
        tester.getRect(find.byKey(ValueKey('tiktok_guest_seat_$index'))),
    ];
    expect(seats[0].height, lessThan(150));
    expect(seats[0].height, moreOrLessEquals(seats[1].height, epsilon: 0.5));
    expect(seats[1].height, moreOrLessEquals(seats[2].height, epsilon: 0.5));
    expect(
      seats[1].top,
      greaterThan(seats[0].bottom),
      reason: 'one guest must not stretch across the full side rail',
    );
  });
}
