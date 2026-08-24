import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bimobondapp/features/live_viewer/domain/entities/live_session_entity.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/live_state_overlay.dart';

void main() {
  Widget subject(LiveConnectionState state) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const ColoredBox(color: Colors.black),
            LiveStateOverlay(
              state: state,
              message: 'انقطع الاتصال المباشر',
              reconnectAttempt: 3,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('viewer never sees reconnecting indicator', (tester) async {
    await tester.pumpWidget(subject(LiveConnectionState.reconnecting));

    expect(find.textContaining('Reconnecting'), findsNothing);
    expect(find.textContaining('انقطع'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('viewer never sees network-lost indicator', (tester) async {
    await tester.pumpWidget(subject(LiveConnectionState.networkLost));

    expect(find.textContaining('Network lost'), findsNothing);
    expect(find.textContaining('انقطع'), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
  });

  testWidgets('terminal live-ended state remains visible', (tester) async {
    await tester.pumpWidget(subject(LiveConnectionState.liveEnded));
    await tester.pumpAndSettle();

    expect(find.text('Live ended'), findsOneWidget);
  });
}
