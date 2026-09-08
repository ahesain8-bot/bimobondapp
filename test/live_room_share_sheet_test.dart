import 'dart:async';

import 'package:bimobondapp/features/live/domain/entities/live_host.dart';
import 'package:bimobondapp/features/live/domain/entities/live_session.dart';
import 'package:bimobondapp/features/live/domain/entities/live_share_result.dart';
import 'package:bimobondapp/features/live/domain/repositories/live_session_repository.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_bloc.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_event.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_state.dart';
import 'package:bimobondapp/features/live/presentation/widgets/room/live_room_share_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingShareRepo extends Fake implements LiveSessionRepository {
  int shareLiveCalls = 0;
  String? lastLiveId;
  String? lastChannel;

  @override
  Future<LiveShareResult> shareLive(String liveId, {String? channel}) async {
    shareLiveCalls += 1;
    lastLiveId = liveId;
    lastChannel = channel;
    return const LiveShareResult(
      liveId: 'live-1',
      shareUrl: 'https://app.example.com/lives/live-1',
      shareCount: 42,
    );
  }
}

class _ShareTestBloc extends Fake implements LiveRoomBloc {
  _ShareTestBloc(this._state);

  LiveRoomState _state;
  final _controller = StreamController<LiveRoomState>.broadcast();
  final added = <LiveRoomEvent>[];

  @override
  LiveRoomState get state => _state;

  @override
  Stream<LiveRoomState> get stream => _controller.stream;

  @override
  bool get isClosed => _controller.isClosed;

  @override
  void add(LiveRoomEvent event) {
    added.add(event);
    if (event is LiveRoomShareCountUpdated && _state is LiveRoomReady) {
      final current = _state as LiveRoomReady;
      _state = current.copyWith(
        session: current.session.copyWith(shareCount: event.shareCount),
      );
      _controller.add(_state);
    }
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const session = LiveSession(
    id: 'live-1',
    title: 'test',
    host: LiveHost(id: 'h1', displayName: 'Host'),
    viewerCount: 0,
    likeCount: 0,
    galleryCurrent: 0,
    galleryTotal: 0,
    guestInviteCount: 0,
    hourlyRankingLabel: '',
    messages: [],
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'share sheet uses page LiveSessionRepository and Copy Link updates count',
    (tester) async {
      final repo = _RecordingShareRepo();
      final bloc = _ShareTestBloc(const LiveRoomReady(session: session));
      addTearDown(bloc.close);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: RepositoryProvider<LiveSessionRepository>.value(
            value: repo,
            child: BlocProvider<LiveRoomBloc>.value(
              value: bloc,
              child: Builder(
                builder: (context) {
                  return Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => LiveRoomShareSheet.show(context),
                        child: const Text('open-share'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open-share'));
      await tester.pumpAndSettle();

      expect(find.text('مشاركة'), findsOneWidget);

      await tester.ensureVisible(find.text('نسخ الرابط'));
      await tester.tap(find.text('نسخ الرابط'));
      await tester.pumpAndSettle();

      expect(repo.shareLiveCalls, 1);
      expect(repo.lastLiveId, 'live-1');
      expect(repo.lastChannel, LiveShareChannel.copyLink);
      expect(find.text('تعذر مشاركة البث'), findsNothing);

      final state = bloc.state;
      expect(state, isA<LiveRoomReady>());
      expect((state as LiveRoomReady).session.shareCount, 42);
    },
  );
}
