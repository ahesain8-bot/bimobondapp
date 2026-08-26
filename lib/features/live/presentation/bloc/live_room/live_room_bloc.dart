import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';

import '../../../../../core/network/api_exceptions.dart';
import '../../../../../core/models/live_battle.dart';
import '../../../../../core/models/live_competition_request.dart';
import '../../../../../core/services/live_feed_refresh_bus.dart';
import '../../../domain/effects/live_effects_catalog.dart';
import '../../../domain/entities/live_chat_feed_merge.dart';
import '../../../domain/entities/live_guest.dart';
import '../../../domain/entities/live_chat_message.dart';
import '../../../domain/entities/live_host.dart';
import '../../../domain/entities/live_session.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../../domain/usecases/dispose_camera.dart';
import '../../../domain/usecases/end_live_session.dart';
import '../../../domain/usecases/initialize_camera.dart';
import '../../../domain/usecases/like_live_session.dart';
import '../../../domain/usecases/send_live_comment.dart';
import '../../../domain/usecases/start_live_session.dart';
import '../../../domain/usecases/update_live_title.dart';
import 'live_room_event.dart';
import 'live_room_state.dart';
import '../../../domain/entities/live_gift_banner.dart';

/// Orchestrates the live-room host screen: backend session + HUD + camera.
class LiveRoomBloc extends Bloc<LiveRoomEvent, LiveRoomState> {
  LiveRoomBloc({
    required StartLiveSession startLiveSession,
    required EndLiveSession endLiveSession,
    required InitializeCamera initializeCamera,
    required DisposeCamera disposeCamera,
    required SendLiveComment sendLiveComment,
    required LikeLiveSession likeLiveSession,
    required UpdateLiveTitle updateLiveTitle,
    required LiveSessionRepository sessionRepository,
    required AuctionSocketService giftSocketService,
  }) : _startLiveSession = startLiveSession,
       _endLiveSession = endLiveSession,
       _initializeCamera = initializeCamera,
       _disposeCamera = disposeCamera,
       _sendLiveComment = sendLiveComment,
       _likeLiveSession = likeLiveSession,
       _updateLiveTitle = updateLiveTitle,
       _sessionRepository = sessionRepository,
       _giftSocketService = giftSocketService,
       super(const LiveRoomInitial()) {
    _giftComboSub = giftSocketService.onGiftCombo.listen((payload) {
      if (!isClosed) add(LiveRoomGiftComboReceived(payload));
    });
    on<LiveRoomStarted>(_onStarted);
    on<LiveRoomRecoverEndAndRestart>(_onRecoverEndAndRestart);
    on<LiveRoomRecoverResumeActive>(_onRecoverResumeActive);
    on<LiveRoomEndRequested>(_onEndRequested);
    on<LiveRoomAppPaused>(_onAppPaused);
    on<LiveRoomAppResumed>(_onAppResumed);
    on<LiveRoomChatTapped>(_onChatTapped);
    on<LiveRoomChatComposerClosed>(_onChatComposerClosed);
    on<LiveRoomChatMessageSubmitted>(_onChatMessageSubmitted);
    on<LiveRoomShareTapped>(_onUiAction);
    on<LiveRoomEffectsTapped>(_onEffectsTapped);
    on<LiveRoomMoreTapped>(_onUiAction);
    on<LiveRoomCollabTapped>(_onUiAction);
    on<LiveRoomViewersTapped>(_onUiAction);
    on<LiveRoomInviteTapped>(_onUiAction);
    on<LiveRoomRankingTapped>(_onRankingTapped);
    on<LiveRoomLikeTapped>(_onLikeTapped);
    on<LiveRoomHeartBurstConsumed>(_onHeartBurstConsumed);
    on<LiveRoomGiftBannerConsumed>(_onGiftBannerConsumed);
    on<LiveRoomGiftComboReceived>(_onGiftComboReceived);
    on<LiveRoomGiftComboConsumed>(_onGiftComboConsumed);
    on<LiveRoomTitleSubmitted>(_onTitleSubmitted);
    on<LiveRoomEffectsPanelModeChanged>(_onEffectsPanelModeChanged);
    on<LiveRoomEffectSelected>(_onEffectSelected);
    on<LiveRoomEffectsCategorySelected>(_onEffectsCategorySelected);
    on<LiveRoomFlipCameraRequested>(_onFlipCamera);
    on<LiveRoomMirrorToggled>(_onMirrorToggled);
    on<LiveRoomMicMuteToggled>(_onMicMuteToggled);
    on<LiveRoomStabilizationToggled>(_onStabilizationToggled);
    on<LiveRoomNoiseReductionToggled>(_onNoiseReductionToggled);
    on<LiveRoomAiContentToggled>(_onAiContentToggled);
    on<LiveRoomPauseLiveTapped>(_onPauseLiveTapped);
    on<LiveRoomMenuDestinationRequested>(_onMenuDestination);
    on<LiveRoomShareContactSelected>(_onShareContactSelected);
    on<LiveRoomShareChannelRequested>(_onShareChannelRequested);
    on<LiveRoomGuestsChanged>(_onGuestsChanged);
    on<LiveRoomBattleChanged>(_onBattleChanged);
    on<LiveRoomCommentsResyncRequested>(_onCommentsResync);
    on<LiveRoomGuestInviteAnswered>(_onGuestInviteAnswered);
    on<LiveRoomGuestRequestAnswered>(_onGuestRequestAnswered);
    on<LiveRoomCompetitionRequestAnswered>(_onCompetitionRequestAnswered);
    on<LiveRoomGalleryChanged>(_onGalleryChanged);
    on<LiveRoomSettingsApplied>(_onSettingsApplied);
    on<LiveRoomModerationRequested>(_onModerationRequested);
    on<LiveRoomHudEventReceived>(_onHudEvent);
    on<LiveRoomMediaEventReceived>(_onMediaEvent);
    on<LiveRoomClearActionMessage>(_onClearActionMessage);
    on<LiveRoomRemoteEnded>(_onRemoteEnded);
  }

  final StartLiveSession _startLiveSession;
  final EndLiveSession _endLiveSession;
  final InitializeCamera _initializeCamera;
  final DisposeCamera _disposeCamera;
  final SendLiveComment _sendLiveComment;
  final LikeLiveSession _likeLiveSession;
  final UpdateLiveTitle _updateLiveTitle;
  final LiveSessionRepository _sessionRepository;

  StreamSubscription<LiveHudEvent>? _hudSub;
  StreamSubscription<LiveMediaConnectionEvent>? _mediaSub;
  StreamSubscription<GiftComboPayload>? _giftComboSub;
  final AuctionSocketService _giftSocketService;
  String? _giftJoinedLiveId;

  /// Set after a successful `POST /end` or remote `liveEnded`.
  var _sessionTeardownDone = false;

  /// Prevents overlapping camera init / flip requests.
  var _cameraOpInFlight = false;
  var _mediaRecoveryInFlight = false;
  var _appPaused = false;
  var _closing = false;

  LiveRoomReady? get _readyOrNull =>
      state is LiveRoomReady ? state as LiveRoomReady : null;

