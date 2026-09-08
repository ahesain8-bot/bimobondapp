import 'package:bimobondapp/features/live/presentation/widgets/room/live_audio_room_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('host audio stage copy is not a raise-hand button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveAudioRoomStage(hostName: 'Host'),
        ),
      ),
    );

    expect(find.text('ارفع يدك للحديث'), findsOneWidget);
    expect(find.byKey(const ValueKey('audio_raise_hand_cta')), findsNothing);
  });

  testWidgets('viewer audio stage copy opens the shared raise-hand callback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveAudioRoomStage(
            hostName: 'Host',
            onRaiseHand: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('audio_raise_hand_cta')));
    expect(taps, 1);
  });
}
