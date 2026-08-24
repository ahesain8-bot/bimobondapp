import 'package:bimobondapp/core/widgets/stage_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _boxWidth = 360.0;
const _boxHeight = _boxWidth / kStageAspect;

Widget tile(String label) => SizedBox.expand(key: ValueKey(label));

Future<List<Rect>> layout(WidgetTester tester, int count) async {
  final labels = [for (var i = 0; i < count; i++) 't$i'];
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: _boxWidth,
            height: _boxHeight,
            child: StageTiles(tiles: [for (final l in labels) tile(l)]),
          ),
        ),
      ),
    ),
  );
  return [for (final l in labels) tester.getRect(find.byKey(ValueKey(l)))];
}

void main() {
  test('shared live box matches the taller TikTok reference proportions', () {
    expect(kStageAspect, closeTo(1.15, 0.001));
  });

  testWidgets('two people split the box down the middle', (tester) async {
    final rects = await layout(tester, 2);

    expect(rects.length, 2);
    expect(
      rects[0].width,
      moreOrLessEquals(rects[1].width, epsilon: 0.5),
      reason: 'host and guest get the same box, not a thumbnail strip',
    );
    expect(rects[0].height, moreOrLessEquals(_boxHeight, epsilon: 0.5));
    expect(rects[1].height, moreOrLessEquals(_boxHeight, epsilon: 0.5));
  });

  testWidgets('the host tile is first, on the left, even in Arabic', (
    tester,
  ) async {
    final rects = await layout(tester, 2);

    expect(
      rects[0].left,
      lessThan(rects[1].left),
      reason: 'the stage must not mirror under RTL',
    );
  });

  testWidgets('three people share one row equally', (tester) async {
    final rects = await layout(tester, 3);

    expect(rects.length, 3);
    for (final r in rects) {
      expect(r.width, moreOrLessEquals(rects.first.width, epsilon: 0.5));
      expect(r.height, moreOrLessEquals(_boxHeight, epsilon: 0.5));
    }
  });

  testWidgets('four people wrap into an even 2x2', (tester) async {
    final rects = await layout(tester, 4);

    expect(rects.length, 4);
    for (final r in rects) {
      expect(r.width, moreOrLessEquals(rects.first.width, epsilon: 0.5));
      expect(r.height, moreOrLessEquals(rects.first.height, epsilon: 0.5));
    }
    // Two distinct rows.
    expect(rects[0].top, moreOrLessEquals(rects[1].top, epsilon: 0.5));
    expect(rects[2].top, greaterThan(rects[0].top));
  });

  testWidgets('five people leave no tile stretched across a row', (
    tester,
  ) async {
    final rects = await layout(tester, 5);

    final boxTop = rects.map((r) => r.top).reduce((a, b) => a < b ? a : b);
    final midline = boxTop + _boxHeight / 2;
    final topRow = rects.where((r) => r.top < midline).toList();
    final bottomRow = rects.where((r) => r.top >= midline).toList();

    expect(topRow.length, 3);
    expect(bottomRow.length, 2);
    for (final r in topRow) {
      expect(r.width, moreOrLessEquals(topRow.first.width, epsilon: 0.5));
    }
  });

  testWidgets('a lone host still fills the whole box', (tester) async {
    final rects = await layout(tester, 1);

    expect(rects.single.width, moreOrLessEquals(_boxWidth, epsilon: 0.5));
  });
}
