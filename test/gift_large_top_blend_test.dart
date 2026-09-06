import 'package:bimobondapp/app/home/presentation/widgets/live_details/gift_animation_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// LARGE gifts (including MP4 occasion gifts) dissolve the top ~10% into the
/// live/auction feed via [ShaderMask] + [BlendMode.dstIn].
/// SMALL and MEDIUM stay fully opaque.

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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tearDownGift(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  testWidgets('LARGE video gifts get a dstIn top transparency mask', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    await _pumpGift(tester, url: _videoGift, size: 'LARGE');

    expect(find.byType(ShaderMask), findsOneWidget);
    expect(
      tester.widget<ShaderMask>(find.byType(ShaderMask)).blendMode,
      BlendMode.dstIn,
    );

    await _tearDownGift(tester);
  });

  testWidgets('LARGE image gifts get a dstIn top transparency mask', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    await _pumpGift(tester, url: _imageGift, size: 'LARGE');

    expect(find.byType(ShaderMask), findsOneWidget);
    expect(
      tester.widget<ShaderMask>(find.byType(ShaderMask)).blendMode,
      BlendMode.dstIn,
    );

    await _tearDownGift(tester);
  });

  testWidgets('SMALL and MEDIUM gifts have no fade mask', (tester) async {
    addTearDown(tester.view.reset);

    for (final size in <String>['SMALL', 'MEDIUM']) {
      await _pumpGift(tester, url: _videoGift, size: size);
      expect(find.byType(ShaderMask), findsNothing);
      await _tearDownGift(tester);

      await _pumpGift(tester, url: _imageGift, size: size);
      expect(
        find.byType(ShaderMask),
        findsNothing,
        reason: '$size must stay fully opaque',
      );
      await _tearDownGift(tester);
    }
  });

  testWidgets('the LARGE stage keeps its size and bottom position', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    const screen = Size(400, 900);

    await _pumpGift(tester, url: _videoGift, size: 'LARGE', screen: screen);

    final stage = tester.getRect(
      find.byKey(const ValueKey('gift-animation-stage')),
    );
    expect(stage.width, screen.width);
    expect(stage.height, screen.width);
    expect(
      screen.height - stage.bottom,
      moreOrLessEquals(0, epsilon: 0.5),
      reason: 'the blend must not move the gift',
    );

    await _tearDownGift(tester);
  });
}
