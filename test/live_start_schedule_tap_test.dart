import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_constants.dart';
import 'package:bimobondapp/features/live/presentation/widgets/start_live/live_start_chrome_actions.dart';
import 'package:bimobondapp/features/live/presentation/widgets/start_live/live_start_info_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveStartChromeMethod', () {
    test('Schedule native method maps to schedule, not cover/image picking', () {
      final action = liveStartChromeActionFor(LiveStartChromeMethod.schedule);
      expect(action, LiveStartChromeAction.schedule);
      expect(action, isNot(LiveStartChromeAction.changeCover));
      expect(liveStartChromeOpensImagePicker(action), isFalse);
    });

    test('cover method is not schedule and does not open an image picker', () {
      final action = liveStartChromeActionFor(
        LiveStartChromeMethod.changeCover,
      );
      expect(action, LiveStartChromeAction.changeCover);
      expect(liveStartChromeOpensImagePicker(action), isFalse);
    });
  });

  testWidgets('Schedule chip fires schedule callback, not cover picking', (
    tester,
  ) async {
    var schedule = 0;
    var cover = 0;
    var imagePicks = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveStartInfoCard(
            titleController: controller,
            onChangeCover: () {
              cover++;
              imagePicks++;
            },
            onSchedule: () => schedule++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('live_start_schedule_chip')));
    await tester.pump();

    expect(schedule, 1);
    expect(cover, 0);
    expect(imagePicks, 0);
  });

  testWidgets('Change cover does not fire the schedule callback', (
    tester,
  ) async {
    var schedule = 0;
    var cover = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveStartInfoCard(
            titleController: controller,
            onChangeCover: () => cover++,
            onSchedule: () => schedule++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('live_start_change_cover')));
    await tester.pump();

    expect(cover, 1);
    expect(schedule, 0);
  });

  testWidgets(
    'platform onLiveStartSchedule invokes schedule, not cover/image picking',
    (tester) async {
      var schedule = 0;
      var cover = 0;
      var imagePicks = 0;

      ArCameraBridge.installPlatformCallbacks();
      ArCameraBridge.onLiveStartSchedule = () => schedule++;
      ArCameraBridge.onLiveStartChangeCover = () {
        cover++;
        imagePicks++;
      };
      addTearDown(() {
        ArCameraBridge.onLiveStartSchedule = null;
        ArCameraBridge.onLiveStartChangeCover = null;
        ArCameraBridge.clearPlatformCallbacks();
      });

      const channel = MethodChannel(ArCameraConstants.channelName);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall(LiveStartChromeMethod.schedule),
        ),
        (_) {},
      );
      await tester.pump();

      expect(schedule, 1);
      expect(cover, 0);
      expect(imagePicks, 0);
    },
  );
}
