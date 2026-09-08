import 'dart:async';

import 'package:bimobondapp/features/live/domain/entities/live_chat_message.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host.dart';
import 'package:bimobondapp/features/live/domain/entities/live_session.dart';
import 'package:bimobondapp/features/live/domain/live_viewer_display_name.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_bloc.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_event.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_state.dart';
import 'package:bimobondapp/features/live/presentation/widgets/room/live_room_chat_feed.dart';
import 'package:bimobondapp/features/live_viewer/data/mappers/socket_mapper.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/comment_entity.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/comment_input_bar.dart';
import 'package:bimobondapp/features/live_viewer/presentation/widgets/comments_section.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _l10nApp({
  required Locale locale,
  required Widget child,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

class _FeedBloc extends Fake implements LiveRoomBloc {
  _FeedBloc(this._state);

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
    if (event is LiveRoomChatPrefillRequested && _state is LiveRoomReady) {
      final current = _state as LiveRoomReady;
      _state = current.copyWith(
        isChatComposerVisible: true,
        chatComposerPrefill: event.text,
      );
      _controller.add(_state);
    }
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

CommentEntity _joinComment({
  required String username,
  String userId = 'v1',
}) {
  return CommentEntity(
    id: 'join-1',
    liveId: 'live-1',
    userId: userId,
    username: username,
    content: '',
    createdAt: DateTime.utc(2026, 9, 8),
    metadata: const {'type': 'join'},
  );
}

CommentEntity _normalComment() {
  return CommentEntity(
    id: 'c1',
    liveId: 'live-1',
    userId: 'v2',
    username: 'NormalUser',
    content: 'hello host',
    createdAt: DateTime.utc(2026, 9, 8),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('liveViewerDisplayNameFrom', () {
    test('uses fullName when available', () {
      expect(
        liveViewerDisplayNameFrom({
          'fullName': 'Sara Ali',
          'displayName': 'Ignored',
          'username': 'sara',
        }),
        'Sara Ali',
      );
    });

    test('falls back to username', () {
      expect(
        liveViewerDisplayNameFrom({'username': 'sara_handle'}),
        'sara_handle',
      );
    });

    test('uses displayName when fullName is missing', () {
      expect(
        liveViewerDisplayNameFrom({
          'displayName': 'Sara D',
          'username': 'sara',
        }),
        'Sara D',
      );
    });

    test('returns null when no real name is present', () {
      expect(liveViewerDisplayNameFrom({'id': 'u1'}), isNull);
      expect(liveViewerDisplayNameFrom({}), isNull);
    });
  });

  group('shouldInsertLiveJoinSystemMessage', () {
    test('host own join is skipped', () {
      expect(
        shouldInsertLiveJoinSystemMessage(
          joinerId: 'host-1',
          skipUserId: 'host-1',
        ),
        isFalse,
      );
    });

    test('other viewers are inserted', () {
      expect(
        shouldInsertLiveJoinSystemMessage(
          joinerId: 'viewer-1',
          skipUserId: 'host-1',
        ),
        isTrue,
      );
    });
  });

  group('SocketMapper userJoined', () {
    test('prefers nested user.fullName', () {
      final event = SocketMapper.userJoinedEvent({
        'liveId': 'live-1',
        'user': {
          'id': 'v1',
          'fullName': 'Sara Ali',
          'username': 'sara',
        },
        'viewers': 4,
      }, 'live-1');
      expect(event, isNotNull);
      expect(event!.userId, 'v1');
      expect(event.username, 'Sara Ali');
      expect(event.viewerCount, 4);
    });

    test('falls back to username without hardcoding User', () {
      final event = SocketMapper.userJoinedEvent({
        'user': {'id': 'v1', 'username': 'sara_handle'},
      }, 'live-1');
      expect(event!.username, 'sara_handle');
    });

    test('leaves username empty when payload has only userId', () {
      final event = SocketMapper.userJoinedEvent({
        'userId': 'v1',
      }, 'live-1');
      expect(event!.userId, 'v1');
      expect(event.username, isEmpty);
    });
  });

  group('localized join / welcome copy', () {
    test('English locale inserts the viewer name', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(l10n.liveViewerJoined('Sara Ali'), 'Sara Ali joined the live');
      expect(l10n.liveWelcomeViewer('Sara Ali'), 'Welcome, Sara Ali');
      expect(l10n.liveViewerFallbackName, 'Viewer');
    });

    test('Arabic locale inserts the viewer name', () {
      final l10n = lookupAppLocalizations(const Locale('ar'));
      expect(l10n.liveViewerJoined('سارة'), 'سارة انضم إلى البث');
      expect(l10n.liveWelcomeViewer('سارة'), 'مرحباً سارة');
      expect(l10n.liveViewerFallbackName, 'مشاهد');
    });
  });

  group('viewer join UI', () {
    testWidgets('viewer join uses localized copy and is not a normal comment', (
      tester,
    ) async {
      await tester.pumpWidget(
        _l10nApp(
          locale: const Locale('en'),
          child: Column(
            children: [
              TikTokCommentBubble(comment: _joinComment(username: 'Sara Ali')),
              TikTokCommentBubble(comment: _normalComment()),
            ],
          ),
        ),
      );

      expect(find.text('Sara Ali joined the live'), findsOneWidget);
      expect(find.text(' joined'), findsNothing);
      expect(find.text('hello host'), findsOneWidget);
      expect(find.text('NormalUser'), findsOneWidget);
    });

    testWidgets('viewer join uses Arabic localized copy', (tester) async {
      await tester.pumpWidget(
        _l10nApp(
          locale: const Locale('ar'),
          child: TikTokCommentBubble(comment: _joinComment(username: 'سارة')),
        ),
      );
      expect(find.text('سارة انضم إلى البث'), findsOneWidget);
    });

    testWidgets('viewer count style comments do not render a leave line', (
      tester,
    ) async {
      await tester.pumpWidget(
        _l10nApp(
          locale: const Locale('en'),
          child: TikTokCommentBubble(comment: _normalComment()),
        ),
      );
      expect(find.textContaining('left the live'), findsNothing);
      expect(find.textContaining('غادر البث'), findsNothing);
      expect(find.text('hello host'), findsOneWidget);
    });
  });

  group('host join UI + welcome prefill', () {
    testWidgets('host join uses localized copy', (tester) async {
      const session = LiveSession(
        id: 'live-1',
        title: 'test',
        host: LiveHost(id: 'h1', displayName: 'Host'),
        viewerCount: 1,
        likeCount: 0,
        galleryCurrent: 0,
        galleryTotal: 0,
        guestInviteCount: 0,
        hourlyRankingLabel: '',
        messages: [
          LiveChatMessage(
            id: 'join-1',
            text: 'Sara Ali',
            username: 'Sara Ali',
            userId: 'v1',
            isJoinEvent: true,
          ),
        ],
      );
      final bloc = _FeedBloc(const LiveRoomReady(session: session));
      addTearDown(bloc.close);

      await tester.pumpWidget(
        _l10nApp(
          locale: const Locale('en'),
          child: BlocProvider<LiveRoomBloc>.value(
            value: bloc,
            child: const SizedBox(
              height: 400,
              child: LiveRoomChatFeed(),
            ),
          ),
        ),
      );

      expect(find.text('Sara Ali joined the live'), findsOneWidget);
      expect(find.text('Sara Ali انضم'), findsNothing);
    });

    testWidgets('host tap on join line prefills localized welcome', (
      tester,
    ) async {
      const session = LiveSession(
        id: 'live-1',
        title: 'test',
        host: LiveHost(id: 'h1', displayName: 'Host'),
        viewerCount: 1,
        likeCount: 0,
        galleryCurrent: 0,
        galleryTotal: 0,
        guestInviteCount: 0,
        hourlyRankingLabel: '',
        messages: [
          LiveChatMessage(
            id: 'join-1',
            text: 'Sara Ali',
            username: 'Sara Ali',
            userId: 'v1',
            isJoinEvent: true,
          ),
          LiveChatMessage(
            id: 'c1',
            text: 'NormalUser: hello host',
            username: 'NormalUser',
            body: 'hello host',
            userId: 'v2',
          ),
        ],
      );
      final bloc = _FeedBloc(const LiveRoomReady(session: session));
      addTearDown(bloc.close);

      await tester.pumpWidget(
        _l10nApp(
          locale: const Locale('en'),
          child: BlocProvider<LiveRoomBloc>.value(
            value: bloc,
            child: const SizedBox(
              height: 400,
              child: LiveRoomChatFeed(),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sara Ali joined the live'));
      await tester.pump();

      expect(bloc.added, hasLength(1));
      expect(bloc.added.single, isA<LiveRoomChatPrefillRequested>());
      expect(
        (bloc.added.single as LiveRoomChatPrefillRequested).text,
        'Welcome, Sara Ali',
      );

      await tester.tap(find.text('hello host'));
      await tester.pump();
      expect(bloc.added, hasLength(1));
    });

    testWidgets('Arabic welcome prefill uses localized copy', (tester) async {
      const session = LiveSession(
        id: 'live-1',
        title: 'test',
        host: LiveHost(id: 'h1', displayName: 'Host'),
        viewerCount: 1,
        likeCount: 0,
        galleryCurrent: 0,
        galleryTotal: 0,
        guestInviteCount: 0,
        hourlyRankingLabel: '',
        messages: [
          LiveChatMessage(
            id: 'join-1',
            text: 'سارة',
            username: 'سارة',
            userId: 'v1',
            isJoinEvent: true,
          ),
        ],
      );
      final bloc = _FeedBloc(const LiveRoomReady(session: session));
      addTearDown(bloc.close);

      await tester.pumpWidget(
        _l10nApp(
          locale: const Locale('ar'),
          child: BlocProvider<LiveRoomBloc>.value(
            value: bloc,
            child: const SizedBox(
              height: 400,
              child: LiveRoomChatFeed(),
            ),
          ),
        ),
      );

      await tester.tap(find.text('سارة انضم إلى البث'));
      await tester.pump();
      expect(
        (bloc.added.single as LiveRoomChatPrefillRequested).text,
        'مرحباً سارة',
      );
    });
  });

  group('CommentInputBar prefill', () {
    testWidgets('shows localized welcome text in the existing composer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _l10nApp(
          locale: const Locale('en'),
          child: CommentInputBar(
            initialText: 'Welcome, Sara Ali',
            onSend: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Welcome, Sara Ali'), findsOneWidget);
    });
  });

  group('no synthetic leave', () {
    test('liveViewers payloads stay count-only', () {
      final event = SocketMapper.viewersEvent({
        'liveId': 'live-1',
        'viewers': 7,
      }, 'live-1');
      expect(event, isNotNull);
      expect(event!.viewerCount, 7);
    });
  });
}
