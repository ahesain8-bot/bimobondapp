import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bimobondapp/core/models/live_competition_request.dart';
import 'package:bimobondapp/features/live/presentation/widgets/room/live_room_competition_request_prompt.dart';

void main() {
  const request = LiveCompetitionRequest(
    commentId: 'comment-1',
    userId: 'guest-1',
    displayName: 'Hazem Smawy',
  );

  test('recognizes only the shared competition request payload', () {
    expect(isLiveCompetitionRequest(liveCompetitionRequestContent), isTrue);
    expect(
      isLiveCompetitionRequest('  $liveCompetitionRequestContent  '),
      isTrue,
    );
    expect(isLiveCompetitionRequest('أطلب جولة'), isFalse);
  });

  for (final width in <double>[280, 320, 360, 412]) {
    testWidgets('competition decision is responsive at ${width.toInt()}dp', (
      tester,
    ) async {
      var accepted = false;
      var rejected = false;
      await tester.binding.setSurfaceSize(Size(width, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: LiveRoomCompetitionRequestCard(
                request: request,
                busy: false,
                onRejected: () => rejected = true,
                onAccepted: () => accepted = true,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('competition_request_card')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('competition_accept_button')));
      await tester.pump();
      expect(accepted, isTrue);
      expect(rejected, isFalse);
    });
  }

  testWidgets('busy request cannot be submitted twice', (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveRoomCompetitionRequestCard(
            request: request,
            busy: true,
            onRejected: () {},
            onAccepted: () => accepted = true,
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('competition_accept_button')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('جاري البدء…'), findsOneWidget);
    expect(accepted, isFalse);
  });

  testWidgets('competition decision fits large accessibility text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: LiveRoomCompetitionRequestCard(
            request: request,
            busy: false,
            onRejected: () {},
            onAccepted: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('بدء المنافسة'), findsOneWidget);
  });
}
