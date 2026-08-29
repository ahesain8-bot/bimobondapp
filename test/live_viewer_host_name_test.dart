import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/tiktok_live_chrome.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/tiktok_live_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The viewer top bar must show the real host name, never the avatar initial.
///
/// A `Spacer` beside the host pill's `Flexible` used to claim an equal share of
/// the row's free width, so the pill received about half of what its avatar and
/// follow button alone need. The name was the only flexible part left, so it
/// absorbed the whole deficit and laid out at zero width — leaving the avatar
/// initial as the only glyph in the capsule. A hard `maxWidth` on the name
/// column then truncated it even when the row had room to spare.
///
/// Widths here are tighter than on a device: the test font (Ahem) is roughly
/// twice as wide as a real UI font, which inflates the fixed "Follow" and
/// viewer-count elements that compete with the name.

LiveEntity _live(String hostName) => LiveEntity(
  id: 'live-1',
  hostId: 'host-1',
  hostName: hostName,
  title: 'Live',
  category: 'General',
  viewerCount: 1234,
  likeCount: 13200,
  startTime: DateTime(2026, 8, 24),
);

/// Width the name needs on a single unconstrained line.
double _naturalWidth(String name) {
  final painter = TextPainter(
    text: TextSpan(text: name, style: TikTokLiveTokens.hostName),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

Future<void> _pumpTopBar(
  WidgetTester tester, {
  required String hostName,
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;

  await tester.pumpWidget(
    MaterialApp(
      // The app runs RTL while the top bar pins its own direction, so the name
      // has to survive either one.
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: TikTokLiveTopBar(
            live: _live(hostName),
            // What the bloc really emits: three top-viewer avatars.
            topViewerAvatars: const [
              'https://example.invalid/a0.png',
              'https://example.invalid/a1.png',
              'https://example.invalid/a2.png',
            ],
            onFollow: () {},
            onClose: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

const _names = <String, String>{
  'short latin': 'Sam',
  'multi word latin': 'Salah Al Rashidi',
  'long latin': 'unclesalahalrashidi official',
  'short arabic': 'سعد',
  'multi word arabic': 'محمد الصايغ',
  'long arabic': 'عامل نظافة مغربي في الرياض',
};

void main() {
  testWidgets('the whole host name is the string laid out', (tester) async {
    addTearDown(tester.view.reset);

    for (final entry in _names.entries) {
      for (final width in <double>[360, 412, 720]) {
        await _pumpTopBar(tester, hostName: entry.value, width: width);
        final where = '${entry.key} @${width.toInt()}dp';

        final name = find.text(entry.value);
        expect(
          name,
          findsOneWidget,
          reason: '$where: the real host name must be the string rendered, '
              'not an initial or a substring of it',
        );
        expect(
          tester.getSize(name).width,
          greaterThan(0),
          reason: '$where: the name collapsed, so the avatar initial was the '
              'only glyph left in the pill',
        );
      }
    }
  });

  testWidgets('a long name is not capped while the row still has width', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    for (final name in <String>[
      'unclesalahalrashidi official',
      'عامل نظافة مغربي في الرياض',
    ]) {
      await _pumpTopBar(tester, hostName: name, width: 720);

      expect(
        tester.getSize(find.text(name)).width,
        moreOrLessEquals(_naturalWidth(name), epsilon: 0.5),
        reason: 'a fixed maxWidth truncates a name that still fits',
      );
    }
  });

  testWidgets('the name grows with the width the row really has', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    const long = 'عامل نظافة مغربي في الرياض';

    await _pumpTopBar(tester, hostName: long, width: 360);
    final narrow = tester.getSize(find.text(long)).width;

    await _pumpTopBar(tester, hostName: long, width: 412);
    final wide = tester.getSize(find.text(long)).width;

    expect(
      wide,
      greaterThan(narrow),
      reason:
          "the pill must get the row's whole free width; a competing Spacer "
          'pins the name to a fixed slice of it instead',
    );
  });

  testWidgets('a short name is shown in full beside a live follow button', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    const short = 'محمد الصايغ';

    await _pumpTopBar(tester, hostName: short, width: 720);

    expect(
      tester.getSize(find.text(short)).width,
      moreOrLessEquals(_naturalWidth(short), epsilon: 0.5),
    );
    expect(find.text('Follow'), findsOneWidget);
  });
}
