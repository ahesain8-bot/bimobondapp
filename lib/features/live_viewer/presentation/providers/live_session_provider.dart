import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../data/services/fake_livekit_service.dart'
    show LiveKitService, LiveKitServiceProxy, LiveKitConnectionState;
import '../../data/services/fake_socket_service.dart'
    show SocketService, SocketServiceProxy;
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../domain/entities/socket_event.dart';
import 'live_dependencies.dart';
import 'live_feed_provider.dart';

/// UI state for the currently active live room only.
class LiveSessionUiState {
  final LiveSessionEntity? session;
  final List<CommentEntity> comments;
  final List<GiftSentEntity> recentGifts;
  final GiftSentEntity? activeGiftAnimation;
  final int floatingHeartBurst;
  final int coinDelta;
  final bool showJoinSuccess;
  final List<String> topViewerAvatars;
  final int pkScoreLeft;
  final int pkScoreRight;
  final CommentEntity? pinnedComment;
  final bool chatMuted;
  final String? moderationBanner;
  final String? currentUserId;

  const LiveSessionUiState({
    this.session,
    this.comments = const [],
    this.recentGifts = const [],
    this.activeGiftAnimation,
    this.floatingHeartBurst = 0,
    this.coinDelta = 0,
    this.showJoinSuccess = false,
    this.topViewerAvatars = const [],
    this.pkScoreLeft = 0,
    this.pkScoreRight = 0,
    this.pinnedComment,
    this.chatMuted = false,
    this.moderationBanner,
    this.currentUserId,
  });

  LiveConnectionState get connectionState =>
      session?.connectionState ?? LiveConnectionState.idle;

  LiveEntity? get live => session?.live;

  bool get isPk => live?.metadata?['isPk'] == true;

  LiveSessionUiState copyWith({
    LiveSessionEntity? session,
    List<CommentEntity>? comments,
    List<GiftSentEntity>? recentGifts,
    GiftSentEntity? activeGiftAnimation,
    bool clearGiftAnimation = false,
    int? floatingHeartBurst,
    int? coinDelta,
    bool? showJoinSuccess,
    List<String>? topViewerAvatars,
    int? pkScoreLeft,
    int? pkScoreRight,
    CommentEntity? pinnedComment,
    bool clearPinnedComment = false,
    bool? chatMuted,
    String? moderationBanner,
    bool clearModerationBanner = false,
    String? currentUserId,
  }) {
    return LiveSessionUiState(
      session: session ?? this.session,
      comments: comments ?? this.comments,
      recentGifts: recentGifts ?? this.recentGifts,
      activeGiftAnimation: clearGiftAnimation
          ? null
          : (activeGiftAnimation ?? this.activeGiftAnimation),
      floatingHeartBurst: floatingHeartBurst ?? this.floatingHeartBurst,
      coinDelta: coinDelta ?? this.coinDelta,
      showJoinSuccess: showJoinSuccess ?? this.showJoinSuccess,
      topViewerAvatars: topViewerAvatars ?? this.topViewerAvatars,
      pkScoreLeft: pkScoreLeft ?? this.pkScoreLeft,
      pkScoreRight: pkScoreRight ?? this.pkScoreRight,
      pinnedComment: clearPinnedComment
          ? null
          : (pinnedComment ?? this.pinnedComment),
      chatMuted: chatMuted ?? this.chatMuted,
      moderationBanner: clearModerationBanner
          ? null
          : (moderationBanner ?? this.moderationBanner),
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }
}

/// Internal holder for a single live (active or preloaded) so the notifier
/// can keep more than one LiveKit / socket connection alive at a time.
class _LiveSessionData {
  _LiveSessionData({
    required this.live,
    required this.liveKit,
    required this.socket,
    required this.uiState,
  });

  final LiveEntity live;
  final LiveKitService liveKit;
  final SocketService socket;
  LiveSessionUiState uiState;
  StreamSubscription<SocketEvent>? socketSub;
}

/// Manages exactly one active live at a time (TikTok vertical swipe),
/// and preloads the next live in the background so the user never sees
/// the "Connecting" overlay when swiping down.
class ActiveLiveNotifier extends StateNotifier<LiveSessionUiState> {
  final Ref _ref;
  StreamSubscription<SocketEvent>? _socketSub;
  _LiveSessionData? _active;
  _LiveSessionData? _preloaded;
  _LiveSessionData? _previous; // last active live, kept alive for instant swipe-back
  bool _busy = false;
  bool _disposed = false;
  bool _teardownInProgress = false;
  LiveEntity? _pendingActivate;
  String? _preloadingId; // prevents concurrent preload races
  String? _currentUserId;

  ActiveLiveNotifier(this._ref) : super(const LiveSessionUiState());

  String? get activeLiveId => _active?.live.id;

  LiveKitServiceProxy? get _liveKitProxy {
    final service = _ref.read(liveKitServiceProvider);
    return service is LiveKitServiceProxy ? service : null;
  }

  SocketServiceProxy? get _socketProxy {
    final service = _ref.read(socketServiceProvider);
    return service is SocketServiceProxy ? service : null;
  }

