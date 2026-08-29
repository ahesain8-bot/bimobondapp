import 'package:bimobondapp/features/live_viewer/domain/entities/comment_entity.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/comments_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CommentEntity comment(String id, String text) => CommentEntity(
  id: id,
  liveId: 'l1',
  userId: 'u-$id',
  username: 'مشاهد $id',
  content: text,
  createdAt: DateTime(2026, 8, 23),
);

Future<void> pumpFeed(
  WidgetTester tester, {
  required TextDirection direction,
  required List<CommentEntity> comments,
  bool highContrast = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: CommentsSection(
            comments: comments,
            height: 200,
            highContrast: highContrast,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('comment text hugs the right edge under Arabic RTL', (
    tester,
  ) async {
    await pumpFeed(
      tester,
      direction: TextDirection.rtl,
      comments: [comment('1', 'تعليق تجريبي')],
    );

    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final body = tester.getTopLeft(find.text('تعليق تجريبي'));

    expect(
      body.dx,
      greaterThan(screenWidth / 2),
      reason: 'the run must start in the right half, as Arabic reads',
    );
  });

  testWidgets('RTL mirrors LTR rather than repeating its offsets', (
    tester,
  ) async {
    await pumpFeed(
      tester,
      direction: TextDirection.ltr,
      comments: [comment('1', 'same spot')],
    );
    final ltrRect = tester.getRect(find.text('same spot'));
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;

    await pumpFeed(
      tester,
      direction: TextDirection.rtl,
      comments: [comment('1', 'same spot')],
    );
    final rtlRect = tester.getRect(find.text('same spot'));

    expect(
      screenWidth - rtlRect.right,
      moreOrLessEquals(ltrRect.left, epsilon: 0.5),
      reason: 'the feed sits the same distance from the leading edge in both',
    );
  });

  testWidgets('the avatar stays to the right of the text in RTL', (
    tester,
  ) async {
    await pumpFeed(
      tester,
      direction: TextDirection.rtl,
      comments: [comment('1', 'نص التعليق')],
    );

    final row = tester.widget<Row>(
      find
          .descendant(
            of: find.byType(TikTokCommentBubble),
            matching: find.byType(Row),
          )
          .first,
    );
    expect(
      row.textDirection,
      isNull,
      reason: 'the bubble follows ambient direction instead of forcing LTR',
    );

    final textX = tester.getTopLeft(find.text('نص التعليق')).dx;
    final avatarX = tester
        .getTopLeft(
          find
              .descendant(
                of: find.byType(TikTokCommentBubble),
                matching: find.byType(ClipOval),
              )
              .first,
        )
        .dx;

    expect(avatarX, greaterThan(textX));
  });

  testWidgets('newest comment renders closest to the bottom', (tester) async {
    await pumpFeed(
      tester,
      direction: TextDirection.rtl,
      comments: [comment('1', 'الأقدم'), comment('2', 'الأحدث')],
    );

    final oldest = tester.getTopLeft(find.text('الأقدم')).dy;
    final newest = tester.getTopLeft(find.text('الأحدث')).dy;

    expect(newest, greaterThan(oldest));
  });

  testWidgets('an empty feed renders nothing and does not throw', (
    tester,
  ) async {
    await pumpFeed(tester, direction: TextDirection.rtl, comments: const []);

    expect(find.byType(TikTokCommentBubble), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('battle comments stay bare text over the video', (tester) async {
    await pumpFeed(
      tester,
      direction: TextDirection.rtl,
      comments: [comment('1', 'تعليق المنافسة')],
      highContrast: true,
    );

    final bubble = tester.widget<Container>(
      find.byKey(const ValueKey('comment-bubble-1')),
    );

    expect(
      bubble.decoration,
      isNull,
      reason: 'the opaque PK pill is the one thing that did not read as TikTok',
    );
    expect(find.text('تعليق المنافسة'), findsOneWidget);
  });
}
