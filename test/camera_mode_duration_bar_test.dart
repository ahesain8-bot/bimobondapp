import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_bottom_controls.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('camera mode buttons dispatch their selected mode', (
    tester,
  ) async {
    var photoTaps = 0;
    int? duration;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraModeDurationBar(
              studioMode: CameraStudioMode.video,
              selectedDuration: 15,
              photoLabel: 'PHOTO',
              textLabel: 'TEXT',
              liveLabel: 'LIVE',
              duration10mLabel: '10m',
              showLive: true,
              showText: true,
              onPhotoSelected: () => photoTaps++,
              onDurationSelected: (value) => duration = value,
              onLiveSelected: () {},
              onTextSelected: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('PHOTO'));
    expect(photoTaps, 1);

    await tester.tap(find.text('10m'));
    expect(duration, 600);
  });
}