  Future<void> activate(LiveEntity live) async {
    final sw = Stopwatch()..start();
    debugPrint('⏱️ [SESSION] activate() START: liveId=${live.id}, activeLiveId=${_active?.live.id}, preloadedId=${_preloaded?.live.id}, previousId=${_previous?.live.id}, teardownInProgress=$_teardownInProgress');
    if (_disposed) return;
    if (_busy) {
      debugPrint('⏱️ [SESSION] Busy, queuing activate for: ${live.id} (${sw.elapsedMilliseconds}ms)');
      _pendingActivate = live;
      return;
    }
    if (_active != null &&
        _active!.live.id == live.id &&
        _active!.liveKit.state == LiveKitConnectionState.connected) {
      debugPrint('⏱️ [SESSION] Already connected to ${live.id}, skipping activate (${sw.elapsedMilliseconds}ms)');
      // Re-point the proxies at this session — the proxy may still be
      // pointing at a previous/preloaded session's room after a
      // swipe-back or re-activation, which would cause the video widget
      // to render nothing (black screen).
      _setProxyDelegates(_active!);
      _resumeAudio(_active!);
      // If uiState was set to networkLost by a stale socket event but
      // LiveKit is still connected, restore the connected state.
      if (_active!.uiState.connectionState != LiveConnectionState.connected) {
        _active!.uiState = _active!.uiState.copyWith(
          session: _active!.uiState.session!.copyWith(
            connectionState: LiveConnectionState.connected,
            isSocketConnected: true,
            isLiveKitConnected: true,
          ),
        );
      }
      _emit(_active!);
      return;
    }

    // Wait for teardown to complete if in progress
    if (_teardownInProgress) {
      debugPrint('⏱️ [SESSION] Waiting for teardown to complete (${sw.elapsedMilliseconds}ms)');
      await Future.delayed(const Duration(milliseconds: 100));
      if (_teardownInProgress) {
        debugPrint('⏱️ [SESSION] Teardown still in progress, queuing activate (${sw.elapsedMilliseconds}ms)');
        _pendingActivate = live;
        return;
      }
      // Teardown completed, continue with activation
      debugPrint('⏱️ [SESSION] Teardown completed, continuing activation (${sw.elapsedMilliseconds}ms)');
    }

    _busy = true;
    _pendingActivate = null;
    try {
      // If the requested live is the previous session (swipe back),
      // adopt it instantly — the video was never stopped, just switch
      // the proxy back so the LiveVideoPlayer re-attaches to this room.
      if (_previous?.live.id == live.id) {
        debugPrint('⏱️ [SESSION] Adopting previous session (swipe back): ${live.id} (${sw.elapsedMilliseconds}ms)');
        final oldActive = _active;
        final oldPreloaded = _preloaded;
        final session = _previous!;
        _previous = null;
        _active = session;
        _preloaded = null; // will be re-triggered by feed listener
        // Move old active to _previous BEFORE _emit so the preload
        // listener sees the correct _previous and skips preloading it.
        if (oldActive != null && oldActive.live.id != session.live.id) {
          _previous = oldActive;
          _pauseAudio(oldActive);
        }
        _resumeAudio(session);
        // Reset connection state to connected — the session was in
        // _previous and may have received a stale networkLost/error
        // state from a transient socket disconnect while backgrounded.
        // If LiveKit is still connected, the session is fine.
        if (session.liveKit.state == LiveKitConnectionState.connected) {
          session.uiState = session.uiState.copyWith(
            session: session.uiState.session!.copyWith(
              connectionState: LiveConnectionState.connected,
              isSocketConnected: true,
              isLiveKitConnected: true,
            ),
          );
        }
        _setProxyDelegates(session);
        _emit(session);
        // Tear down old preloaded in background (it's for a different live now)
        if (oldPreloaded != null && oldPreloaded.live.id != session.live.id) {
          unawaited(_teardown(oldPreloaded));
        }
        debugPrint('⏱️ [SESSION] Previous session adopted: ${live.id} (${sw.elapsedMilliseconds}ms)');
        return;
      }

      // If the requested live is already preloaded, adopt it instantly.
      if (_preloaded?.live.id == live.id) {
        debugPrint('⏱️ [SESSION] Adopting preloaded session: ${live.id} (${sw.elapsedMilliseconds}ms)');
        final adopted = await _adoptPreloaded();
        if (!adopted) {
          debugPrint('⏱️ [SESSION] Preload adoption failed, starting fresh session (${sw.elapsedMilliseconds}ms)');
          // Fallback: start a fresh session if adoption failed
          await _teardown(_preloaded);
          _preloaded = null;
          // Continue to fresh session creation below
        } else {
          debugPrint('⏱️ [SESSION] activate() COMPLETE (adopted): ${live.id} (${sw.elapsedMilliseconds}ms)');
          return;
        }
      }

      debugPrint('⏱️ [SESSION] Starting fresh session for: ${live.id} (${sw.elapsedMilliseconds}ms)');
      // Starting a fresh live: tear down stale sessions, then build a new one.
      // Keep _previous alive if it matches (handled above), otherwise tear it down.
      // Move active to previous (keep alive in background) if no previous yet
      if (_active != null && _previous == null) {
        _previous = _active;
        _pauseAudio(_active!);
      } else {
        await _teardown(_active);
      }
      await _teardown(_preloaded);
      _active = null;
      _preloaded = null;
      if (_disposed) return;

      final liveKit = _ref.read(liveKitServiceFactoryProvider)();
      final socket = _ref.read(socketServiceFactoryProvider)();
      final session = _LiveSessionData(
        live: live,
        liveKit: liveKit,
        socket: socket,
        uiState: _initialUiState(live),
      );
      _active = session;
      _setProxyDelegates(session);
      _emit(session);

      await _runSession(session);
      debugPrint('⏱️ [SESSION] activate() COMPLETE (fresh): ${live.id} (${sw.elapsedMilliseconds}ms)');
    } finally {
      _busy = false;
      final pending = _pendingActivate;
      _pendingActivate = null;
      if (!_disposed && pending != null && pending.id != _active?.live.id) {
        debugPrint('⏱️ [SESSION] Processing pending activate: ${pending.id} (${sw.elapsedMilliseconds}ms)');
        await activate(pending);
      }
    }
  }

