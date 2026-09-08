import 'dart:async';

import 'package:bimobondapp/core/network/api_endpoints.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host.dart';
import 'package:bimobondapp/features/live/domain/entities/live_session.dart';
import 'package:bimobondapp/features/live/domain/entities/live_viewer.dart';
import 'package:bimobondapp/features/live/domain/live_viewer_ban_state.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_bloc.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_event.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_state.dart';
import 'package:bimobondapp/features/live/presentation/widgets/room/live_room_people_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

LiveSession _session() {
  return const LiveSession(
    id: 'live-1',
    title: 'test',
    host: LiveHost(id: 'h1', displayName: 'Host'),
    viewerCount: 2,
    likeCount: 0,
    galleryCurrent: 0,
    galleryTotal: 0,
    guestInviteCount: 0,
    hourlyRankingLabel: '',
    messages: [],
  );
}

class _PeopleBloc extends Fake implements LiveRoomBloc {
  _PeopleBloc(this._state);

  LiveRoomState _state;
  final added = <LiveRoomEvent>[];
  final _controller = StreamController<LiveRoomState>.broadcast();

  @override
  LiveRoomState get state => _state;

  @override
  Stream<LiveRoomState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(LiveRoomEvent event) {
    added.add(event);
    if (event is! LiveRoomModerationRequested) return;
    if (_state is! LiveRoomReady) return;
    final current = _state as LiveRoomReady;
    final userId = event.userId;
    if (event.action == LiveRoomModerationAction.banViewer) {
      _state = current.copyWith(
        bannedUserIds: applyLiveViewerBanState(
          current: current.bannedUserIds,
          userId: userId,
          banned: true,
        ),
        bannedViewerNames: applyLiveViewerBanName(
          current: current.bannedViewerNames,
          userId: userId,
          banned: true,
          displayName: event.username,
        ),
      );
      _controller.add(_state);
    } else if (event.action == LiveRoomModerationAction.unbanViewer) {
      _state = current.copyWith(
        bannedUserIds: applyLiveViewerBanState(
          current: current.bannedUserIds,
          userId: userId,
          banned: false,
        ),
        bannedViewerNames: applyLiveViewerBanName(
          current: current.bannedViewerNames,
          userId: userId,
          banned: false,
        ),
      );
      _controller.add(_state);
    }
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

Widget _app({
  required LiveRoomBloc bloc,
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<LiveRoomBloc>.value(
        value: bloc,
        child: child,
      ),
    ),
  );
}

void main() {
  const sara = LiveViewer(
    userId: 'v1',
    displayName: 'Sara Ali',
  );

  group('applyLiveViewerBanState', () {
    test('fullName-style id is added on viewer_banned', () {
      final next = applyLiveViewerBanState(
        current: const {},
        userId: 'v1',
        banned: true,
      );
      expect(next, {'v1'});
      expect(isLiveViewerBanned(next, 'v1'), isTrue);
    });

    test('viewer_unbanned removes the id', () {
      final next = applyLiveViewerBanState(
        current: {'v1', 'v2'},
        userId: 'v1',
        banned: false,
      );
      expect(next, {'v2'});
      expect(isLiveViewerBanned(next, 'v1'), isFalse);
    });

    test('empty userId does not change state', () {
      expect(
        applyLiveViewerBanState(
          current: {'v1'},
          userId: '',
          banned: true,
        ),
        {'v1'},
      );
    });
  });

  group('liveRoomPeopleRosterForModeration', () {
    test('skips host, empty ids, and keeps banned viewers after they leave', () {
      final rows = liveRoomPeopleRosterForModeration(
        roster: const [
          LiveViewer(userId: 'h1', displayName: 'Host'),
          LiveViewer(userId: '', displayName: 'Ghost'),
          sara,
        ],
        hostId: 'h1',
        bannedUserIds: {'v1', 'v9'},
        bannedViewerNames: const {'v9': 'Left Viewer'},
      );
      expect(rows.map((v) => v.userId), ['v1', 'v9']);
      expect(rows.last.displayName, 'Left Viewer');
    });
  });

  group('LIVE ban endpoints stay separate from kick and global block', () {
    test('host people actions map to viewer ban/unban paths', () {
      expect(
        ApiEndpoints.liveViewerBan('live-1', 'v1'),
        '/lives/live-1/viewers/v1/ban',
      );
      expect(
        ApiEndpoints.liveViewerUnban('live-1', 'v1'),
        '/lives/live-1/viewers/v1/unban',
      );
      expect(
        ApiEndpoints.liveGuestKick('live-1', 'v1'),
        '/lives/live-1/guests/v1/kick',
      );
      expect(ApiConstants.blockUser('v1'), '/users/v1/block');
      expect(
        LiveRoomModerationAction.banViewer,
        isNot(LiveRoomModerationAction.unbanViewer),
      );
    });
  });

  group('People sheet viewer Ban / Unban', () {
    testWidgets('Ban action dispatches LIVE viewer ban, not kick or block', (
      tester,
    ) async {
      final bloc = _PeopleBloc(LiveRoomReady(session: _session()));
      addTearDown(bloc.close);

      await tester.pumpWidget(
        _app(
          bloc: bloc,
          child: const LiveRoomPeopleViewerRow(
            viewer: sara,
            isBanned: false,
          ),
        ),
      );

      expect(find.text('حظر من البث'), findsOneWidget);
      expect(find.text('إلغاء الحظر'), findsNothing);
      expect(find.text('طرد'), findsNothing);

      await tester.tap(find.text('حظر من البث'));
      await tester.pump();

      expect(bloc.added, hasLength(1));
      final event = bloc.added.single as LiveRoomModerationRequested;
      expect(event.action, LiveRoomModerationAction.banViewer);
      expect(event.userId, 'v1');
      expect(event.username, 'Sara Ali');
      expect(
        bloc.added.whereType<LiveRoomModerationRequested>().every(
          (e) =>
              e.action == LiveRoomModerationAction.banViewer ||
              e.action == LiveRoomModerationAction.unbanViewer,
        ),
        isTrue,
      );
      expect(
        ApiEndpoints.liveViewerBan('live-1', event.userId!),
        isNot(ApiEndpoints.liveGuestKick('live-1', event.userId!)),
      );
      expect(
        ApiEndpoints.liveViewerBan('live-1', event.userId!),
        isNot(ApiConstants.blockUser(event.userId!)),
      );
    });

    testWidgets('Unban action dispatches LIVE viewer unban', (tester) async {
      final bloc = _PeopleBloc(
        LiveRoomReady(
          session: _session(),
          bannedUserIds: const {'v1'},
          bannedViewerNames: const {'v1': 'Sara Ali'},
        ),
      );
      addTearDown(bloc.close);

      await tester.pumpWidget(
        _app(
          bloc: bloc,
          child: const LiveRoomPeopleViewerRow(
            viewer: sara,
            isBanned: true,
          ),
        ),
      );

      expect(find.text('إلغاء الحظر'), findsOneWidget);
      expect(find.text('حظر من البث'), findsNothing);
      expect(find.text('طرد'), findsNothing);

      await tester.tap(find.text('إلغاء الحظر'));
      await tester.pump();

      final event = bloc.added.single as LiveRoomModerationRequested;
      expect(event.action, LiveRoomModerationAction.unbanViewer);
      expect(event.userId, 'v1');
      expect(
        ApiEndpoints.liveViewerUnban('live-1', event.userId!),
        '/lives/live-1/viewers/v1/unban',
      );
    });

    testWidgets('state toggles Ban to Unban after moderation update', (
      tester,
    ) async {
      final bloc = _PeopleBloc(LiveRoomReady(session: _session()));
      addTearDown(bloc.close);

      await tester.pumpWidget(
        _app(
          bloc: bloc,
          child: BlocBuilder<LiveRoomBloc, LiveRoomState>(
            builder: (context, state) {
              final banned = state is LiveRoomReady &&
                  isLiveViewerBanned(state.bannedUserIds, sara.userId);
              return LiveRoomPeopleViewerRow(
                viewer: sara,
                isBanned: banned,
              );
            },
          ),
        ),
      );

      expect(find.text('حظر من البث'), findsOneWidget);
      await tester.tap(find.text('حظر من البث'));
      await tester.pump();

      expect(find.text('إلغاء الحظر'), findsOneWidget);
      expect(find.text('حظر من البث'), findsNothing);
      final ready = bloc.state as LiveRoomReady;
      expect(ready.bannedUserIds, {'v1'});
      expect(ready.bannedViewerNames['v1'], 'Sara Ali');

      await tester.tap(find.text('إلغاء الحظر'));
      await tester.pump();
      final after = bloc.state as LiveRoomReady;
      expect(after.bannedUserIds, isEmpty);
      expect(find.text('حظر من البث'), findsOneWidget);
    });

    testWidgets('stage Kick remains off the People viewer row', (tester) async {
      final bloc = _PeopleBloc(LiveRoomReady(session: _session()));
      addTearDown(bloc.close);

      await tester.pumpWidget(
        _app(
          bloc: bloc,
          child: const LiveRoomPeopleViewerRow(
            viewer: sara,
            isBanned: false,
          ),
        ),
      );

      expect(find.text('طرد'), findsNothing);
      expect(find.text('Kick'), findsNothing);
    });
  });
}