  Future<void> _onStarted(
    LiveRoomStarted event,
    Emitter<LiveRoomState> emit,
  ) async {
    emit(const LiveRoomLoading());
    _sessionTeardownDone = false;
    _cameraOpInFlight = false;

    final title = event.title?.trim().isNotEmpty == true
        ? event.title!.trim()
        : 'بث مباشر';

    // Critical path: open local camera immediately — never wait for Nest/LiveKit.
    // If the start screen handed us its RUNNING camera, reuse it (same lens,
    // no reopen, no black flicker); otherwise open a fresh one.
    final cameraFuture = event.initialCamera != null
        ? Future<CameraController?>.value(event.initialCamera)
        : _initializeCamera(useFront: true);
    final sessionFuture = _startLiveSession(title: title);

    final controller = await cameraFuture;
    if (isClosed) {
      if (controller != null) await _disposeCamera(controller);
      return;
    }

    if (controller != null) {
      emit(
        LiveRoomOpening(
          controller: controller,
          isCameraInitialized: true,
          isFrontCamera: true,
        ),
      );
    }

    late final LiveSession session;
    var startedOnServer = true;
    try {
      session = await sessionFuture;
    } catch (e) {
      if (isClosed) {
        if (controller != null) await _disposeCamera(controller);
        return;
      }
      final conflict = e is ApiException && _isActiveLiveConflict(e);
      if (conflict) {
        if (controller != null) await _disposeCamera(controller);
        emit(
          LiveRoomFailure(
            message:
                'لديك بث مباشر نشط بالفعل. أنهِه قبل بدء بث جديد، أو استأنف البث الحالي.',
            isActiveLiveConflict: true,
            pendingTitle: title,
          ),
        );
        return;
      }
      // Fallback to local session if backend server is offline so camera preview remains active.
      startedOnServer = false;
      session = LiveSession(
        id: 'local_live_${DateTime.now().millisecondsSinceEpoch}',
        host: const LiveHost(
          id: 'local_host',
          displayName: 'المستضيف',
          avatarUrl: '',
        ),
        viewerCount: 1,
        likeCount: 0,
        galleryCurrent: 0,
        galleryTotal: 0,
        guestInviteCount: 0,
        hourlyRankingLabel: '',
        messages: const [],
        title: title,
        status: 'LIVE',
      );
    }
    if (isClosed) {
      if (controller != null) await _disposeCamera(controller);
      return;
    }

    await _enterReadyWithSession(
      emit: emit,
      session: session,
      controller: controller,
      startedOnServer: startedOnServer,
    );
  }

  Future<void> _onRecoverEndAndRestart(
    LiveRoomRecoverEndAndRestart event,
    Emitter<LiveRoomState> emit,
  ) async {
    final failure = state is LiveRoomFailure ? state as LiveRoomFailure : null;
    if (failure == null ||
        !failure.isActiveLiveConflict ||
        failure.isRecovering) {
      return;
    }

    emit(
      LiveRoomFailure(
        message: failure.message,
        isActiveLiveConflict: true,
        pendingTitle: failure.pendingTitle,
        isRecovering: true,
      ),
    );

    try {
      final active = await _sessionRepository.findActiveHostLive();
      if (active != null) {
        await _sessionRepository.endSession(active.id);
      }
    } on ApiException catch (e) {
      if (isClosed) return;
      emit(
        LiveRoomFailure(
          message: e.message,
          isActiveLiveConflict: true,
          pendingTitle: failure.pendingTitle,
        ),
      );
      return;
    } catch (e) {
      if (isClosed) return;
      emit(
        LiveRoomFailure(
          message: e.toString(),
          isActiveLiveConflict: true,
          pendingTitle: failure.pendingTitle,
        ),
      );
      return;
    }

    if (isClosed) return;
    add(LiveRoomStarted(title: failure.pendingTitle));
  }