  /// Preloads [live] in the background so the next swipe is instant.
  /// Safe to call repeatedly; duplicate or active ids are ignored.
  Future<void> preload(LiveEntity live) async {
    debugPrint('⏱️ [SESSION] preload() START: liveId=${live.id}, activeLiveId=${_active?.live.id}, preloadedId=${_preloaded?.live.id}, previousId=${_previous?.live.id}');
    if (_disposed) return;
    if (_preloaded?.live.id == live.id || _active?.live.id == live.id) {
      debugPrint('⏱️ [SESSION] Preload skipped: already active or preloaded');
      return;
    }
    // If the live is already in _previous, no need to preload — it's alive
    if (_previous?.live.id == live.id) {
      debugPrint('⏱️ [SESSION] Preload skipped: already in _previous');
      return;
    }
    // Prevent concurrent preload races: if a preload for this live is
    // already in progress, skip. This prevents duplicate _runSession
    // calls that cause LiveKit timeouts and stale state.
    if (_preloadingId == live.id) {
      debugPrint('⏱️ [SESSION] Preload skipped: already preloading this live');
      return;
    }
    _preloadingId = live.id;

    debugPrint('⏱️ [SESSION] Starting preload for: ${live.id}');
    await _teardown(_preloaded);
    _preloaded = null;

    final liveKit = _ref.read(liveKitServiceFactoryProvider)();
    final socket = _ref.read(socketServiceFactoryProvider)();
    final session = _LiveSessionData(
      live: live,
      liveKit: liveKit,
      socket: socket,
      uiState: _initialUiState(live),
    );
    _preloaded = session;

    // Run in the background without blocking the current live.
    unawaited(() async {
      try {
        await _runSession(session);
        // Only pause audio if the session is STILL the preloaded one.
        // If it was adopted as _active while _runSession was running,
        // pausing its audio would mute the currently-visible live!
        if (session == _preloaded) {
          _pauseAudio(session);
          debugPrint('⏱️ [SESSION] preload() COMPLETE: ${live.id} (audio paused)');
        } else {
          debugPrint('⏱️ [SESSION] preload() COMPLETE: ${live.id} (NOT pausing audio — session is now active/previous)');
        }
      } catch (e) {
        debugPrint('⏱️ [SESSION] preload() FAILED: ${live.id} - $e');
      } finally {
        if (_preloadingId == live.id) _preloadingId = null;
      }
    }());
  }

  Future<bool> _adoptPreloaded() async {
    final sw = Stopwatch()..start();
    final session = _preloaded;
    if (session == null) return false;

    final sessionState = session.uiState.connectionState;
    debugPrint('⏱️ [SESSION] _adoptPreloaded INSTANT SWAP: ${session.live.id}, state=$sessionState (${sw.elapsedMilliseconds}ms)');
    // Don't adopt a session in a terminal/error state — fall back to fresh
    if (sessionState == LiveConnectionState.error ||
        sessionState == LiveConnectionState.liveEnded ||
        sessionState == LiveConnectionState.banned) {
      debugPrint('⏱️ [SESSION] Preloaded session in bad state ($sessionState), falling back (${sw.elapsedMilliseconds}ms)');
      await _teardown(_preloaded);
      _preloaded = null;
      return false;
    }

    // Verify LiveKit is actually connected — the uiState may be stale
    // if a concurrent preload race caused a LiveKit timeout.
    if (session.liveKit.state != LiveKitConnectionState.connected) {
      debugPrint('⏱️ [SESSION] Preloaded session LiveKit not connected (state=${session.liveKit.state}), falling back (${sw.elapsedMilliseconds}ms)');
      await _teardown(_preloaded);
      _preloaded = null;
      return false;
    }

    // SWAP INSTANTLY — no waiting, no teardown before swap.
    // Move the old active to _previous (keep alive for swipe-back),
    // tear down the old _previous (we only keep one previous alive).
    final oldActive = _active;
    final oldPrevious = _previous;
    _preloaded = null;
    _active = session;
    // Move old active to _previous BEFORE _emit so the preload listener
    // sees the correct _previous and skips preloading it.
    if (oldActive != null && oldActive.live.id != session.live.id) {
      _previous = oldActive;
      _pauseAudio(oldActive);
    }
    _resumeAudio(session);
    // Reset connection state to connected — the preloaded session may
    // have received a stale networkLost state while backgrounded.
    if (session.liveKit.state == LiveKitConnectionState.connected) {
      session.uiState = session.uiState.copyWith(
        session: session.uiState.session!.copyWith(
          connectionState: LiveConnectionState.connected,
          isSocketConnected: true,
          isLiveKitConnected: true,
        ),
      );
    }
    _setProxyDelegates(session);
    _emit(session);
    debugPrint('⏱️ [SESSION] _adoptPreloaded SWAP DONE: ${session.live.id} (${sw.elapsedMilliseconds}ms)');
    if (oldActive != null && oldActive.live.id != session.live.id) {
      debugPrint('⏱️ [SESSION] Moved old active to _previous: ${oldActive.live.id} (${sw.elapsedMilliseconds}ms)');
    }

    // Tear down the old _previous in the background (only keep one previous)
    if (oldPrevious != null && oldPrevious.live.id != session.live.id) {
      debugPrint('⏱️ [SESSION] Background teardown of old _previous: ${oldPrevious.live.id}');
      unawaited(_teardown(oldPrevious));
    }

    debugPrint('⏱️ [SESSION] _adoptPreloaded COMPLETE: ${session.live.id} (${sw.elapsedMilliseconds}ms)');
    return true; // Adoption succeeded
  }

  LiveSessionUiState _initialUiState(LiveEntity live) {
    final isPk = live.metadata?['isPk'] == true;
    final initialAvatars = _avatarsFromLive(live);

    return LiveSessionUiState(
      session: LiveSessionEntity(
        live: live,
        connectionState: LiveConnectionState.connecting,
      ),
      topViewerAvatars: initialAvatars.isNotEmpty
          ? initialAvatars
          : List.generate(
              3,
              (i) => 'https://i.pravatar.cc/150?u=${live.id}_v$i',
            ),
      pkScoreLeft: isPk
          ? ((live.metadata?['scoreLeft'] as num?)?.toInt() ??
                (8000 + Random().nextInt(8000)))
          : 0,
      pkScoreRight: isPk
          ? ((live.metadata?['scoreRight'] as num?)?.toInt() ??
                (1000 + Random().nextInt(3000)))
          : 0,
      currentUserId: _currentUserId,
    );
  }

