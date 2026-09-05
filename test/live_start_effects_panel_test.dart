import 'package:bimobondapp/features/live_source/presentation/widgets/start_live/effects_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('effects tray always exposes a close control', (tester) async {
    var closeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EffectsPanel(onClose: () => closeCount++)),
      ),
    );

    await tester.tap(find.byKey(const Key('live_start_effects_close')));
    expect(closeCount, 1);
  });

  testWidgets('search mode retains a way to close the whole tray', (
    tester,
  ) async {
    var closeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EffectsPanel(onClose: () => closeCount++)),
      ),
    );

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('live_start_effects_close_search')));

    expect(closeCount, 1);
  });
}
