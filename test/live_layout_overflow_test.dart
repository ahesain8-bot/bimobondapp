import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_gradient_overlay.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/features/live/presentation/widgets/start_live/tool_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The narrowest phone the app ships on, and the width the device in the bug
/// report reports (`w360dp`).
const double _phoneWidth = 360;

Widget toolsBlock() => FittedBox(
  fit: BoxFit.scaleDown,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [
          ToolButton(asset: AppAssets.service, label: 'Services+'),
          ToolButton(asset: AppAssets.settings, label: 'الإعدادات'),
          ToolButton(asset: AppAssets.guests, label: 'المؤثرات'),
          ToolButton(asset: AppAssets.edit, label: 'تجميل'),
          ToolButton(asset: AppAssets.heart, label: 'قلب'),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [
          ToolButton(asset: AppAssets.share, label: 'مشاركة'),
          ToolButton(asset: AppAssets.interaction, label: 'تفاعل'),
          ToolButton(asset: AppAssets.followHosts, label: 'مجتمع المعجبين'),
        ],
      ),
    ],
  ),
);

void main() {
  testWidgets('the five live tools fit a 360dp phone', (tester) async {
    tester.view.physicalSize = const Size(_phoneWidth, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: Padding(
              // The 30px side padding the row actually ships with.
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: toolsBlock(),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.takeException(),
      isNull,
      reason: 'this row overflowed by exactly 20px on a 360dp screen',
    );
  });

  testWidgets('both tool rows scale by the same factor', (tester) async {
    tester.view.physicalSize = const Size(_phoneWidth, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: toolsBlock(),
            ),
          ),
        ),
      ),
    );

    final primary = tester.getSize(find.byType(ToolButton).first);
    final secondary = tester.getSize(find.byType(ToolButton).last);

    expect(
      primary.width,
      moreOrLessEquals(secondary.width, epsilon: 0.5),
      reason: 'a button must not be a different size between the two rows',
    );
  });

  testWidgets('the tools still fit on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(720, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(child: toolsBlock()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the feed gradient overlay does not fight its own Positioned', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 400,
              // The caller positions it; the overlay must not position itself.
              child: VideoPostGradientOverlay(),
            ),
          ],
        ),
      ),
    );

    expect(
      tester.takeException(),
      isNull,
      reason: 'two Positioned widgets on one RenderObject is an assertion',
    );
    expect(tester.getSize(find.byType(VideoPostGradientOverlay)).height, 400);
  });
}