  void _setProxyDelegates(_LiveSessionData session) {
    _liveKitProxy?.setDelegate(session.liveKit);
    _socketProxy?.setDelegate(session.socket);
  }

  /// Pauses audio for a background session (previous/preloaded) by
  /// unsubscribing from all remote audio tracks. The LiveKit connection
  /// stays alive so swipe-back is instant; only the audio is muted.
  void _pauseAudio(_LiveSessionData session) {
    debugPrint('⏱️ [SESSION] _pauseAudio: ${session.live.id}');
    final room = session.liveKit.room;
    if (room == null) return;
    for (final p in room.remoteParticipants.values) {
      for (final pub in p.audioTrackPublications) {
        try {
          if (pub.subscribed) pub.unsubscribe();
        } catch (e) {
          debugPrint('⏱️ [SESSION] _pauseAudio error: $e');
        }
      }
    }
  }

  /// Resumes audio for a session that is becoming active again by
  /// resubscribing to all remote audio tracks.
  void _resumeAudio(_LiveSessionData session) {
    debugPrint('⏱️ [SESSION] _resumeAudio: ${session.live.id}');
    final room = session.liveKit.room;
    if (room == null) return;
    for (final p in room.remoteParticipants.values) {
      for (final pub in p.audioTrackPublications) {
        try {
          if (!pub.subscribed) pub.subscribe();
        } catch (e) {
          debugPrint('⏱️ [SESSION] _resumeAudio error: $e');
        }
      }
    }
  }

  void _emit(_LiveSessionData session) {
    if (session == _active && !_disposed) state = session.uiState;
  }

  bool _isRelevant(_LiveSessionData session) {
    if (_disposed) return false;
    return session == _active || session == _preloaded || session == _previous;
  }

  Future<void> _teardown(_LiveSessionData? session) async {
    if (session == null) return;
    final sw = Stopwatch()..start();
    debugPrint('⏱️ [SESSION] _teardown START: liveId=${session.live.id}, isPreloaded=${session == _preloaded}');

    _teardownInProgress = true;
    session.socketSub?.cancel();
    session.socketSub = null;

    final id = session.live.id;
    if (id.isNotEmpty) {
      try {
        await _ref.read(leaveLiveUseCaseProvider)(id);
      } catch (_) {}
    }

    try {
      await session.socket.disconnect();
    } catch (_) {}
    try {
      await session.liveKit.disconnect();
    } catch (_) {}
    try {
      session.socket.dispose();
    } catch (_) {}
    try {
      session.liveKit.dispose();
    } catch (_) {}

    if (session == _active) {
      debugPrint('⏱️ [SESSION] Clearing proxy delegates for active session (${sw.elapsedMilliseconds}ms)');
      _liveKitProxy?.setDelegate(null);
      _socketProxy?.setDelegate(null);
    }
    _teardownInProgress = false;
    debugPrint('⏱️ [SESSION] _teardown COMPLETE: ${session.live.id} (${sw.elapsedMilliseconds}ms)');
    // Process pending activate if any
    final pending = _pendingActivate;
    if (pending != null && !_disposed && !_busy) {
      _pendingActivate = null;
      debugPrint('⏱️ [SESSION] Processing pending activate after teardown: ${pending.id}');
      unawaited(activate(pending));
    }
  }