  Future<void> _onRecoverResumeActive(
    LiveRoomRecoverResumeActive event,
    Emitter<LiveRoomState> emit,
  ) async {
    final failure = state is LiveRoomFailure ? state as LiveRoomFailure : null;
    if (failure == null ||
        !failure.isActiveLiveConflict ||
        failure.isRecovering) {
      return;
    }

    emit(
      LiveRoomFailure(
        message: failure.message,
        isActiveLiveConflict: true,
        pendingTitle: failure.pendingTitle,
        isRecovering: true,
      ),
    );

    try {
      final active = await _sessionRepository.findActiveHostLive();
      if (active == null) {
        if (isClosed) return;
        emit(
          LiveRoomFailure(
            message: 'لم يتم العثور على بث نشط. يمكنك المحاولة من جديد.',
            pendingTitle: failure.pendingTitle,
          ),
        );
        return;
      }

      final cameraFuture = _initializeCamera(useFront: true);
      final sessionFuture = _sessionRepository.reconnectHostSession(active.id);
      final controller = await cameraFuture;
      if (isClosed) {
        if (controller != null) await _disposeCamera(controller);
        return;
      }
      if (controller != null) {
        emit(
          LiveRoomOpening(
            controller: controller,
            isCameraInitialized: true,
            isFrontCamera: true,
          ),
        );
      }

      final session = await sessionFuture;
      if (isClosed) {
        if (controller != null) await _disposeCamera(controller);
        return;
      }

      await _enterReadyWithSession(
        emit: emit,
        session: session,
        controller: controller,
      );
    } on ApiException catch (e) {
      if (isClosed) return;
      emit(
        LiveRoomFailure(
          message: _mapStartFailureMessage(e),
          isActiveLiveConflict: true,
          pendingTitle: failure.pendingTitle,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        LiveRoomFailure(
          message: e.toString(),
          isActiveLiveConflict: true,
          pendingTitle: failure.pendingTitle,
        ),
      );
    }
  }

  Future<void> _enterReadyWithSession({
    required Emitter<LiveRoomState> emit,
    required LiveSession session,
    required CameraController? controller,
    bool startedOnServer = true,
  }) async {
    await _hudSub?.cancel();
    _hudSub = _sessionRepository.hudEvents.listen((hudEvent) {
      if (!isClosed) {
        add(LiveRoomHudEventReceived(hudEvent));
      }
    });
    await _mediaSub?.cancel();
    _mediaSub = _sessionRepository.mediaEvents.listen((mediaEvent) {
      if (!isClosed) add(LiveRoomMediaEventReceived(mediaEvent));
    });

    // Preview is already on screen (Opening → Ready keeps same controller).
    //
    // Emitted BEFORE the socket is dialled. Awaiting `connectRealtime` here
    // held the room in `Opening` for the whole handshake — and on a failure
    // that is the full connect timeout, so starting a broadcast looked frozen
    // for several seconds with the camera already running underneath.
    emit(
      LiveRoomReady(
        session: session,
        controller: controller,
        isCameraInitialized: controller != null,
        isFrontCamera: true,
        isMediaConnected: false,
      ),
    );

    if (startedOnServer && session.id.isNotEmpty) {
      _giftJoinedLiveId = session.id;
      unawaited(
        _giftSocketService
            .ensureJoined(liveId: session.id)
            .catchError((error) {
              debugPrint('Canonical gift socket join failed: $error');
            }),
      );
    }

    // Skipped for the offline fallback below: a `local_live_<ts>` id means
    // POST /lives never succeeded, so there is no room on the server and the
    // join would subscribe to nothing.
    if (startedOnServer && session.id.isNotEmpty) {
      unawaited(_connectRealtimeInBackground(session.id));
    }

    // The offline fallback invents a `local_live_…` id, so there is no room on
    // the server to join: viewers, comments and likes would all stay empty with
    // nothing on screen explaining why. Tell the host instead of pretending.
    if (!startedOnServer) {
      final ready = _readyOrNull;
      if (ready != null && !isClosed) {
        emit(
          ready.copyWith(
            actionMessage:
                'لم يبدأ البث على الخادم. المعاينة تعمل محلياً فقط، ولن يظهر '
                'المشاهدون ولا التعليقات ولا الإعجابات. أعد المحاولة.',
          ),
        );
      }
      // Nothing to enrich or publish either: every one of those calls keys off
      // the live id the server never issued.
      return;
    }

    // Publishing is the critical path. Waiting for four HUD HTTP requests here
    // delayed the first outgoing frame by several seconds.
    await _publishLiveKitAfterPreview(emit);

    // Comments/gallery/guests/rank can arrive after video is already flowing.
    await _enrichSession(emit);
  }

  /// Dials the HUD socket off the critical path, retrying with a short backoff.
  ///
  /// The room is already interactive by the time this runs, so a slow or dead
  /// socket costs comments and the viewer counter — surfaced by the standing
  /// warning in the chat feed — but never the ability to broadcast. Without the
  /// retry a single failed handshake left the room silent for its whole run.
  Future<void> _connectRealtimeInBackground(String liveId) async {
    const delays = [
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ];

    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      // Bail out if the host left, ended the stream, or started another one.
      if (isClosed) return;
      final ready = _readyOrNull;
      if (ready == null || ready.session.id != liveId) return;

      try {
        await _sessionRepository.connectRealtime(liveId);
        return;
      } catch (e) {
        debugPrint('HUD socket connect failed for $liveId: $e');
        if (isClosed) return;
        add(
          LiveRoomHudEventReceived(
            LiveHudConnectionEvent(connected: false, reason: e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _enrichSession(Emitter<LiveRoomState> emit) async {
    final current = _readyOrNull;
    if (current == null || current.session.id.isEmpty) return;
    final liveId = current.session.id;

    final results = await Future.wait([
      _sessionRepository.loadComments(liveId),
      _sessionRepository.loadGalleryCounts(liveId),
      // Full roster, not just the count: a request that arrived before the
      // host opened the room would otherwise sit invisible until the next
      // socket event, and there may not be one.
      _sessionRepository.loadGuests(liveId),
      _sessionRepository.loadHourlyRank(liveId),
      _loadBattleSafely(liveId),
    ]);
    if (isClosed) return;
    final ready = _readyOrNull;
    if (ready == null || ready.session.id != liveId) return;

    final comments = results[0] as List<LiveChatMessage>;
    final gallery = results[1] as ({int current, int total});
    final guests = results[2] as List<LiveGuest>;
    final hourly =
        results[3] as ({int? rank, String label, int? score, int? coins});
    final battle = results[4] as LiveBattle?;
    // A `liveBattle` event may have arrived while the parallel HTTP snapshot
    // was still loading. Never let an older null response erase that event.
    final effectiveBattle = battle ?? ready.battle;

    // Merged, not assigned: enrichment runs a beat after the room goes Ready,
    // and anything the socket delivered in that window used to be wiped by the
    // HTTP history landing on top of it.
    emit(
      ready.copyWith(
        guests: guests,
        battle: effectiveBattle,
        session: ready.session.copyWith(
          messages: mergeLiveChatMessages(comments, ready.session.messages),
          galleryCurrent: gallery.current,
          galleryTotal: gallery.total,
          guestInviteCount: guests.where((g) => g.isPending).length,
          hourlyRank: hourly.rank,
          hourlyRankingLabel: hourly.label,
        ),
      ),
    );
    if (effectiveBattle?.isActive == true) {
      add(LiveRoomBattleChanged(effectiveBattle));
    }
  }

  Future<LiveBattle?> _loadBattleSafely(String liveId) async {
    try {
      return await _sessionRepository.loadBattle(liveId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _publishLiveKitAfterPreview(Emitter<LiveRoomState> emit) async {
    final current = _readyOrNull;
    if (current == null) {
      debugPrint(
        '🔍 [BLoC] _publishLiveKitAfterPreview: _readyOrNull is null → abort',
      );
      return;
    }

    final token = current.session.liveKitToken;
    final url = current.session.liveKitUrl;
    debugPrint(
      '🔍 [BLoC] _publishLiveKitAfterPreview: '
      'url=${url ?? "NULL"}, token=${token != null ? "${token.substring(0, 10)}..." : "NULL"}',
    );
    if (token == null || token.isEmpty || url == null || url.isEmpty) {
      final ready = _readyOrNull;
      if (ready != null && !isClosed) {
        emit(
          ready.copyWith(
            actionMessage:
                'الخادم لم يعرض بيانات LiveKit (token/url مفقودين). الفيديو عبر البث غير متاح، ولكن توجد معاينة محلية.',
          ),
        );
      }
      return;
    }

    final useFront = current.isFrontCamera;
    final local = current.controller;
    debugPrint(
      '🔍 [BLoC] _publishLiveKitAfterPreview: '
      'useFront=$useFront, localController=${local != null ? "SET" : "NULL"}',
    );

    // ── Two-phase camera handoff (no black screen) ─────────────────────────
    // Keep the local preview alive while room signalling and audio connect.
    // Release it exactly once immediately before WebRTC opens the camera, so
    // CameraX and LiveKit never contend for the same lens.
    var localReleased = false;
    Future<void> releaseLocalCamera() async {
      if (local == null || localReleased || isClosed) return;
      final beforeRelease = _readyOrNull;
      if (beforeRelease == null) return;
      emit(
        beforeRelease.copyWith(
          controller: null,
          isCameraInitialized: false,
          clearActionMessage: true,
        ),
      );
      await _disposeCamera(local);
      localReleased = true;
      debugPrint('🔍 [BLoC] Flutter camera handed off to LiveKit ✅');
    }

    try {
      debugPrint('🔍 [BLoC] connectMedia with serialized camera handoff...');
      await _sessionRepository.connectMedia(
        url: url,
        token: token,
        useFrontCamera: useFront,
        beforeVideoCapture: releaseLocalCamera,
        mediaHints: current.session.mediaHints,
      );
      debugPrint('🔍 [BLoC] connectMedia SUCCESS ✅');
    } catch (e) {
      debugPrint('🔴 [BLoC] connectMedia failed: $e');
      CameraController? fallback = localReleased ? null : local;
      if (localReleased) {
        fallback = await _initializeCamera(useFront: useFront);
      }
      if (isClosed) {
        if (localReleased && fallback != null) await _disposeCamera(fallback);
        return;
      }
      final ready = _readyOrNull;
      if (ready == null) {
        if (localReleased && fallback != null) await _disposeCamera(fallback);
        return;
      }
      emit(
        ready.copyWith(
          controller: fallback,
          isCameraInitialized: fallback != null,
          isMediaConnected: false,
          localVideoTrack: null,
          actionMessage: 'تعذر نشر الفيديو عبر LiveKit: $e',
        ),
      );
      return;
    }
    if (isClosed) return;

    final ready = _readyOrNull;
    if (ready == null) {
      debugPrint('🔍 [BLoC] After connectMedia: _readyOrNull is null → abort');
      return;
    }

    debugPrint(
      '🔍 [BLoC] After connectMedia: '
      'isMediaConnected=${_sessionRepository.isMediaConnected}, '
      'localPreviewTrack=${_sessionRepository.localPreviewTrack != null ? "SET" : "NULL"}',
    );

    // Only swap when there is genuinely something to swap TO.
    final liveTrack = _sessionRepository.localPreviewTrack as VideoTrack?;
    final mediaUp = _sessionRepository.isMediaConnected;
    final swapToLiveKit = liveTrack != null && mediaUp;
    emit(
      ready.copyWith(
        controller: swapToLiveKit ? null : ready.controller,
        isCameraInitialized: swapToLiveKit ? false : ready.isCameraInitialized,
        isMediaConnected: mediaUp,
        localVideoTrack: liveTrack,
        isFrontCamera: useFront,
        clearActionMessage: true,
      ),
    );
    debugPrint(
      '🔍 [BLoC] Emitted state: controller=null, '
      'isMediaConnected=${_sessionRepository.isMediaConnected}, '
      'localVideoTrack=${_sessionRepository.localPreviewTrack != null ? "SET" : "NULL"}',
    );

    debugPrint('🟢 [BLoC] _publishLiveKitAfterPreview: COMPLETE');
  }

  /// Surfaces Nest LiveKit misconfig clearly (production.md troubleshooting).
  String _mapStartFailureMessage(ApiException e) {
    final raw = e.message;
    final lower = raw.toLowerCase();
    if (e.statusCode == 503 ||
        lower.contains('livekit') && lower.contains('not configured')) {
      return 'الخادم غير مهيأ لـ LiveKit (LIVEKIT_URL). '
          'هذا إعداد على الـ backend وليس خطأ في التطبيق.\n'
          '($raw)';
    }
    if (_isActiveLiveConflict(e)) {
      return 'لديك بث مباشر نشط بالفعل. أنهِه قبل بدء بث جديد، أو استأنف البث الحالي.';
    }
    return raw;
  }

  bool _isActiveLiveConflict(ApiException e) {
    final lower = e.message.toLowerCase();
    return lower.contains('already have an active live') ||
        lower.contains('end it before starting another') ||
        (e.statusCode == 400 &&
            lower.contains('already') &&
            lower.contains('live'));
  }

  Future<void> _onEndRequested(
    LiveRoomEndRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) {
      emit(const LiveRoomEnded());
      return;
    }

    emit(
      current.copyWith(
        isEnding: true,
        controller: null,
        isCameraInitialized: false,
        clearActionMessage: true,
      ),
    );

    final controller = current.controller;
    if (controller != null) {
      await _disposeCamera(controller);
    }

    String? endFailure;
    try {
      await _endLiveSession(current.session.id);
      _sessionTeardownDone = true;
    } on ApiException catch (e) {
      endFailure = e.message;
    } catch (e) {
      endFailure = e.toString();
    }

    // Guarantee the local teardown completes (camera, LiveKit, socket)
    // no matter what the server says, then ALWAYS leave the room.
    try {
      await _sessionRepository.disconnectRealtime();
    } catch (_) {}
    try {
      await _sessionRepository.disconnectMedia();
    } catch (_) {}
    await _hudSub?.cancel();
    _hudSub = null;
    await _mediaSub?.cancel();
    _mediaSub = null;

    if (isClosed) return;
    // Tell the LIVE feed screen this live ended so it disappears immediately.
    LiveFeedRefreshBus.instance.notifyLiveEnded(current.session.id);
    emit(const LiveRoomEnded());

    if (endFailure != null) {
      // The live may still be open on the server; the next start attempt
      // surfaces the conflict with the end-and-restart recovery path.
      debugPrint('Live end failed on server, room closed locally: $endFailure');
    }
  }

  Future<void> _onRemoteEnded(
    LiveRoomRemoteEnded event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) return;
    final controller = current.controller;
    // Drop the controller from the widget tree first (no rebuild can race
    // the slow Xiaomi teardown and render a disposed controller).
    if (controller != null) {
      emit(current.copyWith(controller: null, isCameraInitialized: false));
      await _disposeCamera(controller);
    }
    await _sessionRepository.disconnectRealtime();
    await _sessionRepository.disconnectMedia();
    await _hudSub?.cancel();
    _hudSub = null;
    await _mediaSub?.cancel();
    _mediaSub = null;
    _sessionTeardownDone = true;
    if (isClosed) return;
    // Tell the LIVE feed screen this live ended so it disappears immediately.
    LiveFeedRefreshBus.instance.notifyLiveEnded(current.session.id);
    emit(const LiveRoomEnded());
  }

  Future<void> _onAppPaused(
    LiveRoomAppPaused event,
    Emitter<LiveRoomState> emit,
  ) async {
    _appPaused = true;
    final current = _readyOrNull;
    if (current == null) return;
    final controller = current.controller;
    if (controller == null || !current.isCameraInitialized) return;

    // Emit null first so no HUD-triggered rebuild renders the disposed
    // controller during the slow camera teardown.
    emit(current.copyWith(controller: null, isCameraInitialized: false));
    await _disposeCamera(controller);
    if (isClosed) return;
  }

  Future<void> _onAppResumed(
    LiveRoomAppResumed event,
    Emitter<LiveRoomState> emit,
  ) async {
    _appPaused = false;
    final current = _readyOrNull;
    if (current == null) return;
    if (current.isMediaConnected) return;
    if (current.session.isLive && !current.isEnding) {
      await _recoverHostMedia(current.session.id, emit);
      if (_readyOrNull?.isMediaConnected == true) return;
    }
    if (current.controller != null && current.isCameraInitialized) return;

    final controller = await _initializeCamera(useFront: current.isFrontCamera);
    if (isClosed) return;
    emit(
      current.copyWith(
        controller: controller,
        isCameraInitialized: controller != null,
      ),
    );
  }

  void _onChatTapped(LiveRoomChatTapped event, Emitter<LiveRoomState> emit) {
    final current = _readyOrNull;
    if (current == null) return;
    emit(current.copyWith(isChatComposerVisible: true));
  }

  void _onChatComposerClosed(
    LiveRoomChatComposerClosed event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    emit(current.copyWith(isChatComposerVisible: false));
  }

  Future<void> _onChatMessageSubmitted(
    LiveRoomChatMessageSubmitted event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) return;
    final content = event.content.trim();
    if (content.isEmpty) return;

    emit(current.copyWith(isSendingChat: true, clearActionMessage: true));
    try {
      final message = await _sendLiveComment(
        liveId: current.session.id,
        content: content,
      );
      if (isClosed) return;
      final ready = _readyOrNull ?? current;
      final exists = ready.session.messages.any((m) => m.id == message.id);
      final messages = exists
          ? ready.session.messages
          : [...ready.session.messages, message];
      emit(
        ready.copyWith(
          session: ready.session.copyWith(messages: messages),
          isSendingChat: false,
          isChatComposerVisible: false,
        ),
      );
    } on ApiException catch (e) {
      emit(current.copyWith(isSendingChat: false, actionMessage: e.message));
    } catch (e) {
      emit(current.copyWith(isSendingChat: false, actionMessage: e.toString()));
    }
  }

  Future<void> _onLikeTapped(
    LiveRoomLikeTapped event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) return;
    try {
      final likeCount = await _likeLiveSession(current.session.id);
      if (isClosed) return;
      final ready = _readyOrNull ?? current;
      emit(
        ready.copyWith(
          session: ready.session.copyWith(likeCount: likeCount),
          floatingHeartBurst: ready.floatingHeartBurst + 1,
        ),
      );
    } on ApiException catch (e) {
      emit(current.copyWith(actionMessage: e.message));
    } catch (e) {
      emit(current.copyWith(actionMessage: e.toString()));
    }
  }

  void _onGiftBannerConsumed(
    LiveRoomGiftBannerConsumed event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null || current.giftBanner == null) return;
    emit(current.copyWith(giftBanner: null));
  }

  void _onHeartBurstConsumed(
    LiveRoomHeartBurstConsumed event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null || current.floatingHeartBurst == 0) return;
    emit(current.copyWith(floatingHeartBurst: 0));
  }

  String _moderationMessage(String type) {
    switch (type) {
      case 'chat_muted':
        return 'تم كتم دردشة مشاهد';
      case 'chat_unmuted':
        return 'تم إلغاء كتم دردشة مشاهد';
      case 'viewer_banned':
        return 'تم حظر مشاهد من البث';
      case 'viewer_unbanned':
        return 'تم إلغاء حظر مشاهد';
      default:
        return 'تحديث إشراف: $type';
    }
  }

  Future<void> _onRankingTapped(
    LiveRoomRankingTapped event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) return;
    try {
      final hourly = await _sessionRepository.loadHourlyRank(
        current.session.id,
      );
      if (isClosed) return;
      emit(
        current.copyWith(
          session: current.session.copyWith(
            hourlyRank: hourly.rank,
            hourlyRankingLabel: hourly.label,
          ),
        ),
      );
    } on ApiException catch (e) {
      emit(current.copyWith(actionMessage: e.message));
    } catch (e) {
      emit(current.copyWith(actionMessage: e.toString()));
    }
  }

  Future<void> _onGuestsChanged(
    LiveRoomGuestsChanged event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null || current.session.id.isEmpty) return;
    try {
      // One call now covers both the badge and the stage: the pending count is
      // derived from the same roster the multi-guest grid renders.
      final guests = await _sessionRepository.loadGuests(current.session.id);
      if (isClosed) return;
      final ready = _readyOrNull ?? current;
      emit(
        ready.copyWith(
          guests: guests,
          session: ready.session.copyWith(
            guestInviteCount: guests.where((g) => g.isPending).length,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _onBattleChanged(
    LiveRoomBattleChanged event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) return;
    final battle = event.battle?.withTimingFrom(current.battle);
    emit(
      current.copyWith(
        battle: battle,
        pendingCompetitionRequest: battle?.isActive == true
            ? null
            : current.pendingCompetitionRequest,
        isCompetitionActionBusy: false,
      ),
    );
    if (battle?.isActive != true) {
      await _sessionRepository.disconnectBattleOpponentMedia();
      return;
    }
    final opponentId = battle!.opponentLiveId(current.session.id);
    if (opponentId.isEmpty || opponentId == current.session.id) return;
    try {
      await _sessionRepository.connectBattleOpponentMedia(opponentId);
      if (isClosed) return;
      final ready = _readyOrNull;
      if (ready != null && ready.battle?.id == battle.id) {
        // The state identity change tells the stage to pick up battleMediaRoom;
        // subsequent track publications repaint through Room notifications.
        emit(ready.copyWith(battle: battle));
      }
    } catch (e) {
      if (isClosed) return;
      final ready = _readyOrNull;
      if (ready != null) {
        emit(
          ready.copyWith(
            actionMessage: 'بدأت المعركة لكن تعذر فتح فيديو الخصم: $e',
          ),
        );
      }
    }
  }

  /// Pulls the comment history again, keeping whatever the socket delivered
  /// since. Runs whenever the HUD socket (re)connects.
  Future<void> _onCommentsResync(
    LiveRoomCommentsResyncRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null || current.session.id.isEmpty) return;
    final liveId = current.session.id;
    try {
      final history = await _sessionRepository.loadComments(liveId);
      if (isClosed) return;
      final ready = _readyOrNull;
      if (ready == null || ready.session.id != liveId) return;
      final merged = mergeLiveChatMessages(history, ready.session.messages);
      LiveCompetitionRequest? pending = ready.pendingCompetitionRequest;
      for (final message in merged.reversed) {
        final request = _competitionRequestFrom(ready, message);
        if (request != null) {
          pending = request;
          break;
        }
      }
      emit(
        ready.copyWith(
          session: ready.session.copyWith(
            messages: merged
                .where((message) => !isLiveCompetitionRequest(message.body))
                .toList(growable: false),
          ),
          pendingCompetitionRequest: ready.isBattleActive ? null : pending,
        ),
      );
    } catch (_) {}
  }

  LiveCompetitionRequest? _competitionRequestFrom(
    LiveRoomReady current,
    LiveChatMessage message,
  ) {
    if (!isLiveCompetitionRequest(message.body)) return null;
    final userId = message.userId;
    if (userId == null || userId.isEmpty || userId == current.session.host.id) {
      return null;
    }
    // Do not require the roster to have refreshed yet here. The guest can tap
    // immediately after joining while the host's GET /guests is still in
    // flight. Acceptance validates the ACTIVE roster again before it calls
    // the battle API, so an ordinary viewer cannot start a match by typing
    // the same sentence.
    final displayName = message.username?.trim();
    return LiveCompetitionRequest(
      commentId: message.id,
      userId: userId,
      displayName: displayName?.isNotEmpty == true ? displayName! : 'ضيف',
      avatarUrl: message.avatarUrl,
    );
  }

  Future<void> _onCompetitionRequestAnswered(
    LiveRoomCompetitionRequestAnswered event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    final request = current?.pendingCompetitionRequest;
    if (current == null ||
        request == null ||
        request.commentId != event.commentId ||
        current.isCompetitionActionBusy) {
      return;
    }

    if (!event.accepted) {
      emit(current.copyWith(pendingCompetitionRequest: null));
      try {
        await _sessionRepository.deleteComment(
          liveId: current.session.id,
          commentId: request.commentId,
        );
      } catch (_) {}
      return;
    }

    if (current.isBattleActive) {
      emit(
        current.copyWith(
          pendingCompetitionRequest: null,
          actionMessage: 'هناك جولة منافسة نشطة بالفعل',
        ),
      );
      return;
    }

    final guestStillActive = current.activeGuests.any(
      (guest) => guest.userId == request.userId,
    );
    if (!guestStillActive) {
      emit(
        current.copyWith(
          pendingCompetitionRequest: null,
          actionMessage: 'غادر الضيف المسرح قبل بدء المنافسة',
        ),
      );
      return;
    }

    // Accepting only clears the request. Picking the opponent is the UI's job
    // now: a PK is live-vs-live on the server, and the guest who tapped
    // "أطلب بدء جولة منافسة" is standing on *this* stage, so they have no live
    // of their own to battle. This used to call auto-match, which silently
    // paired the host with an unrelated stranger — or answered
    // `404 No opponents available` and surfaced as a dead-end "تعذر بدء
    // المنافسة" whenever nobody else was broadcasting.
    // `LiveRoomCompetitionRequestPrompt` opens the opponent picker right after
    // dispatching this.
    emit(
      current.copyWith(
        pendingCompetitionRequest: null,
        isCompetitionActionBusy: false,
        clearActionMessage: true,
      ),
    );
    try {
      await _sessionRepository.deleteComment(
        liveId: current.session.id,
        commentId: request.commentId,
      );
    } catch (_) {}
  }

  /// This user accepting or declining an invite onto someone else's stage.
  Future<void> _onGuestInviteAnswered(
    LiveRoomGuestInviteAnswered event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    final invite = current?.pendingGuestInvite;
    if (current == null || invite == null) return;

    // Clear the prompt first either way: leaving it up through a failed accept
    // is what makes a stuck invite look like the button did nothing.
    emit(current.copyWith(pendingGuestInvite: null));

    if (!event.accepted) return;

    // Accepting means republishing this camera into the *inviter's* LiveKit
    // room, which tears down the publish feeding this host's own stream. Their
    // live would stay LIVE on the server with nothing going out, so refuse
    // rather than silently hijacking a broadcast that is already on air.
    if (invite.liveId != current.session.id) {
      emit(
        (_readyOrNull ?? current).copyWith(
          actionMessage:
              'لا يمكن الانضمام إلى مسرح بث آخر أثناء بثك الحالي. أنهِ بثك '
              'أولاً ثم اقبل الدعوة.',
        ),
      );
      return;
    }

    try {
      final creds = await _sessionRepository.acceptGuestInvite(invite.liveId);
      if (isClosed) return;
      final ready = _readyOrNull ?? current;
      if (!creds.isUsable) {
        emit(
          ready.copyWith(
            actionMessage:
                'قبلت الدعوة، لكن الخادم لم يرسل بيانات LiveKit للنشر.',
          ),
        );
        return;
      }
      await _sessionRepository.connectMedia(
        url: creds.url,
        token: creds.token,
        useFrontCamera: ready.isFrontCamera,
        mediaHints: creds.mediaHints,
      );
      if (isClosed) return;
      emit(
        (_readyOrNull ?? ready).copyWith(
          isMediaConnected: true,
          actionMessage: creds.role.toUpperCase() == 'CO_HOST'
              ? 'انضممت كمضيف مشارك.'
              : 'انضممت إلى المسرح.',
        ),
      );
      add(const LiveRoomGuestsChanged());
    } on ApiException catch (e) {
      if (!isClosed) {
        emit((_readyOrNull ?? current).copyWith(actionMessage: e.message));
      }
    } catch (e) {
      if (!isClosed) {
        emit((_readyOrNull ?? current).copyWith(actionMessage: e.toString()));
      }
    }
  }

  /// Host or moderator answering a viewer who asked to come on stage.
  Future<void> _onGuestRequestAnswered(
    LiveRoomGuestRequestAnswered event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null || current.session.id.isEmpty) return;
    final liveId = current.session.id;
    try {
      if (event.accepted) {
        await _sessionRepository.acceptGuest(
          liveId: liveId,
          userId: event.userId,
        );
      } else {
        await _sessionRepository.rejectGuest(
          liveId: liveId,
          userId: event.userId,
        );
      }
      if (isClosed) return;
      add(const LiveRoomGuestsChanged());
    } on ApiException catch (e) {
      if (!isClosed) {
        emit((_readyOrNull ?? current).copyWith(actionMessage: e.message));
      }
    } catch (e) {
      if (!isClosed) {
        emit((_readyOrNull ?? current).copyWith(actionMessage: e.toString()));
      }
    }
  }

  /// Arabic line for a `liveGuestUpdate.type`, or null when the roster refresh
  /// already tells the story on screen.
  String? _guestUpdateMessage(String type) {
    switch (type) {
      case 'joined':
        return 'انضم ضيف إلى المسرح.';
      case 'left':
        return 'غادر ضيف المسرح.';
      case 'kicked':
        return 'تمت إزالة ضيف من المسرح.';
      case 'requested':
        return 'طلب مشاهد الانضمام إلى المسرح.';
      case 'role':
        return 'تم تغيير دور أحد الضيوف.';
      default:
        return null;
    }
  }

  Future<void> _onGalleryChanged(
    LiveRoomGalleryChanged event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) return;
    try {
      final gallery = await _sessionRepository.loadGalleryCounts(
        current.session.id,
      );
      if (isClosed) return;
      final ready = _readyOrNull ?? current;
      emit(
        ready.copyWith(
          session: ready.session.copyWith(
            galleryCurrent: gallery.current,
            galleryTotal: gallery.total,
          ),
        ),
      );
    } catch (_) {}
  }

  void _onSettingsApplied(
    LiveRoomSettingsApplied event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    final s = event.session;
    emit(
      current.copyWith(
        session: current.session.copyWith(
          guestsEnabled: s.guestsEnabled,
          guestRequestMode: s.guestRequestMode,
          maxGuests: s.maxGuests,
          layout: s.layout,
          allowGuestCamera: s.allowGuestCamera,
          moderatorsCanManageGuests: s.moderatorsCanManageGuests,
        ),
        actionMessage: 'تم تحديث إعدادات البث',
      ),
    );
  }

  Future<void> _onModerationRequested(
    LiveRoomModerationRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) return;
    final liveId = current.session.id;
    try {
      switch (event.action) {
        case LiveRoomModerationAction.pin:
          await _sessionRepository.pinComment(
            liveId: liveId,
            commentId: event.commentId,
          );
          emit(current.copyWith(actionMessage: 'تم تثبيت التعليق'));
        case LiveRoomModerationAction.unpin:
          await _sessionRepository.unpinComment(
            liveId: liveId,
            commentId: event.commentId,
          );
          emit(current.copyWith(actionMessage: 'تم إلغاء التثبيت'));
        case LiveRoomModerationAction.deleteComment:
          await _sessionRepository.deleteComment(
            liveId: liveId,
            commentId: event.commentId,
          );
          final messages = current.session.messages
              .where((m) => m.id != event.commentId)
              .toList(growable: false);
          emit(
            current.copyWith(
              session: current.session.copyWith(messages: messages),
              actionMessage: 'تم حذف التعليق',
            ),
          );
        case LiveRoomModerationAction.muteChat:
          final userId = event.userId;
          if (userId == null || userId.isEmpty) {
            emit(current.copyWith(actionMessage: 'لا يوجد معرف مستخدم'));
            return;
          }
          await _sessionRepository.muteViewerChat(
            liveId: liveId,
            userId: userId,
          );
          emit(current.copyWith(actionMessage: 'تم كتم الدردشة'));
        case LiveRoomModerationAction.unmuteChat:
          final userId = event.userId;
          if (userId == null || userId.isEmpty) {
            emit(current.copyWith(actionMessage: 'لا يوجد معرف مستخدم'));
            return;
          }
          await _sessionRepository.unmuteViewerChat(
            liveId: liveId,
            userId: userId,
          );
          emit(current.copyWith(actionMessage: 'تم إلغاء كتم الدردشة'));
        case LiveRoomModerationAction.banViewer:
          final userId = event.userId;
          if (userId == null || userId.isEmpty) {
            emit(current.copyWith(actionMessage: 'لا يوجد معرف مستخدم'));
            return;
          }
          await _sessionRepository.banViewer(liveId: liveId, userId: userId);
          emit(current.copyWith(actionMessage: 'تم حظر المشاهد من البث'));
      }
    } on ApiException catch (e) {
      emit(current.copyWith(actionMessage: e.message));
    } catch (e) {
      emit(current.copyWith(actionMessage: e.toString()));
    }
  }

  void _onHudEvent(
    LiveRoomHudEventReceived event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    final hud = event.event;

    switch (hud) {
      case LiveHudGuestInviteEvent(:final liveId, :final hostName, :final role):
        // Arrives on the personal room, so it can reach a host who is already
        // broadcasting. Parked in state, not shouted once: accepting is a
        // deliberate tap and the prompt has to survive until it is answered.
        final who = (hostName == null || hostName.isEmpty)
            ? 'المضيف'
            : hostName;
        final target = liveId ?? current.session.id;
        if (target.isEmpty) return;
        emit(
          current.copyWith(
            pendingGuestInvite: LivePendingGuestInvite(
              liveId: target,
              hostName: who,
              role: role ?? 'GUEST',
            ),
          ),
        );
      case LiveHudGuestUpdateEvent(:final type, :final affectsStage):
        // The stage roster is authoritative on the server, so every change
        // re-reads it rather than trying to patch a card in place.
        if (affectsStage) {
          add(const LiveRoomGuestsChanged());
        }
        final note = _guestUpdateMessage(type);
        if (note != null) {
          emit(current.copyWith(actionMessage: note));
        }
      case LiveHudBattleEvent(:final battle):
        add(LiveRoomBattleChanged(battle));
      case LiveHudConnectionEvent(:final connected):
        // Comments, viewers and likes all ride this socket. The flag is kept in
        // state so the room can show a standing warning: a SnackBar alone
        // flashed past and left the host staring at a feed that never fills.
        if (connected) {
          emit(
            current.copyWith(
              isRealtimeConnected: true,
              clearActionMessage: current.actionMessage != null,
            ),
          );
          // The socket may have missed comments while it was down.
          add(const LiveRoomCommentsResyncRequested());
          return;
        }
        // Recover silently. A dropped HUD socket must not cover the live with
        // a red banner/SnackBar; Socket.IO keeps retrying in the background.
        emit(current.copyWith(isRealtimeConnected: false));
      case LiveHudCommentEvent(:final message):
        final competitionRequest = _competitionRequestFrom(current, message);
        if (competitionRequest != null) {
          emit(
            current.copyWith(
              pendingCompetitionRequest: current.isBattleActive
                  ? null
                  : competitionRequest,
            ),
          );
          return;
        }
        if (current.session.messages.any((m) => m.id == message.id)) {
          return;
        }
        emit(
          current.copyWith(
            session: current.session.copyWith(
              messages: capLiveChatMessages([
                ...current.session.messages,
                message,
              ]),
            ),
          ),
        );
      case LiveHudCommentDeletedEvent(:final commentId):
        emit(
          current.copyWith(
            session: current.session.copyWith(
              messages: current.session.messages
                  .where((m) => m.id != commentId)
                  .toList(growable: false),
            ),
          ),
        );
      case LiveHudCommentPinnedEvent(:final message):
        final others = current.session.messages
            .where((m) => m.id != message.id)
            .map((m) => m.isPinned ? m.copyWith(isPinned: false) : m)
            .toList(growable: false);
        emit(
          current.copyWith(
            session: current.session.copyWith(messages: [message, ...others]),
          ),
        );
      case LiveHudCommentUnpinnedEvent(:final commentId):
        emit(
          current.copyWith(
            session: current.session.copyWith(
              messages: current.session.messages
                  .map(
                    (m) => m.id == commentId ? m.copyWith(isPinned: false) : m,
                  )
                  .toList(growable: false),
            ),
          ),
        );
      case LiveHudModerationEvent(:final type):
        emit(current.copyWith(actionMessage: _moderationMessage(type)));
      case LiveHudViewersEvent(:final viewers):
        emit(
          current.copyWith(
            session: current.session.copyWith(viewerCount: viewers),
          ),
        );
      case LiveHudUserJoinedEvent(
        :final userId,
        :final username,
        :final viewers,
      ):
        if (userId == current.session.host.id) {
          if (viewers != null) {
            emit(
              current.copyWith(
                session: current.session.copyWith(viewerCount: viewers),
              ),
            );
          }
          return;
        }
        final joinText = '$username انضم';
        final messages = [
          ...current.session.messages,
          LiveChatMessage(
            id: 'join-$userId-${DateTime.now().microsecondsSinceEpoch}',
            text: joinText,
            userId: userId,
            username: username,
            isJoinEvent: true,
          ),
        ];
        emit(
          current.copyWith(
            session: current.session.copyWith(
              viewerCount: viewers ?? current.session.viewerCount,
              messages: capLiveChatMessages(messages),
            ),
          ),
        );
      case LiveHudLikeEvent(:final likeCount, :final userId):
        final isHostTap = userId != null && userId == current.session.host.id;
        emit(
          current.copyWith(
            session: current.session.copyWith(likeCount: likeCount),
            floatingHeartBurst: isHostTap
                ? current.floatingHeartBurst
                : current.floatingHeartBurst + 1,
          ),
        );
      case LiveHudEndedEvent():
        add(const LiveRoomRemoteEnded());
      case LiveHudGiftComboEvent(:final payload, :final totalEarnedCoins):
        final giftCombo = GiftComboPayload.fromMap(payload);
        if (giftCombo == null ||
            (giftCombo.liveId.isNotEmpty &&
                giftCombo.liveId != current.session.id)) {
          return;
        }
        var session = current.session;
        if (totalEarnedCoins != null) {
          session = session.copyWith(totalEarnedCoins: totalEarnedCoins);
        }
        emit(current.copyWith(session: session, latestGiftCombo: giftCombo));
      case LiveHudGiftEvent(
        :final summaryText,
        :final totalEarnedCoins,
        :final senderName,
        :final senderGifterLevel,
        :final senderAvatarUrl,
        :final giftName,
        :final giftIcon,
        :final giftImageUrl,
        :final quantity,
      ):
        var session = current.session;
        if (totalEarnedCoins != null) {
          session = session.copyWith(totalEarnedCoins: totalEarnedCoins);
        }
        final giftText = (summaryText != null && summaryText.isNotEmpty)
            ? summaryText
            : (senderName == null || senderName.isEmpty)
            ? null
            : '$senderName أرسل هدية';
        final messages = giftText == null
            ? session.messages
            : [
                ...session.messages,
                LiveChatMessage(
                  id: 'gift-${DateTime.now().millisecondsSinceEpoch}',
                  text: giftText,
                  showBadge: (senderGifterLevel ?? 0) > 0,
                  username: senderName,
                  gifterLevel: senderGifterLevel,
                ),
              ];
        // The chat line stays as the permanent record; the banner is the
        // celebration on top of the video, the way TikTok plays one.
        final banner = (senderName == null || senderName.isEmpty)
            ? current.giftBanner
            : LiveGiftBanner(
                id: 'gift-${DateTime.now().microsecondsSinceEpoch}',
                senderName: senderName,
                senderAvatarUrl: senderAvatarUrl,
                giftName: giftName,
                giftIcon: giftIcon,
                giftImageUrl: giftImageUrl,
                quantity: quantity,
                gifterLevel: senderGifterLevel,
              );

        emit(
          current.copyWith(
            session: session.copyWith(messages: messages),
            giftBanner: banner,
          ),
        );
      case LiveHudHourlyRankEvent(:final hourlyRank, :final label):
        emit(
          current.copyWith(
            session: current.session.copyWith(
              hourlyRank: hourlyRank ?? current.session.hourlyRank,
              hourlyRankingLabel: label ?? current.session.hourlyRankingLabel,
            ),
          ),
        );
    }
  }

  void _onGiftComboReceived(
    LiveRoomGiftComboReceived event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    // Only teardown blocks a gift. The session status is not checked: the
    // viewer accepts combos without it, and a host whose status had not yet
    // flipped to LIVE locally silently dropped gifts the viewer could send.
    if (current == null || current.isEnding) return;

    final payloadLiveId = event.payload.liveId.trim();
    if (payloadLiveId.isNotEmpty && payloadLiveId != current.session.id) {
      return;
    }

    emit(current.copyWith(latestGiftCombo: event.payload));
  }

  void _onGiftComboConsumed(
    LiveRoomGiftComboConsumed event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    // Only the combo that was actually presented is released, so a gift that
    // arrived while the previous one was playing is still rendered.
    if (current == null || !identical(current.latestGiftCombo, event.payload)) {
      return;
    }
    emit(current.copyWith(latestGiftCombo: null));
  }

  Future<void> _onMediaEvent(
    LiveRoomMediaEventReceived event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null ||
        current.isEnding ||
        _sessionTeardownDone ||
        _closing) {
      return;
    }
    switch (event.event.state) {
      case LiveMediaConnectionState.reconnecting:
        emit(current.copyWith(isMediaConnected: false));
        return;
      case LiveMediaConnectionState.reconnected:
        final track = _sessionRepository.localPreviewTrack as VideoTrack?;
        emit(
          current.copyWith(
            isMediaConnected: track != null,
            localVideoTrack: track,
          ),
        );
        return;
      case LiveMediaConnectionState.disconnected:
        emit(current.copyWith(isMediaConnected: false, localVideoTrack: null));
        if (!_appPaused) {
          await _recoverHostMedia(current.session.id, emit);
        }
        return;
    }
  }

