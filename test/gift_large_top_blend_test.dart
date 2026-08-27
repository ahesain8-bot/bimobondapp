import 'package:bimobondapp/app/home/presentation/widgets/live_details/gift_animation_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A LARGE gift fills most of the frame, so a straight top edge reads as a
/// rectangle laid over the live feed. The stage's alpha is masked with a
/// gradient so that edge dissolves into the video underneath.
///
/// Video used to be excluded from every mask, which is why an MP4 gift was the
/// one that looked pasted on. SMALL and MEDIUM must keep the behaviour they
/// already had.

const _videoGift = 'https://example.invalid/gifts/occasion.mp4';
const _imageGift = 'https://example.invalid/gifts/monkey.webp';

Future<void> _pumpGift(
  WidgetTester tester, {
  required String url,
  required String size,
  Size screen = const Size(400, 900),
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GiftAnimationOverlay(
          animationUrl: url,
          size: size,
          onCompleted: () {},
        ),
      ),
    ),
  );
  // Let the failed video init and the entrance controller settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Disposing the overlay cancels its finish/stall timers.
Future<void> _tearDownGift(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('a LARGE video gift is alpha-masked, not left as a rectangle', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    await _pumpGift(tester, url: _videoGift, size: 'LARGE');

    final mask = find.byType(ShaderMask);
    expect(
      mask,
      findsOneWidget,
      reason: 'the LARGE stage must be masked so its top edge can dissolve',
    );
    expect(
      tester.widget<ShaderMask>(mask).blendMode,
      BlendMode.dstIn,
      reason: 'dstIn multiplies the gift\'s own alpha; it is not an opacity '
          'reduction and it preserves existing transparency',
    );

    await _tearDownGift(tester);
  });

  testWidgets('a LARGE image gift stays masked', (tester) async {
    addTearDown(tester.view.reset);

    await _pumpGift(tester, url: _imageGift, size: 'LARGE');

    expect(find.byType(ShaderMask), findsOneWidget);
    expect(
      tester.widget<ShaderMask>(find.byType(ShaderMask)).blendMode,
      BlendMode.dstIn,
    );

    await _tearDownGift(tester);
  });

  testWidgets('SMALL and MEDIUM video gifts keep the texture unmasked', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    for (final size in <String>['SMALL', 'MEDIUM']) {
      await _pumpGift(tester, url: _videoGift, size: size);

      expect(
        find.byType(ShaderMask),
        findsNothing,
        reason: '$size video must keep the video texture out of a mask layer',
      );

      await _tearDownGift(tester);
    }
  });

  testWidgets('SMALL and MEDIUM non-video gifts keep their existing fade', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    for (final size in <String>['SMALL', 'MEDIUM']) {
      await _pumpGift(tester, url: _imageGift, size: size);

      expect(
        find.byType(ShaderMask),
        findsOneWidget,
        reason: '$size kept its edge fade before this change',
      );

      await _tearDownGift(tester);
    }
  });

  testWidgets('the LARGE stage keeps its size and lower-middle position', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    const screen = Size(400, 900);

    await _pumpGift(tester, url: _videoGift, size: 'LARGE', screen: screen);

    final stage = tester.getRect(find.byType(ShaderMask));
    // Square stage of the screen's width, sitting clear of the bottom controls.
    final expectedBottomInset = (screen.height * 0.12).clamp(96.0, 160.0);

    expect(stage.width, screen.width);
    expect(stage.height, screen.width);
    expect(
      screen.height - stage.bottom,
      moreOrLessEquals(expectedBottomInset, epsilon: 0.5),
      reason: 'the blend must not move the gift',
    );

    await _tearDownGift(tester);
  });
}
