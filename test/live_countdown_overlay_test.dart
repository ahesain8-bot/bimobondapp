import 'package:bimobondapp/features/live/presentation/widgets/live_countdown_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('embedded live countdown completes after 1, 2, 3', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(home: LiveCountdownLayer(onFinished: () => completed = true)),
    );

    expect(find.text('1'), findsOneWidget);
    expect(completed, isFalse);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('3'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(completed, isTrue);
  });
}
