import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bimobondapp/features/live/presentation/widgets/room/live_starting_indicator.dart';

void main() {
  Widget subject({required DateTime deadline, required bool isPublished}) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: LiveStartingIndicator(
          deadline: deadline,
          isPublished: isPublished,
        ),
      ),
    );
  }

  testWidgets('shows publish progress inside the seven-second window', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        deadline: DateTime.now().add(const Duration(seconds: 7)),
        isPublished: false,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('جاري تجهيز البث…'), findsOneWidget);
  });

  testWidgets('hides immediately when media publishing succeeds', (
    tester,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 7));
    await tester.pumpWidget(subject(deadline: deadline, isPublished: false));
    await tester.pumpWidget(subject(deadline: deadline, isPublished: true));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('جاري تجهيز البث…'), findsNothing);
  });

  testWidgets('hides when the seven-second preparation window expires', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        deadline: DateTime.now().add(const Duration(seconds: 7)),
        isPublished: false,
      ),
    );
    await tester.pump(const Duration(seconds: 8));

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