  /// Re-starting an already-LIVE session is the documented host token refresh
  /// path. Reusing the JWT kept by the old Room makes a hard disconnect remain
  /// permanent after token expiry or a failed ICE restart.
  Future<void> _recoverHostMedia(
    String liveId,
    Emitter<LiveRoomState> emit,
  ) async {
    if (_mediaRecoveryInFlight ||
        _sessionTeardownDone ||
        _appPaused ||
        _closing) {
      return;
    }
    _mediaRecoveryInFlight = true;
    try {
      for (var attempt = 1; attempt <= 4; attempt++) {
        if (isClosed || _sessionTeardownDone || _appPaused) return;
        final before = _readyOrNull;
        if (before == null || before.session.id != liveId || before.isEnding) {
          return;
        }
        if (attempt > 1) {
          await Future<void>.delayed(Duration(seconds: attempt - 1));
        }
        if (isClosed || _sessionTeardownDone || _appPaused) return;

        try {
          final refreshed = await _sessionRepository.reconnectHostSession(
            liveId,
          );
          final token = refreshed.liveKitToken;
          final url = refreshed.liveKitUrl;
          if (token == null || token.isEmpty || url == null || url.isEmpty) {
            throw StateError('LiveKit token/url missing after host reconnect');
          }
          await _sessionRepository.connectMedia(
            url: url,
            token: token,
            useFrontCamera: before.isFrontCamera,
            mediaHints: refreshed.mediaHints,
          );
          if (isClosed || _sessionTeardownDone) return;
          final ready = _readyOrNull;
          if (ready == null || ready.session.id != liveId) return;
          final track = _sessionRepository.localPreviewTrack as VideoTrack?;
          final mediaUp = _sessionRepository.isMediaConnected && track != null;
          if (!mediaUp) {
            throw StateError('Host video track was not republished');
          }
          emit(
            ready.copyWith(
              session: ready.session.copyWith(
                liveKitToken: token,
                liveKitUrl: url,
                mediaHints: refreshed.mediaHints,
              ),
              controller: null,
              isCameraInitialized: false,
              isMediaConnected: true,
              localVideoTrack: track,
              clearActionMessage: true,
            ),
          );
          return;
        } catch (e) {
          debugPrint('Host media recovery attempt $attempt failed: $e');
          final ready = _readyOrNull;
          if (ready != null && ready.session.id == liveId && !isClosed) {
            emit(
              ready.copyWith(
                isMediaConnected: false,
                localVideoTrack: null,
                clearActionMessage: true,
              ),
            );
          }
        }
      }
    } finally {
      _mediaRecoveryInFlight = false;
    }
  }

