import 'package:bimobondapp/features/live/domain/entities/live_guest.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host.dart';
import 'package:bimobondapp/features/live/domain/entities/live_session.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_state.dart';
import 'package:bimobondapp/features/live/presentation/widgets/room/live_room_stage.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/comment_entity.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/comments_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = LiveSession(
  id: 'l1',
  title: 't',
  host: LiveHost(id: 'h1', displayName: 'Host'),
  viewerCount: 0,
  likeCount: 0,
  galleryCurrent: 0,
  galleryTotal: 0,
  guestInviteCount: 0,
  hourlyRankingLabel: '',
  messages: [],
);

LiveGuest guest(String id, String status) => LiveGuest(
  id: 'g-$id',
  liveId: 'l1',
  userId: id,
  role: 'GUEST',
  status: status,
  displayName: 'Guest $id',
);

Future<Size> stageSize(WidgetTester tester, Size screen) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: screen.width,
          height: screen.height,
          child: LiveRoomStageTiles(
            tiles: const [
              SizedBox.expand(key: ValueKey('a')),
              SizedBox.expand(key: ValueKey('b')),
            ],
          ),
        ),
      ),
    ),
  );
  return tester.getSize(find.byKey(const ValueKey('a')));
}

void main() {
  group('stage geometry', () {
    testWidgets('tiles stay equal on a narrow phone', (tester) async {
      final size = await stageSize(tester, const Size(320, 640));
      expect(size.width, greaterThan(0));
    });

    testWidgets('tiles stay equal on a tablet-width screen', (tester) async {
      final narrow = await stageSize(tester, const Size(320, 640));
      final wide = await stageSize(tester, const Size(800, 1200));
      expect(wide.width, greaterThan(narrow.width));
    });

    test('the stage never claims more than half the space below the header', () {
      expect(kStageMaxHeightFactor, lessThanOrEqualTo(0.6));
      expect(kStageAspect, greaterThan(1.0));
    });
  });

  group('request roster', () {
    test('only REQUESTED viewers need the host to decide', () {
      const state = LiveRoomReady(session: _session);
      final withGuests = state.copyWith(
        guests: [
          guest('u1', 'REQUESTED'),
          guest('u2', 'INVITED'),
          guest('u3', 'ACTIVE'),
          guest('u4', 'REQUESTED'),
        ],
      );

      expect(withGuests.requestingGuests.map((g) => g.userId), ['u1', 'u4']);
      expect(
        withGuests.activeGuests.map((g) => g.userId),
        ['u3'],
        reason: 'an invite the host sent is not a request to answer',
      );
    });

    test('an invited guest is pending but not requesting', () {
      expect(guest('u', 'INVITED').isPending, isTrue);
      expect(guest('u', 'INVITED').isRequesting, isFalse);
      expect(guest('u', 'REQUESTED').isRequesting, isTrue);
    });
  });

  group('comment feed sizing', () {
    testWidgets('the feed honours a short slot without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomLeft,
                child: CommentsSection(
                  height: 64,
                  comments: [
                    for (var i = 0; i < 12; i++)
                      CommentEntity(
                        id: 'c$i',
                        liveId: 'l1',
                        userId: 'u$i',
                        username: 'مشاهد $i',
                        content: 'تعليق رقم $i',
                        createdAt: DateTime(2026, 8, 24),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CommentsSection)).height, 64);
    });

    testWidgets('a large text scale does not overflow the feed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: CommentsSection(
                  height: 200,
                  comments: [
                    CommentEntity(
                      id: 'c1',
                      liveId: 'l1',
                      userId: 'u1',
                      username: 'مشاهد باسم طويل جداً',
                      content: 'تعليق طويل نسبياً لاختبار التمدد',
                      createdAt: DateTime(2026, 8, 24),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });
  });
}
