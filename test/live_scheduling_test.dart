import 'dart:async';
import 'dart:convert';

import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/core/models/live_battle.dart';
import 'package:bimobondapp/core/models/live_topic.dart';
import 'package:bimobondapp/core/network/api_exceptions.dart';
import 'package:bimobondapp/core/network/live_api_client.dart';
import 'package:bimobondapp/features/live/domain/entities/live_chat_message.dart';
import 'package:bimobondapp/features/live/domain/entities/live_guest.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host_outbound_pause_plan.dart';
import 'package:bimobondapp/features/live/domain/entities/live_leaderboard_entry.dart';
import 'package:bimobondapp/features/live/domain/entities/live_moderator.dart';
import 'package:bimobondapp/features/live/domain/entities/live_session.dart';
import 'package:bimobondapp/features/live/domain/entities/live_studio.dart';
import 'package:bimobondapp/features/live/domain/live_planned_scheduling.dart';
import 'package:bimobondapp/features/live/domain/repositories/camera_repository.dart';
import 'package:bimobondapp/features/live/domain/repositories/live_session_repository.dart';
import 'package:bimobondapp/features/live/domain/usecases/dispose_camera.dart';
import 'package:bimobondapp/features/live/domain/usecases/end_live_session.dart';
import 'package:bimobondapp/features/live/domain/usecases/initialize_camera.dart';
import 'package:bimobondapp/features/live/domain/usecases/like_live_session.dart';
import 'package:bimobondapp/features/live/domain/usecases/pause_live_session.dart';
import 'package:bimobondapp/features/live/domain/usecases/send_live_comment.dart';
import 'package:bimobondapp/features/live/domain/usecases/start_live_session.dart';
import 'package:bimobondapp/features/live/domain/usecases/update_live_title.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_bloc.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_event.dart';
import 'package:bimobondapp/features/live/presentation/bloc/live_room/live_room_state.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_livekit_service.dart';
import 'package:bimobondapp/features/live_viewer/data/services/fake_socket_service.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/entities/live_session_entity.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/comment_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/gift_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/guest_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/like_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/repositories/live_repository.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/ban_viewer_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/delete_comment_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/join_live_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/leave_live_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/like_live_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/mute_viewer_chat_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/unban_viewer_usecase.dart';
import 'package:bimobondapp/features/live_viewer/domain/usecases/unmute_viewer_chat_usecase.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_bloc.dart';
import 'package:bimobondapp/features/live_viewer/presentation/bloc/live_viewer/live_viewer_event.dart';
import 'package:camera/camera.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

LiveSession _planned({
  String id = 'planned-1',
  String status = 'PLANNED',
}) {
  return LiveSession(
    id: id,
    title: 'Q&A tonight',
    host: const LiveHost(id: 'h1', displayName: 'Host'),
    viewerCount: 0,
    likeCount: 0,
    galleryCurrent: 0,
    galleryTotal: 0,
    guestInviteCount: 0,
    hourlyRankingLabel: '',
    messages: const [],
    status: status,
    mediaMode: 'AUDIO',
    audioOnly: true,
    liveKitToken: status == 'LIVE' ? 'livekit-jwt-token' : null,
    liveKitUrl: status == 'LIVE' ? 'wss://example.invalid' : null,
    scheduledAt: DateTime.utc(2026, 9, 8, 20),
  );
}

class _NoopCameraRepo implements CameraRepository {
  @override
  Future<CameraController?> initialize({required bool useFront}) async => null;

  @override
  Future<void> dispose(CameraController controller) async {}
}

class _ScheduleRepo extends Fake implements LiveSessionRepository {
  _ScheduleRepo({this.startResult, this.startError});

  LiveSession? startResult;
  Object? startError;
  var startHostCalls = 0;
  var reconnectCalls = 0;
  final reconnectIds = <String>[];
  var mediaConnected = false;
  final mediaEventsController =
      StreamController<LiveMediaConnectionEvent>.broadcast();

  @override
  Stream<LiveHudEvent> get hudEvents => const Stream.empty();

  @override
  Stream<LiveMediaConnectionEvent> get mediaEvents =>
      mediaEventsController.stream;

  @override
  Future<LiveSession> startHostSession({
    required String title,
    String mediaMode = 'VIDEO',
    String? topic,
  }) async {
    startHostCalls += 1;
    return startResult ?? _planned(status: 'LIVE');
  }