  void _onEffectsTapped(
    LiveRoomEffectsTapped event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    if (current.isMediaConnected && current.controller == null) {
      emit(
        current.copyWith(
          actionMessage:
              'تأثيرات الوجه تحتاج معاينة الكاميرا المحلية؛ أثناء البث عبر LiveKit غير متاحة حالياً',
        ),
      );
      return;
    }
    final next = current.effectsPanelMode == LiveEffectsPanelMode.hidden
        ? LiveEffectsPanelMode.tray
        : LiveEffectsPanelMode.hidden;
    emit(current.copyWith(effectsPanelMode: next));
  }

  void _onEffectsPanelModeChanged(
    LiveRoomEffectsPanelModeChanged event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    emit(current.copyWith(effectsPanelMode: event.mode));
  }

  void _onEffectSelected(
    LiveRoomEffectSelected event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    final effect = LiveEffectsCatalog.byId(event.effectId);
    emit(
      current.copyWith(
        selectedEffectId: effect.id,
        effectsCategoryId: effect.isClear
            ? current.effectsCategoryId
            : effect.categoryId,
      ),
    );
  }

  void _onEffectsCategorySelected(
    LiveRoomEffectsCategorySelected event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    emit(current.copyWith(effectsCategoryId: event.categoryId));
  }

