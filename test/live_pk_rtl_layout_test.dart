import 'package:bimobondapp/features/live_viewer/presentation/widgets/tiktok_live_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double kBarWidth = 360;

Future<Rect> pumpBar(
  WidgetTester tester, {
  required TextDirection direction,
  required int scoreLeft,
  required int scoreRight,
  required Finder of,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: kBarWidth,
              child: PkBattleBar(scoreLeft: scoreLeft, scoreRight: scoreRight),
            ),
          ),
        ),
      ),
    ),
  );
  // The seam slides over 420ms; settle it before measuring.
  await tester.pump(const Duration(milliseconds: 600));
  return tester.getRect(of);
}

/// The seam is painted, not a widget, so it is read off the painter.
///
/// [PkSplitPainter] measures its split from the left edge of the canvas, so
/// this is exactly the number a mirrored layout would get wrong.
double seamX(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(PkBattleBar),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PkSplitPainter,
      ),
    ),
  );
  final size = tester.getSize(find.byType(PkBattleBar));
  return (paint.painter as PkSplitPainter).ratio * size.width;
}

void main() {
  testWidgets('the left score stays on the left under Arabic RTL', (
    tester,
  ) async {
    final left = await pumpBar(
      tester,
      direction: TextDirection.rtl,
      scoreLeft: 900,
      scoreRight: 100,
      of: find.text('900'),
    );
    final right = tester.getRect(find.text('100'));

    expect(
      left.left,
      lessThan(right.left),
      reason: 'the bar must not mirror: B2 owns the left half in every locale',
    );
  });

  testWidgets('RTL and LTR lay the bar out identically', (tester) async {
    final ltr = await pumpBar(
      tester,
      direction: TextDirection.ltr,
      scoreLeft: 900,
      scoreRight: 100,
      of: find.text('900'),
    );
    final rtl = await pumpBar(
      tester,
      direction: TextDirection.rtl,
      scoreLeft: 900,
      scoreRight: 100,
      of: find.text('900'),
    );

    expect(rtl, ltr);
  });

  testWidgets('the seam rides the score split, not the mirrored one', (
    tester,
  ) async {
    // 900 v 100 puts the split at 90% of the bar, measured from the left.
    await pumpBar(
      tester,
      direction: TextDirection.rtl,
      scoreLeft: 900,
      scoreRight: 100,
      of: find.text('900'),
    );

    // Anchor on the painted pink side itself rather than a bare fraction: if
    // the bar mirrored, the 900 side would own the right half and the seam
    // would land at 10% instead of 90%.
    final seam = seamX(tester);

    expect(
      seam,
      closeTo(kBarWidth * 0.9, 3.0),
      reason: 'the split is measured from the left edge, so the bar must be '
          'painted from the left edge in every locale',
    );
  });

  testWidgets('neither side is ever squeezed out entirely', (tester) async {
    await pumpBar(
      tester,
      direction: TextDirection.rtl,
      scoreLeft: 100000,
      scoreRight: 0,
      of: find.text('100,000'),
    );

    final seamShare = seamX(tester) / kBarWidth;

    expect(seamShare, lessThan(1.0));
    expect(seamShare, greaterThan(0.9));
  });
}
