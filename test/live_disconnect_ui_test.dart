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

  testWidgets('network-lost state provides recovery actions', (tester) async {
    await tester.pumpWidget(subject(LiveConnectionState.networkLost));
    await tester.pumpAndSettle();

    expect(find.text('Network lost'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Leave'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });

  testWidgets('connected state has no fullscreen grey overlay', (tester) async {
    await tester.pumpWidget(subject(LiveConnectionState.connected));

    expect(find.byType(Positioned), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Connecting'), findsNothing);
    expect(find.text('Loading live'), findsNothing);
  });

  testWidgets('terminal live-ended state remains visible', (tester) async {
    await tester.pumpWidget(subject(LiveConnectionState.liveEnded));
    await tester.pumpAndSettle();

    expect(find.text('Live ended'), findsOneWidget);
  });
}