  Future<void> _onFlipCamera(
    LiveRoomFlipCameraRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null || _cameraOpInFlight) return;
    _cameraOpInFlight = true;
    final nextIsFront = !current.isFrontCamera;

    try {
      if (current.isMediaConnected) {
        try {
          await _sessionRepository.flipMediaCamera(useFront: nextIsFront);
          if (isClosed) return;
          emit(
            current.copyWith(
              isFrontCamera: nextIsFront,
              localVideoTrack:
                  _sessionRepository.localPreviewTrack as VideoTrack?,
            ),
          );
        } catch (e) {
          if (isClosed) return;
          emit(
            current.copyWith(actionMessage: 'تعذر تبديل كاميرا LiveKit: $e'),
          );
        }
        return;
      }

      final oldController = current.controller;
      if (oldController == null || !current.isCameraInitialized) return;

      // Drop the controller from the widget tree BEFORE disposing it — same
      // reason as in _publishLiveKitAfterPreview: a HUD-triggered rebuild
      // during the slow Xiaomi teardown would render a disposed controller
      // and freeze the camera.
      emit(
        current.copyWith(
          controller: null,
          isCameraInitialized: false,
          isFrontCamera: nextIsFront,
        ),
      );
      await _disposeCamera(oldController);
      if (isClosed) return;

      final controller = await _initializeCamera(useFront: nextIsFront);
      if (isClosed) {
        if (controller != null) await _disposeCamera(controller);
        return;
      }
      if (controller != null) {
        emit(
          current.copyWith(
            controller: controller,
            isCameraInitialized: true,
            isFrontCamera: nextIsFront,
          ),
        );
        return;
      }

      final fallback = await _initializeCamera(useFront: !nextIsFront);
      if (isClosed) {
        if (fallback != null) await _disposeCamera(fallback);
        return;
      }
      emit(
        current.copyWith(
          controller: fallback,
          isCameraInitialized: fallback != null,
          isFrontCamera: !nextIsFront,
          actionMessage: fallback == null ? 'تعذر فتح الكاميرا' : null,
        ),
      );
    } finally {
      _cameraOpInFlight = false;
    }
  }

  void _onMirrorToggled(
    LiveRoomMirrorToggled event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    emit(current.copyWith(isMirrorEnabled: !current.isMirrorEnabled));
  }

  Future<void> _onMicMuteToggled(
    LiveRoomMicMuteToggled event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) return;
    final next = !current.isMicMuted;
    emit(current.copyWith(isMicMuted: next));
    if (current.isMediaConnected) {
      await _sessionRepository.setMicrophoneEnabled(!next);
    }
  }

  Future<void> _onTitleSubmitted(
    LiveRoomTitleSubmitted event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) return;
    final title = event.title.trim();
    if (title.isEmpty) return;
    try {
      final updated = await _updateLiveTitle(
        liveId: current.session.id,
        title: title,
      );
      if (isClosed) return;
      final ready = _readyOrNull ?? current;
      emit(
        ready.copyWith(
          session: ready.session.copyWith(
            title: updated.title ?? title,
            host: ready.session.host,
          ),
          showLiveTitleBadge: false,
          actionMessage: 'تم تحديث عنوان البث',
        ),
      );
    } on ApiException catch (e) {
      emit(current.copyWith(actionMessage: e.message));
    } catch (e) {
      emit(current.copyWith(actionMessage: e.toString()));
    }
  }

  void _onStabilizationToggled(
    LiveRoomStabilizationToggled event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    emit(
      current.copyWith(isStabilizationEnabled: !current.isStabilizationEnabled),
    );
  }

  void _onNoiseReductionToggled(
    LiveRoomNoiseReductionToggled event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    emit(
      current.copyWith(
        isNoiseReductionEnabled: !current.isNoiseReductionEnabled,
      ),
    );
  }

  void _onAiContentToggled(
    LiveRoomAiContentToggled event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    emit(current.copyWith(isAiContentTagged: !current.isAiContentTagged));
  }

  void _onPauseLiveTapped(
    LiveRoomPauseLiveTapped event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    // Pause is client-only — no backend pause API in lives docs.
    emit(
      current.copyWith(
        isLivePaused: !current.isLivePaused,
        actionMessage: current.isLivePaused
            ? null
            : 'إيقاف مؤقت محلي فقط (لا يوجد API للإيقاف المؤقت)',
      ),
    );
  }

  Future<void> _onMenuDestination(
    LiveRoomMenuDestinationRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    final current = _readyOrNull;
    if (current == null) return;

    switch (event.destination) {
      case LiveRoomMenuDestination.liveTitle:
        return;
      case LiveRoomMenuDestination.comments:
        emit(current.copyWith(isChatComposerVisible: true));
      case LiveRoomMenuDestination.settings:
        // Sheet opened from presentation layer.
        return;
      case LiveRoomMenuDestination.liveGifts:
        emit(
          current.copyWith(
            actionMessage:
                'كتالوج الهدايا غير متوفر في مستندات lives (يحتاج ../gifts/mobile-api.md)',
            showLiveGiftsBadge: false,
          ),
        );
      default:
        emit(
          current.copyWith(
            actionMessage:
                'هذه الميزة بانتظار تأكيد الـ backend / غير موثّقة في lives',
          ),
        );
    }
  }

  void _onShareContactSelected(
    LiveRoomShareContactSelected event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    emit(
      current.copyWith(
        actionMessage: 'قائمة جهات المشاركة غير متوفرة من الـ backend بعد',
      ),
    );
  }

  void _onShareChannelRequested(
    LiveRoomShareChannelRequested event,
    Emitter<LiveRoomState> emit,
  ) {
    // Clipboard / url_launcher stay in presentation; no share API in docs.
  }

  void _onClearActionMessage(
    LiveRoomClearActionMessage event,
    Emitter<LiveRoomState> emit,
  ) {
    final current = _readyOrNull;
    if (current == null) return;
    emit(current.copyWith(clearActionMessage: true));
  }

  void _onUiAction(LiveRoomEvent event, Emitter<LiveRoomState> emit) {}

  @override
  Future<void> close() async {
    _closing = true;
    final giftLiveId = _giftJoinedLiveId;
    _giftJoinedLiveId = null;
    if (giftLiveId != null && giftLiveId.isNotEmpty) {
      _giftSocketService.leaveLive(giftLiveId);
    }
    await _mediaSub?.cancel();
    _mediaSub = null;
    await _hudSub?.cancel();
    _hudSub = null;
    await _giftComboSub?.cancel();
    _giftComboSub = null;
    final current = _readyOrNull;
    final controller = current?.controller;
    if (controller != null) {
      await _disposeCamera(controller);
    }

    // Host must POST /end — do not only disconnect LiveKit/Socket (mobile-api §1).
    if (!_sessionTeardownDone &&
        current != null &&
        current.session.id.isNotEmpty &&
        current.session.isLive) {
      try {
        await _endLiveSession(current.session.id);
        _sessionTeardownDone = true;
      } catch (_) {
        await _sessionRepository.disconnectRealtime();
        await _sessionRepository.disconnectMedia();
      }
    } else {
      await _sessionRepository.disconnectRealtime();
      await _sessionRepository.disconnectMedia();
    }
    return super.close();
  }
}
