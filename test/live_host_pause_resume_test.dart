import 'dart:async';

import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/core/models/live_battle.dart';
import 'package:bimobondapp/core/network/api_exceptions.dart';
import 'package:bimobondapp/features/live/data/datasources/lives_media_datasource.dart';
import 'package:bimobondapp/features/live/domain/entities/live_chat_message.dart';
import 'package:bimobondapp/features/live/domain/entities/live_guest.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host.dart';
import 'package:bimobondapp/features/live/domain/entities/live_host_outbound_pause_plan.dart';
import 'package:bimobondapp/features/live/domain/entities/live_leaderboard_entry.dart';
import 'package:bimobondapp/features/live/domain/entities/live_moderator.dart';
import 'package:bimobondapp/features/live/domain/entities/live_scene.dart';
import 'package:bimobondapp/features/live/domain/entities/live_session.dart';
import 'package:bimobondapp/features/live/domain/entities/live_studio.dart';
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
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

LiveSession _session({
  String mediaMode = 'VIDEO',
  bool audioOnly = false,
  LiveScene scene = const LiveScene(),
}) {
  return LiveSession(
    id: 'live-1',
    title: 'test',
    host: const LiveHost(id: 'h1', displayName: 'Host'),
    viewerCount: 0,
    likeCount: 0,
    galleryCurrent: 0,
    galleryTotal: 0,
    guestInviteCount: 0,
    hourlyRankingLabel: '',
    messages: const [],
    status: 'LIVE',
    mediaMode: mediaMode,
    audioOnly: audioOnly,
    scene: scene,
    liveKitToken: 'livekit-jwt-token',
    liveKitUrl: 'wss://example.invalid',
  );
}

class _NoopCameraRepo implements CameraRepository {
  @override
  Future<CameraController?> initialize({required bool useFront}) async => null;

  @override
  Future<void> dispose(CameraController controller) async {}
}

class _PauseRepo extends Fake implements LiveSessionRepository {
  _PauseRepo(this.session);

  LiveSession session;
  final log = <String>[];
  LiveHostOutboundPausePlan? lastPausePlan;
  LiveHostOutboundPausePlan? lastResumePlan;
  var pauseLiveCalls = 0;
  var resumeLiveCalls = 0;
  var reconnectCalls = 0;
  var mediaConnected = false;
  var failMediaPause = false;
  var failHttpPause = false;
  var failMediaResume = false;
  var failHttpResume = false;
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
  }) async => session;

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
  Future<void> pauseHostOutboundMedia(LiveHostOutboundPausePlan plan) async {
    log.add('mediaPause');
    lastPausePlan = plan;
    if (failMediaPause) throw StateError('media pause failed');
  }

  @override
  Future<void> resumeHostOutboundMedia(LiveHostOutboundPausePlan plan) async {
    log.add('mediaResume');
    lastResumePlan = plan;
    if (failMediaResume) throw StateError('media resume failed');
  }

  @override
  Future<bool> pauseLive(String liveId) async {
    log.add('httpPause');
    pauseLiveCalls += 1;
    if (failHttpPause) throw ApiException('backend pause failed');
    return true;
  }

  @override
  Future<bool> resumeLive(String liveId) async {
    log.add('httpResume');
    resumeLiveCalls += 1;
    if (failHttpResume) throw ApiException('backend resume failed');
    return false;
  }

  @override
  bool get isHostOutboundMediaPaused => lastPausePlan != null &&
      (log.isNotEmpty && log.last != 'mediaResume');

  @override
  Future<LiveSession> reconnectHostSession(String liveId) async {
    reconnectCalls += 1;
    return session;
  }

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
  Future<void> setMicrophoneEnabled(bool enabled) async {
    log.add(enabled ? 'micOn' : 'micOff');
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    log.add(enabled ? 'camOn' : 'camOff');
  }

  @override
  Future<void> setScreenShareEnabled(bool enabled) async {
    log.add(enabled ? 'screenOn' : 'screenOff');
  }

  Future<void> dispose() => mediaEventsController.close();
}