  @override
  Future<LiveSession> reconnectHostSession(String liveId) async {
    reconnectCalls += 1;
    reconnectIds.add(liveId);
    final error = startError;
    if (error != null) throw error;
    return startResult ?? _planned(id: liveId, status: 'LIVE');
  }

  @override
  Future<void> connectRealtime(String liveId) async {}

  @override
  Future<void> disconnectRealtime() async {}

  @override
  Future<void> connectMedia({
    required String url,
    required String token,
    bool useFrontCamera = true,
    int maxAttempts = 3,
    Future<void> Function()? beforeVideoCapture,
    mediaHints,
    bool useArBeautyCamera = false,
  }) async {
    mediaConnected = true;
  }

  @override
  Future<void> disconnectMedia() async {
    mediaConnected = false;
  }

  @override
  bool get isMediaConnected => mediaConnected;

  @override
  Object? get localPreviewTrack => null;

  @override
  Object? get localScreenShareTrack => null;

  @override
  Object? get mediaRoom => null;

  @override
  Object? get battleMediaRoom => null;

  @override
  bool get isBattleRoomUsable => false;

  @override
  Future<void> pauseHostOutboundMedia(LiveHostOutboundPausePlan plan) async {}

  @override
  Future<void> resumeHostOutboundMedia(LiveHostOutboundPausePlan plan) async {}

  @override
  Future<List<LiveChatMessage>> loadComments(
    String liveId, {
    int page = 1,
    int limit = 50,
  }) async => const [];

  @override
  Future<({int current, int total})> loadGalleryCounts(String liveId) async =>
      (current: 0, total: 0);

  @override
  Future<List<LiveGuest>> loadGuests(String liveId) async => const [];

  @override
  Future<({int? rank, String label, int? score, int? coins})> loadHourlyRank(
    String liveId,
  ) async => (rank: null, label: '', score: null, coins: null);

  @override
  Future<LiveBattle?> loadBattle(String liveId) async => null;

  @override
  Future<LiveStudio?> loadStudio(String liveId) async => null;

  @override
  Future<List<LiveModerator>> loadModerators(String liveId) async => const [];

  @override
  Future<List<LiveLeaderboardEntry>> loadGiftersLeaderboard(
    String liveId, {
    String window = 'hour',
  }) async => const [];

  @override
  void pauseOutboundMediaHealthCheck() {}

  @override
  void resumeOutboundMediaHealthCheck() {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setScreenShareEnabled(bool enabled) async {}

  Future<void> dispose() => mediaEventsController.close();
}

LiveRoomBloc _hostBloc(_ScheduleRepo repo) {
  final camera = _NoopCameraRepo();
  return LiveRoomBloc(
    startLiveSession: StartLiveSession(repo),
    endLiveSession: EndLiveSession(repo),
    initializeCamera: InitializeCamera(camera),
    disposeCamera: DisposeCamera(camera),
    sendLiveComment: SendLiveComment(repo),
    likeLiveSession: LikeLiveSession(repo),
    updateLiveTitle: UpdateLiveTitle(repo),
    pauseLiveSession: PauseLiveSession(repo),
    sessionRepository: repo,
    giftSocketService: AuctionSocketService(),
  );
}

class _JoinCountingRepo implements LiveRepository {
  var joinCalls = 0;
  var liveKitWouldJoin = false;

  @override
  Future<Either<Failure, JoinLiveResult>> joinLive(
    String liveId, {
    String? campaignId,
  }) async {
    joinCalls += 1;
    liveKitWouldJoin = true;
    return const Left(ServerFailure('join must not run for PLANNED'));
  }

