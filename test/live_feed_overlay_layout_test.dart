import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layout guard for the live-feed overlays in [LiveFeedScreen._buildBody].
///
/// `Positioned` is a `ParentDataWidget<StackParentData>`, so nesting it under a
/// `Column` still type-checks (`children` is `List<Widget>`) and stays invisible
/// to `flutter analyze`. It only breaks when parent data is applied, and the two
/// build modes diverge: debug skips `applyParentData` behind an assert and just
/// logs, while release casts `FlexParentData` to `StackParentData` and throws a
/// `TypeError`. Flutter then swaps the enclosing subtree for `ErrorWidget`,
/// which paints flat grey over the whole video surface.
void main() {
  Widget swipeHint() => Positioned(
        right: 12,
        bottom: 70,
        child: IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.keyboard_arrow_up, size: 22),
              Text('Swipe'),
            ],
          ),
        ),
      );

  Widget feedFilterChip() => Positioned(
        top: 12,
        left: 12,
        child: FilterChip(
          selected: false,
          label: const Text('For You'),
          onSelected: (_) {},
        ),
      );

  Widget subject(List<Widget> children) => MaterialApp(
        home: Scaffold(body: Stack(children: children)),
      );

  testWidgets('feed overlays sit directly under the body Stack',
      (tester) async {
    await tester.pumpWidget(
      subject([
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        swipeHint(),
        feedFilterChip(),
      ]),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Swipe'), findsOneWidget);
    expect(find.text('For You'), findsOneWidget);
  });

  testWidgets('Positioned nested inside the hint Column is rejected',
      (tester) async {
    await tester.pumpWidget(
      subject([
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        Positioned(
          right: 12,
          bottom: 70,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Swipe'),
                feedFilterChip(),
              ],
            ),
          ),
        ),
      ]),
    );

    expect(tester.takeException(), isNotNull);
  });
}