  Future<void> _runSession(_LiveSessionData session) async {
    final sw = Stopwatch()..start();
    final live = session.live;
    debugPrint('⏱️ [SESSION] _runSession START: liveId=${live.id}, isPreloaded=${session == _preloaded}');
    if (live.status == LiveStatus.ended) {
      debugPrint('⏱️ [SESSION] Live already ended: ${live.id} (${sw.elapsedMilliseconds}ms)');
      session.uiState = session.uiState.copyWith(
        session: session.uiState.session!.copyWith(
          connectionState: LiveConnectionState.liveEnded,
        ),
      );
      _emit(session);
      return;
    }
    if (live.status == LiveStatus.banned) {
      debugPrint('⏱️ [SESSION] Live banned: ${live.id} (${sw.elapsedMilliseconds}ms)');
      session.uiState = session.uiState.copyWith(
        session: session.uiState.session!.copyWith(
          connectionState: LiveConnectionState.banned,
        ),
      );
      _emit(session);
      return;
    }

    debugPrint('⏱️ [SESSION] Calling joinLiveUseCase for: ${live.id} (${sw.elapsedMilliseconds}ms)');
    final joinSw = Stopwatch()..start();
    final joinResult = await _ref.read(joinLiveUseCaseProvider)(live.id);
    debugPrint('⏱️ [SESSION] joinLiveUseCase took: ${joinSw.elapsedMilliseconds}ms (${sw.elapsedMilliseconds}ms)');
    if (!_isRelevant(session)) {
      debugPrint('⏱️ [SESSION] Session no longer relevant after join: ${live.id} (${sw.elapsedMilliseconds}ms)');
      return;
    }

    await joinResult.fold(
      (failure) async {
        debugPrint('⏱️ [SESSION] Join failed for ${live.id}: ${failure.message} (${sw.elapsedMilliseconds}ms)');
        final banned = failure.message.toLowerCase().contains('banned');
        final ended = failure.message.toLowerCase().contains('ended');
        session.uiState = session.uiState.copyWith(
          session: session.uiState.session!.copyWith(
            connectionState: banned
                ? LiveConnectionState.banned
                : ended
                    ? LiveConnectionState.liveEnded
                    : LiveConnectionState.error,
            errorMessage: failure.message,
          ),
        );
        _emit(session);
      },
      (result) async {
        debugPrint('⏱️ [SESSION] Join succeeded for ${live.id}, connecting LiveKit... (${sw.elapsedMilliseconds}ms)');
        // ============================================================
        // [DEBUG-QOS JWT] Non-cryptographic token claim check.
        // Decodes ONLY the Base64 payload of the viewer JWT to prove
        // the backend isn't embedding a max-quality / max-bitrate
        // restriction that overrides our client-side simulcast
        // settings.  NEVER prints the full token or verifies a
        // signature — only dumps public claims.
        // ============================================================
        try {
          final tok = result.liveKitToken;
          final parts = tok.split('.');
          if (parts.length >= 2) {
            String payload = parts[1];
            while (payload.length % 4 != 0) {
              payload += '=';
            }
            final bytes = base64Url.decode(payload);
            final Map<String, dynamic> claims =
                jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
            final subClaims = Map<String, dynamic>.of(claims);
            subClaims.remove('secret');
            subClaims.remove('apiKey');
            subClaims.remove('apiSecret');
            subClaims.remove('privateKey');
          }
        } catch (e) { /* JWT is optional; failures are not fatal. */ }

        try {
          debugPrint('⏱️ [SESSION] Connecting LiveKit for ${live.id} (${sw.elapsedMilliseconds}ms)');
          final liveKitSw = Stopwatch()..start();
          await session.liveKit.connect(
            url: result.liveKitUrl,
            token: result.liveKitToken,
            roomName: result.liveId,
            mockStreamUrl: result.live.streamUrl,
          );
          debugPrint('⏱️ [SESSION] LiveKit connected for ${live.id} (${liveKitSw.elapsedMilliseconds}ms, total: ${sw.elapsedMilliseconds}ms)');
        } catch (e) {
          debugPrint('⏱️ [SESSION] LiveKit connect failed for ${live.id}: $e (${sw.elapsedMilliseconds}ms)');
          if (!_isRelevant(session)) return;
          session.uiState = session.uiState.copyWith(
            session: session.uiState.session!.copyWith(
              connectionState: LiveConnectionState.error,
              errorMessage: 'Failed to connect to stream',
            ),
          );
          _emit(session);
          return;
        }

        if (!_isRelevant(session)) {
          debugPrint('⏱️ [SESSION] Session no longer relevant after LiveKit connect: ${live.id} (${sw.elapsedMilliseconds}ms)');
          return;
        }

        final joinedAvatars = _avatarsFromLive(result.live);
        session.uiState = session.uiState.copyWith(
          session: session.uiState.session!.copyWith(
            live: result.live.copyWith(
              metadata: live.metadata,
              isFollowing: live.isFollowing,
            ),
            connectionState: LiveConnectionState.connected,
            isLiveKitConnected: true,
            socketToken: result.socketToken,
            liveKitToken: result.liveKitToken,
            coinBalance: 1250,
          ),
          showJoinSuccess: true,
          topViewerAvatars: joinedAvatars.isNotEmpty
              ? joinedAvatars
              : session.uiState.topViewerAvatars,
        );
        _emit(session);

        debugPrint('⏱️ [SESSION] Connecting socket for ${live.id} (${sw.elapsedMilliseconds}ms)');
        final socketSw = Stopwatch()..start();
        final socketFuture = session.socket.connect(
          liveId: result.liveId,
          token: result.socketToken,
        );
        final coinsFuture = _ref.read(giftRepositoryProvider).getCoinBalance();
        final commentsFuture = _ref
            .read(commentRepositoryProvider)
            .getComments(liveId: live.id, limit: 20);
        final meFuture = _loadCurrentUserId();

        try {
          final results = await Future.wait<dynamic>([
            socketFuture,
            coinsFuture,
            commentsFuture,
            meFuture,
          ]);
          if (!_isRelevant(session)) {
            debugPrint('⏱️ [SESSION] Session no longer relevant after socket connect: ${live.id} (${sw.elapsedMilliseconds}ms)');
            return;
          }

          final coins = results[1];
          final commentsResult = results[2];
          _currentUserId = results[3] as String? ?? _currentUserId;
          final comments = commentsResult.fold(
                (_) => <CommentEntity>[],
                (batch) => batch.comments.reversed.toList(),
              )
              as List<CommentEntity>;
          CommentEntity? pinned;
          for (final c in comments) {
            if (c.isPinned) pinned = c;
          }
          pinned ??= _pinnedFromLiveMetadata(result.live);
          _listenSocket(session);
          session.uiState = session.uiState.copyWith(
            session: session.uiState.session!.copyWith(
              isSocketConnected: true,
              coinBalance: coins.getOrElse(() => 1250),
            ),
            comments: comments,
            pinnedComment: pinned,
            currentUserId: _currentUserId,
          );
          _emit(session);
          debugPrint('⏱️ [SESSION] Socket connected for ${live.id} (${socketSw.elapsedMilliseconds}ms, total: ${sw.elapsedMilliseconds}ms)');
          debugPrint('⏱️ [SESSION] _runSession COMPLETE: ${live.id} (${sw.elapsedMilliseconds}ms)');
        } catch (e) {
          debugPrint('⏱️ [SESSION] Socket/services failed for ${live.id}: $e (${sw.elapsedMilliseconds}ms)');
          // A slow/failing overlay service must not take down an already
          // connected LiveKit video. Socket reconnect handling remains active
          // when it becomes available on the next join.
        }

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (_active == session && !_disposed) {
            session.uiState = session.uiState.copyWith(showJoinSuccess: false);
            _emit(session);
          }
        });
      },
    );
  }

  void _listenSocket(_LiveSessionData session) {
    session.socketSub?.cancel();
    session.socketSub = session.socket.events.listen((event) {
      if (event.liveId != session.live.id) return;
      _onSocketEvent(session, event);
    });
  }

  void _onSocketEvent(_LiveSessionData session, SocketEvent event) {
    final current = session.uiState;
    if (current.session == null) return;

    if (event is LiveCommentEvent) {
      final next = [...current.comments, event.comment];
      session.uiState = current.copyWith(
        comments: next.length > 80 ? next.sublist(next.length - 80) : next,
        pinnedComment: event.comment.isPinned
            ? event.comment
            : current.pinnedComment,
      );
    } else if (event is LiveCommentDeletedEvent) {
      session.uiState = current.copyWith(
        comments: current.comments.where((c) => c.id != event.commentId).toList(),
        clearPinnedComment: current.pinnedComment?.id == event.commentId,
      );
    } else if (event is LiveCommentPinnedEvent) {
      final pinned = event.comment.copyWith(isPinned: true);
      session.uiState = current.copyWith(
        comments: [
          for (final c in current.comments)
            c.id == pinned.id ? pinned : c.copyWith(isPinned: false),
        ],
        pinnedComment: pinned,
      );
    } else if (event is LiveCommentUnpinnedEvent) {
      session.uiState = current.copyWith(
        comments: [
          for (final c in current.comments)
            c.id == event.commentId ? c.copyWith(isPinned: false) : c,
        ],
        clearPinnedComment: true,
      );
    } else if (event is LiveModerationEvent) {
      _onModeration(session, event);
      return;
    } else if (event is UserJoinedEvent) {
      if (_isMe(event.userId)) {
        if (event.viewerCount != null) {
          session.uiState = current.copyWith(
            session: current.session!.copyWith(
              live: current.session!.live.copyWith(viewerCount: event.viewerCount!),
            ),
          );
        }
        _emit(session);
        return;
      }
      final joinNotice = CommentEntity(
        id: 'join_${event.timestamp.microsecondsSinceEpoch}',
        liveId: event.liveId,
        userId: event.userId,
        username: event.username,
        userAvatar: event.avatarUrl,
        content: '${event.username} joined the live',
        createdAt: event.timestamp,
        metadata: const {'type': 'join'},
      );
      final next = [...current.comments, joinNotice];
      session.uiState = current.copyWith(
        comments: next.length > 80 ? next.sublist(next.length - 80) : next,
        topViewerAvatars: _pushAvatar(current.topViewerAvatars, event.avatarUrl),
        session: event.viewerCount != null
            ? current.session!.copyWith(
                live: current.session!.live.copyWith(viewerCount: event.viewerCount!),
              )
            : current.session,
      );
    } else if (event is LiveLikeEvent) {
      final isSelf = _isMe(event.userId);
      session.uiState = current.copyWith(
        session: current.session!.copyWith(
          live: current.session!.live.copyWith(likeCount: event.likeCount),
        ),
        floatingHeartBurst: isSelf
            ? current.floatingHeartBurst
            : current.floatingHeartBurst + event.delta.clamp(1, 3),
      );
    } else if (event is LiveViewersEvent) {
      session.uiState = current.copyWith(
        session: current.session!.copyWith(
          live: current.session!.live.copyWith(viewerCount: event.viewerCount),
        ),
        topViewerAvatars: event.topViewerAvatars.isNotEmpty
            ? event.topViewerAvatars
            : current.topViewerAvatars,
      );
    } else if (event is LiveGiftEvent) {
      var left = current.pkScoreLeft;
      var right = current.pkScoreRight;
      if (current.isPk) {
        if (Random().nextBool()) {
          left += event.gift.totalCost;
        } else {
          right += event.gift.totalCost;
        }
      }
      final giftNotice = CommentEntity(
        id: 'gift_c_${event.gift.id}',
        liveId: event.liveId,
        userId: event.gift.senderId,
        username: event.gift.senderName,
        userAvatar: event.gift.senderAvatar,
        content: event.gift.giftDetails?.name ?? 'a gift',
        createdAt: event.gift.sentAt,
        gifterLevel: event.gift.senderGifterLevel,
        metadata: const {'type': 'gift'},
      );
      final nextComments = [...current.comments, giftNotice];
      session.uiState = current.copyWith(
        recentGifts: [event.gift, ...current.recentGifts].take(8).toList(),
        activeGiftAnimation: event.gift,
        pkScoreLeft: left,
        pkScoreRight: right,
        comments: nextComments.length > 80
            ? nextComments.sublist(nextComments.length - 80)
            : nextComments,
      );
    } else if (event is LiveEndedEvent) {
      session.uiState = current.copyWith(
        session: current.session!.copyWith(
          connectionState: LiveConnectionState.liveEnded,
          errorMessage: event.reason,
        ),
      );
      _ref.read(liveFeedProvider.notifier).removeLive(event.liveId);
      if (session == _preloaded) {
        unawaited(_teardown(_preloaded));
        _preloaded = null;
      } else if (session == _previous) {
        unawaited(_teardown(_previous));
        _previous = null;
      }
    } else if (event is NetworkLostEvent) {
      // Only update state if this session is the active one. Background
      // sessions (previous/preloaded) may have their sockets disconnect
      // temporarily, but we don't want to show "Network lost" when the
      // user swipes back to them — we'll reconnect if needed.
      debugPrint('⏱️ [SESSION] NetworkLostEvent: liveId=${session.live.id}, isActive=${session == _active}, liveKitState=${session.liveKit.state}');
      if (session != _active) return;
      // If LiveKit is still connected, the video is still playing —
      // don't show "Network lost" to the user. Only mark the socket
      // as disconnected silently; the socket will auto-reconnect.
      if (session.liveKit.state == LiveKitConnectionState.connected) {
        debugPrint('⏱️ [SESSION] NetworkLostEvent ignored — LiveKit still connected, video still playing');
        session.uiState = current.copyWith(
          session: current.session!.copyWith(
            isSocketConnected: false,
          ),
        );
        _emit(session);
        return;
      }
      session.uiState = current.copyWith(
        session: current.session!.copyWith(
          connectionState: LiveConnectionState.networkLost,
          isSocketConnected: false,
        ),
      );
    } else if (event is ReconnectingEvent) {
      debugPrint('⏱️ [SESSION] ReconnectingEvent: liveId=${session.live.id}, isActive=${session == _active}, attempt=${event.attempt}');
      if (session != _active) return;
      // If LiveKit is still connected, don't show "reconnecting" —
      // only the socket is reconnecting, the video is still playing.
      if (session.liveKit.state == LiveKitConnectionState.connected) {
        session.uiState = current.copyWith(
          session: current.session!.copyWith(
            isSocketConnected: false,
          ),
        );
        _emit(session);
        return;
      }
      session.uiState = current.copyWith(
        session: current.session!.copyWith(
          connectionState: LiveConnectionState.reconnecting,
          reconnectAttempt: event.attempt,
        ),
      );
      session.liveKit.reconnect();
    } else if (event is ReconnectedEvent) {
      debugPrint('⏱️ [SESSION] ReconnectedEvent: liveId=${session.live.id}, isActive=${session == _active}');
      if (session != _active) return;
      session.uiState = current.copyWith(
        session: current.session!.copyWith(
          connectionState: LiveConnectionState.connected,
          isSocketConnected: true,
          isLiveKitConnected: true,
        ),
      );
    }

    _emit(session);
  }

  Future<void> sendComment(String content) async {
    final id = _active?.live.id;
    if (id == null || content.trim().isEmpty) return;
    if (state.chatMuted) {
      state = state.copyWith(
        moderationBanner: 'Your chat is muted on this live',
      );
      _scheduleBannerClear();
      return;
    }
    final result = await _ref
        .read(commentRepositoryProvider)
        .sendComment(liveId: id, content: content.trim());
    result.fold(
      (failure) {
        final muted = failure.message.toLowerCase().contains('mute');
        state = state.copyWith(
          chatMuted: muted || state.chatMuted,
          moderationBanner: muted
              ? 'Your chat is muted on this live'
              : failure.message,
        );
        _scheduleBannerClear();
      },
      (comment) {
        if (comment.userId.isNotEmpty) {
          _currentUserId ??= comment.userId;
        }
        if (!state.comments.any((c) => c.id == comment.id)) {
          state = state.copyWith(
            comments: [...state.comments, comment],
            currentUserId: _currentUserId,
          );
        }
      },
    );
  }

  Future<void> like({int burst = 1}) async {
    final session = state.session;
    final id = _active?.live.id;
    if (session == null || id == null) return;

    state = state.copyWith(
      session: session.copyWith(
        live: session.live.copyWith(likeCount: session.live.likeCount + burst),
        hasLiked: true,
      ),
      floatingHeartBurst: state.floatingHeartBurst + burst.clamp(1, 5),
    );
    await _ref.read(likeLiveUseCaseProvider)(id, burst: burst);
  }

  void consumeHeartBurst() {
    if (state.floatingHeartBurst > 0) {
      state = state.copyWith(floatingHeartBurst: 0);
    }
  }

  void consumeModerationBanner() {
    if (state.moderationBanner != null) {
      state = state.copyWith(clearModerationBanner: true);
    }
  }

  void _scheduleBannerClear() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!_disposed) consumeModerationBanner();
    });
  }

  bool _isMe(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    if (_currentUserId != null && userId == _currentUserId) return true;
    final firebaseUid = fb.FirebaseAuth.instance.currentUser?.uid;
    return firebaseUid != null && userId == firebaseUid;
  }

  List<String> _avatarsFromLive(LiveEntity live) {
    final raw = live.metadata?['topViewerAvatars'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString())
        .where((url) => url.isNotEmpty)
        .take(3)
        .toList();
  }

  List<String> _pushAvatar(List<String> current, String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return current;
    return [avatarUrl, ...current.where((url) => url != avatarUrl)].take(3).toList();
  }

  void _onModeration(_LiveSessionData session, LiveModerationEvent event) {
    final isMe = _isMe(event.userId);
    switch (event.moderationType) {
      case 'chat_muted':
        if (!isMe) return;
        session.uiState = session.uiState.copyWith(
          chatMuted: true,
          moderationBanner: event.reason?.isNotEmpty == true
              ? 'Chat muted: ${event.reason}'
              : 'Your chat was muted',
        );
        _scheduleBannerClear();
        break;
      case 'chat_unmuted':
        if (!isMe) return;
        session.uiState = session.uiState.copyWith(
          chatMuted: false,
          moderationBanner: 'Your chat was unmuted',
        );
        _scheduleBannerClear();
        break;
      case 'viewer_banned':
        if (!isMe) return;
        unawaited(_kickSessionBanned(session, event.reason));
        break;
      case 'viewer_unbanned':
        if (!isMe) return;
        session.uiState = session.uiState.copyWith(
          chatMuted: false,
          moderationBanner: 'You were unbanned from this live',
        );
        _scheduleBannerClear();
        break;
      default:
        if (isMe) {
          session.uiState = session.uiState.copyWith(
            moderationBanner: 'Moderation update: ${event.moderationType}',
          );
          _scheduleBannerClear();
        }
        break;
    }
    _emit(session);
  }

  Future<void> _kickSessionBanned(
    _LiveSessionData session,
    String? reason,
  ) async {
    try {
      await session.socket.disconnect();
    } catch (_) {}
    try {
      await session.liveKit.disconnect();
    } catch (_) {}
    try {
      await _ref.read(leaveLiveUseCaseProvider)(session.live.id);
    } catch (_) {}
    if (_disposed) return;
    session.uiState = session.uiState.copyWith(
      session: session.uiState.session!.copyWith(
        connectionState: LiveConnectionState.banned,
        isSocketConnected: false,
        isLiveKitConnected: false,
        errorMessage: reason?.isNotEmpty == true
            ? reason
            : 'You are banned from this live',
      ),
      chatMuted: true,
    );
    _emit(session);
  }

  Future<String?> _loadCurrentUserId() async {
    try {
      final payload = await _ref.read(apiClientProvider).get(ApiEndpoints.authMe);
      final id = payload['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
      final user = payload['user'];
      if (user is Map) {
        final nested = user['id']?.toString();
        if (nested != null && nested.isNotEmpty) return nested;
      }
    } catch (_) {}
    return fb.FirebaseAuth.instance.currentUser?.uid;
  }

  CommentEntity? _pinnedFromLiveMetadata(LiveEntity live) {
    final raw = live.metadata?['pinnedComment'];
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final user = map['user'];
    final userMap = user is Map ? Map<String, dynamic>.from(user) : null;
    final content = map['content']?.toString() ?? map['text']?.toString() ?? '';
    if (content.isEmpty && map['id'] == null) return null;
    return CommentEntity(
      id: map['id']?.toString() ?? 'pinned',
      liveId: live.id,
      userId: userMap?['id']?.toString() ?? map['userId']?.toString() ?? '',
      username:
          userMap?['username']?.toString() ??
          userMap?['fullName']?.toString() ??
          'User',
      userAvatar: userMap?['avatarUrl']?.toString(),
      content: content,
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      gifterLevel: userMap?['gifterLevel'] is num
          ? (userMap!['gifterLevel'] as num).toInt()
          : int.tryParse(userMap?['gifterLevel']?.toString() ?? ''),
      isVerified: userMap?['isVerified'] == true,
      isPinned: true,
    );
  }

  Future<void> sendGift(GiftEntity gift, {int quantity = 1}) async {
    final session = state.session;
    final id = _active?.live.id;
    if (session == null || id == null) return;

    final result = await _ref.read(sendGiftUseCaseProvider)(
      liveId: id,
      giftId: gift.id,
      quantity: quantity,
      receiverId: session.live.hostId,
    );

    result.fold((_) {}, (sent) {
      final balance = session.coinBalance - sent.totalCost;
      var left = state.pkScoreLeft;
      var right = state.pkScoreRight;
      if (state.isPk) left += sent.totalCost;

      state = state.copyWith(
        session: session.copyWith(coinBalance: balance < 0 ? 0 : balance),
        recentGifts: [sent, ...state.recentGifts].take(8).toList(),
        activeGiftAnimation: sent,
        coinDelta: -sent.totalCost,
        pkScoreLeft: left,
        pkScoreRight: right,
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_active?.live.id == id) state = state.copyWith(coinDelta: 0);
      });
    });
  }

  void clearGiftAnimation() {
    state = state.copyWith(clearGiftAnimation: true);
  }

  Future<void> toggleFollow() async {
    final session = state.session;
    if (session == null) return;
    final next = !session.live.isFollowing;
    state = state.copyWith(
      session: session.copyWith(live: session.live.copyWith(isFollowing: next)),
    );
    if (next) {
      await _ref.read(liveRepositoryProvider).followHost(session.live.hostId);
    } else {
      await _ref.read(liveRepositoryProvider).unfollowHost(session.live.hostId);
    }
  }

  Future<void> retry() async {
    final live = state.live;
    if (live == null) return;
    await activate(live);
  }

  Future<void> _teardownAndClear({
    bool includePreloaded = false,
    bool includePrevious = false,
  }) async {
    debugPrint('⏱️ [SESSION] _teardownAndClear START: activeId=${_active?.live.id}, preloadedId=${_preloaded?.live.id}, previousId=${_previous?.live.id}, includePreloaded=$includePreloaded, includePrevious=$includePrevious');
    await _teardown(_active);
    _active = null;
    if (includePreloaded) {
      await _teardown(_preloaded);
      _preloaded = null;
    }
    if (includePrevious) {
      await _teardown(_previous);
      _previous = null;
    }
    if (!_disposed) state = const LiveSessionUiState();
    debugPrint('⏱️ [SESSION] _teardownAndClear COMPLETE: preloadedId=${_preloaded?.live.id}, previousId=${_previous?.live.id}');
  }

  /// Deactivates only the active session, keeping any preloaded/previous
  /// sessions alive so they can be adopted on the next activate() call.
  Future<void> deactivate() {
    debugPrint('⏱️ [SESSION] deactivate() called: activeId=${_active?.live.id}, preloadedId=${_preloaded?.live.id}, previousId=${_previous?.live.id}');
    return _teardownAndClear(includePreloaded: false, includePrevious: false);
  }

  /// Deactivates all sessions (active + preloaded + previous) — use when
  /// leaving the feed entirely or when the app goes to background.
  Future<void> deactivateAll() {
    debugPrint('⏱️ [SESSION] deactivateAll() called: activeId=${_active?.live.id}, preloadedId=${_preloaded?.live.id}, previousId=${_previous?.live.id}');
    return _teardownAndClear(includePreloaded: true, includePrevious: true);
  }

  void simulateNetworkLoss() {
    // Real socket does not support simulated drops — UI retry re-joins.
  }

  @override
  void dispose() {
    _disposed = true;
    _socketSub?.cancel();
    _socketSub = null;
    unawaited(_teardown(_active));
    unawaited(_teardown(_preloaded));
    unawaited(_teardown(_previous));
    _liveKitProxy?.setDelegate(null);
    _socketProxy?.setDelegate(null);
    super.dispose();
  }
}

final activeLiveProvider =
    StateNotifierProvider<ActiveLiveNotifier, LiveSessionUiState>((ref) {
      return ActiveLiveNotifier(ref);
    });