  @override
  Future<Either<Failure, void>> leaveLive(String liveId) async =>
      const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Comments implements CommentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Gifts implements GiftRepository {
  @override
  Future<Either<Failure, int>> getCoinBalance() async => const Right(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Likes implements LikeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Guests implements GuestRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LiveEntity _scheduledLive() => LiveEntity(
  id: 'planned-1',
  hostId: 'host-1',
  hostName: 'Host',
  title: 'Q&A tonight',
  category: 'chat',
  startTime: DateTime.utc(2026, 9, 8, 20),
  status: LiveStatus.scheduled,
  isLive: false,
  scheduledAt: DateTime.utc(2026, 9, 8, 20),
);

Future<void> _pumpUntil(bool Function() test) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!test()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('create scheduled LIVE payload', () {
    test('POST /lives body has scheduledAt UTC Z and omits startNow', () {
      final local = DateTime(2026, 9, 8, 23, 0);
      final body = LivePlannedScheduling.createBody(
        title: 'Q&A tonight',
        scheduledAt: local,
        mediaMode: 'VIDEO',
        topic: ' late night ',
        coverUrl: 'https://cdn.example/cover.jpg',
      );

      expect(body.containsKey('startNow'), isFalse);
      expect(body['title'], 'Q&A tonight');
      expect(body['mediaMode'], 'VIDEO');
      expect(body['topic'], 'late night');
      expect(body['coverUrl'], 'https://cdn.example/cover.jpg');
      final iso = body['scheduledAt'] as String;
      expect(iso.endsWith('Z'), isTrue);
      expect(iso, LiveSchedule.toUtcIso(local));
      expect(
        jsonEncode(body).contains('"startNow"'),
        isFalse,
      );
    });

    test('scheduledAt UTC serialization round-trips local wall clock', () {
      final local = DateTime(2026, 3, 8, 1, 30);
      final iso = LiveSchedule.toUtcIso(local);
      expect(iso.endsWith('Z'), isTrue);
      final roundTrip = LiveSchedule.parse(iso)!.toLocal();
      expect(roundTrip.year, local.year);
      expect(roundTrip.month, local.month);
      expect(roundTrip.day, local.day);
      expect(roundTrip.hour, local.hour);
      expect(roundTrip.minute, local.minute);
    });
  });

  group('GET /lives/mine PLANNED filtering', () {
    test('keeps every PLANNED row and ignores LIVE/ENDED', () {
      final planned = LivePlannedScheduling.plannedMapsFromMinePayload({
        'data': [
          {'id': 'a', 'status': 'PLANNED'},
          {'id': 'b', 'status': 'LIVE'},
          {'id': 'c', 'status': 'PLANNED'},
          {'id': 'd', 'status': 'ENDED'},
        ],
      });
      expect(planned.map((e) => e['id']), ['a', 'c']);
      expect(planned.length, 2);
    });

    test('multiple PLANNED items are supported', () {
      expect(
        LivePlannedScheduling.isPlannedStatus('PLANNED'),
        isTrue,
      );
      expect(LivePlannedScheduling.isPlannedStatus('LIVE'), isFalse);
    });
  });

  group('PATCH scheduledAt', () {
    test('reschedule sends a new UTC ISO scheduledAt', () {
      final next = DateTime.utc(2026, 9, 8, 21);
      final body = LivePlannedScheduling.rescheduleBody(next);
      expect(body, {'scheduledAt': '2026-09-08T21:00:00.000Z'});
    });

    test('clear time PATCH encodes scheduledAt: null, not a delete', () {
      final body = LivePlannedScheduling.clearScheduledTimeBody();
      expect(body.containsKey('scheduledAt'), isTrue);
      expect(body['scheduledAt'], isNull);
      expect(jsonEncode(body), '{"scheduledAt":null}');
    });
  });

  group('start existing PLANNED', () {
    test('StartLiveSession uses reconnect, not create', () async {
      final repo = _ScheduleRepo(startResult: _planned(status: 'LIVE'));
      final usecase = StartLiveSession(repo);
      final session = await usecase(
        title: 'ignored',
        existingLiveId: 'planned-1',
      );
      expect(repo.reconnectCalls, 1);
      expect(repo.reconnectIds, ['planned-1']);
      expect(repo.startHostCalls, 0);
      expect(session.id, 'planned-1');
      expect(session.status, 'LIVE');
    });

    test('omitting existingLiveId creates a new live', () async {
      final repo = _ScheduleRepo(startResult: _planned(id: 'new-1', status: 'LIVE'));
      final usecase = StartLiveSession(repo);
      await usecase(title: 'Now');
      expect(repo.startHostCalls, 1);
      expect(repo.reconnectCalls, 0);
    });

    test('early start is allowed client-side', () {
      final future = DateTime.now().add(const Duration(hours: 3));
      expect(
        LivePlannedScheduling.canStartNow(scheduledAt: future),
        isTrue,
      );
      expect(
        LivePlannedScheduling.canStartNow(
          scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        isTrue,
      );
    });
  });

  group('LiveRoomBloc existing PLANNED start', () {
    test('successful start keeps live id and goes READY/LIVE', () async {
      final repo = _ScheduleRepo(
        startResult: _planned(id: 'planned-1', status: 'LIVE'),
      );
      final bloc = _hostBloc(repo);
      bloc.add(
        const LiveRoomStarted(
          title: 'Q&A tonight',
          mediaMode: 'AUDIO',
          existingLiveId: 'planned-1',
        ),
      );
      await _pumpUntil(() => bloc.state is LiveRoomReady);
      final ready = bloc.state as LiveRoomReady;
      expect(ready.session.id, 'planned-1');
      expect(ready.session.status, 'LIVE');
      expect(ready.session.id.startsWith('local_live_'), isFalse);
      expect(repo.reconnectCalls, 1);
      expect(repo.startHostCalls, 0);
      await bloc.close();
      await repo.dispose();
    });

    test('failed start stays PLANNED and does not create a live', () async {
      final repo = _ScheduleRepo(
        startError: ApiException('backend start failed', statusCode: 500),
      );
      final bloc = _hostBloc(repo);
      bloc.add(
        const LiveRoomStarted(
          title: 'Q&A tonight',
          mediaMode: 'AUDIO',
          existingLiveId: 'planned-1',
        ),
      );
      await _pumpUntil(() => bloc.state is LiveRoomFailure);
      final failure = bloc.state as LiveRoomFailure;
      expect(failure.pendingExistingLiveId, 'planned-1');
      expect(failure.isActiveLiveConflict, isFalse);
      expect(repo.startHostCalls, 0);
      expect(repo.reconnectCalls, 1);
      await bloc.close();
      await repo.dispose();
    });

    test('active LIVE conflict is surfaced without creating another live', () async {
      final repo = _ScheduleRepo(
        startError: ApiException(
          'You already have an active live',
          statusCode: 400,
        ),
      );
      final bloc = _hostBloc(repo);
      bloc.add(
        const LiveRoomStarted(
          title: 'Q&A tonight',
          mediaMode: 'AUDIO',
          existingLiveId: 'planned-1',
        ),
      );
      await _pumpUntil(() => bloc.state is LiveRoomFailure);
      final failure = bloc.state as LiveRoomFailure;
      expect(failure.isActiveLiveConflict, isTrue);
      expect(failure.pendingExistingLiveId, 'planned-1');
      expect(repo.startHostCalls, 0);
      await bloc.close();
      await repo.dispose();
    });
  });

  group('PLANNED viewer path', () {
    test('does not call join or LiveKit', () async {
      final lives = _JoinCountingRepo();
      final kit = FakeLiveKitService();
      final socket = FakeSocketService();
      final gifts = AuctionSocketService();
      final bloc = LiveViewerBloc(
        joinLiveUseCase: JoinLiveUseCase(lives),
        leaveLiveUseCase: LeaveLiveUseCase(lives),
        likeLiveUseCase: LikeLiveUseCase(_Likes()),
        giftSocketService: gifts,
        banViewerUseCase: BanViewerUseCase(lives),
        unbanViewerUseCase: UnbanViewerUseCase(lives),
        muteViewerChatUseCase: MuteViewerChatUseCase(lives),
        unmuteViewerChatUseCase: UnmuteViewerChatUseCase(lives),
        deleteCommentUseCase: DeleteCommentUseCase(_Comments()),
        liveRepository: lives,
        commentRepository: _Comments(),
        giftRepository: _Gifts(),
        likeRepository: _Likes(),
        socketService: socket,
        liveKitService: kit,
        guestRepository: _Guests(),
        apiClient: LiveApiClient(
          httpClient: MockClient((request) async {
            return http.Response(jsonEncode({'id': 'viewer-1'}), 200);
          }),
          idTokenProvider: () async => 'mock',
        ),
      );

      bloc.add(LiveViewerActivated(_scheduledLive()));
      await _pumpUntil(
        () =>
            bloc.state.session?.connectionState ==
            LiveConnectionState.scheduled,
      );

      expect(lives.joinCalls, 0);
      expect(lives.liveKitWouldJoin, isFalse);
      expect(
        LivePlannedScheduling.viewerMayJoinLiveKit('PLANNED'),
        isFalse,
      );
      expect(_scheduledLive().status.allowsViewerLiveKitJoin, isFalse);
      await bloc.close();
      kit.dispose();
      socket.dispose();
      gifts.dispose();
    });
  });
}
