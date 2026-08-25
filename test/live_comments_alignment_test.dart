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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: CommentsSection(comments: comments, height: 200),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('comment text hugs the left edge under Arabic RTL', (
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
      lessThan(screenWidth / 2),
      reason: 'the run must start in the left half, not drift to the centre',
    );
  });

  testWidgets('RTL and LTR put the comment in the same place', (tester) async {
    await pumpFeed(
      tester,
      direction: TextDirection.ltr,
      comments: [comment('1', 'same spot')],
    );
    final ltrX = tester.getTopLeft(find.text('same spot')).dx;

    await pumpFeed(
      tester,
      direction: TextDirection.rtl,
      comments: [comment('1', 'same spot')],
    );
    final rtlX = tester.getTopLeft(find.text('same spot')).dx;

    expect(
      rtlX,
      moreOrLessEquals(ltrX, epsilon: 0.5),
      reason: 'host and viewer must not mirror the feed in Arabic',
    );
  });

  testWidgets('the avatar stays to the left of the text in RTL', (
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
    expect(row.textDirection ?? TextDirection.ltr, TextDirection.ltr);

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

    expect(avatarX, lessThan(textX));
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
}