LiveRoomBloc _bloc(_PauseRepo repo) {
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

Future<LiveRoomReady> _startConnected(
  LiveRoomBloc bloc, {
  String mediaMode = 'VIDEO',
}) async {
  final ready = bloc.stream.firstWhere(
    (state) => state is LiveRoomReady && state.isMediaConnected,
  );
  bloc.add(LiveRoomStarted(title: 'test', mediaMode: mediaMode));
  return await ready.timeout(const Duration(seconds: 5)) as LiveRoomReady;
}

Future<LiveRoomReady> _waitReady(
  LiveRoomBloc bloc,
  bool Function(LiveRoomReady state) test,
) {
  final current = bloc.state;
  if (current is LiveRoomReady && test(current)) {
    return Future<LiveRoomReady>.value(current);
  }
  return bloc.stream
      .where((state) => state is LiveRoomReady)
      .cast<LiveRoomReady>()
      .firstWhere(test)
      .timeout(const Duration(seconds: 5));
}

Future<LiveRoomReady> _waitIdlePaused(
  LiveRoomBloc bloc, {
  required bool paused,
}) {
  return _waitReady(
    bloc,
    (state) => state.isLivePaused == paused && !state.isPauseActionBusy,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveHostOutboundPausePlan', () {
    test('CAMERA mutes camera + mic and restores both', () {
      final plan = LiveHostOutboundPausePlan.fromSession(
        isAudioOnly: false,
        scene: const LiveScene(scene: LiveScene.camera),
        micWasEnabled: true,
      );
      expect(plan.muteCamera, isTrue);
      expect(plan.muteMicrophone, isTrue);
      expect(plan.muteScreenShare, isFalse);
      expect(plan.restoreCamera, isTrue);
      expect(plan.restoreMicrophone, isTrue);
      expect(plan.restoreScreenShare, isFalse);
    });

    test('SCREEN mutes screen + mic and does not restore camera', () {
      final plan = LiveHostOutboundPausePlan.fromSession(
        isAudioOnly: false,
        scene: const LiveScene(scene: LiveScene.screen),
        micWasEnabled: true,
      );
      expect(plan.muteCamera, isFalse);
      expect(plan.muteScreenShare, isTrue);
      expect(plan.muteMicrophone, isTrue);
      expect(plan.restoreCamera, isFalse);
      expect(plan.restoreScreenShare, isTrue);
    });

    test('DUAL mutes both video sources + mic', () {
      final plan = LiveHostOutboundPausePlan.fromSession(
        isAudioOnly: false,
        scene: const LiveScene(scene: LiveScene.dual),
        micWasEnabled: true,
      );
      expect(plan.muteCamera, isTrue);
      expect(plan.muteScreenShare, isTrue);
      expect(plan.muteMicrophone, isTrue);
      expect(plan.restoreCamera, isTrue);
      expect(plan.restoreScreenShare, isTrue);
    });

    test('AUDIO mutes mic only', () {
      final plan = LiveHostOutboundPausePlan.fromSession(
        isAudioOnly: true,
        scene: const LiveScene(),
        micWasEnabled: true,
      );
      expect(plan.muteCamera, isFalse);
      expect(plan.muteScreenShare, isFalse);
      expect(plan.muteMicrophone, isTrue);
      expect(plan.restoreCamera, isFalse);
      expect(plan.restoreScreenShare, isFalse);
      expect(plan.restoreMicrophone, isTrue);
    });

    test('pre-existing mic mute is not restored', () {
      final plan = LiveHostOutboundPausePlan.fromSession(
        isAudioOnly: false,
        scene: const LiveScene(),
        micWasEnabled: false,
      );
      expect(plan.restoreMicrophone, isFalse);
      expect(plan.muteMicrophone, isTrue);
    });
  });

  group('LivesMediaDataSource pause does not destroy screen share', () {
    test('SCREEN pause/resume never calls setScreenShareEnabled', () async {
      final media = _SpyMedia();
      final plan = LiveHostOutboundPausePlan.fromSession(
        isAudioOnly: false,
        scene: const LiveScene(scene: LiveScene.screen),
        micWasEnabled: true,
      );
      await media.pauseHostOutboundMedia(plan);
      expect(media.isHostSessionMediaPaused, isTrue);
      expect(media.screenShareEnabledCalls, 0);
      expect(media.cameraEnabledCalls, 0);

      await expectLater(media.resumeHostOutboundMedia(plan), throwsStateError);
      expect(media.isHostSessionMediaPaused, isTrue);
      expect(media.screenShareEnabledCalls, 0);
    });

    test('intentional pause keeps outbound health paused through resumeOutboundHealthCheck',
        () async {
      final media = LivesMediaDataSource();
      final plan = LiveHostOutboundPausePlan.fromSession(
        isAudioOnly: true,
        scene: const LiveScene(),
        micWasEnabled: true,
      );
      await media.pauseHostOutboundMedia(plan);
      expect(media.isHostSessionMediaPaused, isTrue);
      media.resumeOutboundHealthCheck();
      expect(media.isHostSessionMediaPaused, isTrue);
      await media.resumeHostOutboundMedia(plan);
      expect(media.isHostSessionMediaPaused, isFalse);
    });
  });

  group('LiveRoomBloc pause / resume media', () {
    late _PauseRepo repo;
    late LiveRoomBloc bloc;

    Future<void> start({
      String mediaMode = 'VIDEO',
      LiveScene scene = const LiveScene(),
    }) async {
      repo = _PauseRepo(
        _session(
          mediaMode: mediaMode,
          audioOnly: mediaMode == 'AUDIO',
          scene: scene,
        ),
      );
      bloc = _bloc(repo);
      await _startConnected(bloc, mediaMode: mediaMode);
    }

    tearDown(() async {
      await bloc.close();
      await repo.dispose();
    });

    test('CAMERA Pause disables outbound camera + mic then HTTP pause', () async {
      await start();
      final paused = _waitIdlePaused(bloc, paused: true);
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      final state = await paused;

      expect(state.isLivePaused, isTrue);
      expect(repo.lastPausePlan?.muteCamera, isTrue);
      expect(repo.lastPausePlan?.muteMicrophone, isTrue);
      expect(repo.lastPausePlan?.muteScreenShare, isFalse);
      expect(repo.log, ['mediaPause', 'httpPause']);
      expect(repo.pauseLiveCalls, 1);
    });

    test('CAMERA Resume restores camera + mic then HTTP resume', () async {
      await start();
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      await _waitIdlePaused(bloc, paused: true);
      final resumed = _waitIdlePaused(bloc, paused: false);
      bloc.add(const LiveRoomPauseLiveTapped(pause: false));
      final state = await resumed;

      expect(state.isLivePaused, isFalse);
      expect(repo.lastResumePlan?.restoreCamera, isTrue);
      expect(repo.lastResumePlan?.restoreMicrophone, isTrue);
      expect(repo.lastResumePlan?.restoreScreenShare, isFalse);
      expect(repo.log, ['mediaPause', 'httpPause', 'mediaResume', 'httpResume']);
    });

    test('AUDIO Pause disables mic only', () async {
      await start(mediaMode: 'AUDIO');
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      await _waitIdlePaused(bloc, paused: true);

      expect(repo.lastPausePlan?.muteCamera, isFalse);
      expect(repo.lastPausePlan?.muteScreenShare, isFalse);
      expect(repo.lastPausePlan?.muteMicrophone, isTrue);
    });

    test('AUDIO Resume restores mic only', () async {
      await start(mediaMode: 'AUDIO');
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      await _waitIdlePaused(bloc, paused: true);
      bloc.add(const LiveRoomPauseLiveTapped(pause: false));
      await _waitIdlePaused(bloc, paused: false);

      expect(repo.lastResumePlan?.restoreCamera, isFalse);
      expect(repo.lastResumePlan?.restoreScreenShare, isFalse);
      expect(repo.lastResumePlan?.restoreMicrophone, isTrue);
    });

    test('pre-existing manual mic mute stays muted after Pause → Resume', () async {
      await start();
      bloc.add(const LiveRoomMicMuteToggled());
      await _waitReady(bloc, (state) => state.isMicMuted);
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      await _waitIdlePaused(bloc, paused: true);
      bloc.add(const LiveRoomPauseLiveTapped(pause: false));
      final state = await _waitIdlePaused(bloc, paused: false);

      expect(state.isMicMuted, isTrue);
      expect(repo.lastResumePlan?.restoreMicrophone, isFalse);
      expect(repo.log.contains('micOn'), isFalse);
    });

    test('SCREEN pause/resume uses screen-share media path, not camera restore',
        () async {
      await start(scene: const LiveScene(scene: LiveScene.screen));
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      await _waitIdlePaused(bloc, paused: true);
      expect(repo.lastPausePlan?.muteScreenShare, isTrue);
      expect(repo.lastPausePlan?.muteCamera, isFalse);
      expect(repo.lastPausePlan?.muteMicrophone, isTrue);
      expect(repo.log.contains('screenOff'), isFalse);

      bloc.add(const LiveRoomPauseLiveTapped(pause: false));
      await _waitIdlePaused(bloc, paused: false);
      expect(repo.lastResumePlan?.restoreScreenShare, isTrue);
      expect(repo.lastResumePlan?.restoreCamera, isFalse);
      expect(repo.log.contains('screenOn'), isFalse);
    });

    test('DUAL pause/resume handles both video sources', () async {
      await start(scene: const LiveScene(scene: LiveScene.dual));
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      await _waitIdlePaused(bloc, paused: true);
      expect(repo.lastPausePlan?.muteCamera, isTrue);
      expect(repo.lastPausePlan?.muteScreenShare, isTrue);

      bloc.add(const LiveRoomPauseLiveTapped(pause: false));
      await _waitIdlePaused(bloc, paused: false);
      expect(repo.lastResumePlan?.restoreCamera, isTrue);
      expect(repo.lastResumePlan?.restoreScreenShare, isTrue);
    });

    test('intentional pause does not trigger media watchdog recovery', () async {
      await start();
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      await _waitIdlePaused(bloc, paused: true);
      repo.mediaEventsController.add(
        const LiveMediaConnectionEvent(
          state: LiveMediaConnectionState.disconnected,
          reason: 'disconnected:outbound_video_stalled',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.reconnectCalls, 0);
      final state = bloc.state as LiveRoomReady;
      expect(state.isLivePaused, isTrue);
      expect(state.isMediaConnected, isTrue);
    });

    test('backend pause failure does not mark local session paused', () async {
      await start();
      repo.failHttpPause = true;
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      final state = await bloc.stream
          .where((s) => s is LiveRoomReady)
          .cast<LiveRoomReady>()
          .firstWhere(
            (s) => !s.isPauseActionBusy && s.actionMessage != null,
          )
          .timeout(const Duration(seconds: 5));

      expect(state.isLivePaused, isFalse);
      expect(repo.log, ['mediaPause', 'httpPause', 'mediaResume']);
    });

    test('backend resume failure keeps local session paused', () async {
      await start();
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      await _waitIdlePaused(bloc, paused: true);
      repo.failHttpResume = true;
      bloc.add(const LiveRoomPauseLiveTapped(pause: false));
      final state = await bloc.stream
          .where((s) => s is LiveRoomReady)
          .cast<LiveRoomReady>()
          .firstWhere(
            (s) => !s.isPauseActionBusy && s.actionMessage != null,
          )
          .timeout(const Duration(seconds: 5));

      expect(state.isLivePaused, isTrue);
      expect(repo.log, [
        'mediaPause',
        'httpPause',
        'mediaResume',
        'httpResume',
        'mediaPause',
      ]);
    });

    test('media pause failure does not call backend pause or mark paused', () async {
      await start();
      repo.failMediaPause = true;
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      final state = await bloc.stream
          .where((s) => s is LiveRoomReady)
          .cast<LiveRoomReady>()
          .firstWhere(
            (s) => !s.isPauseActionBusy && s.actionMessage != null,
          )
          .timeout(const Duration(seconds: 5));

      expect(state.isLivePaused, isFalse);
      expect(repo.pauseLiveCalls, 0);
      expect(repo.log, ['mediaPause']);
    });

    test('duplicate Pause taps do not pause twice', () async {
      await start();
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      bloc.add(const LiveRoomPauseLiveTapped(pause: true));
      await _waitIdlePaused(bloc, paused: true);
      expect(repo.pauseLiveCalls, 1);
    });
  });
}

class _SpyMedia extends LivesMediaDataSource {
  var screenShareEnabledCalls = 0;
  var cameraEnabledCalls = 0;

  @override
  Future<void> setScreenShareEnabled(bool enabled) async {
    screenShareEnabledCalls += 1;
    await super.setScreenShareEnabled(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraEnabledCalls += 1;
    await super.setCameraEnabled(enabled);
  }
}
