import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/gift_entity.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../domain/entities/socket_event.dart';
import 'live_dependencies.dart';

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
    );
  }
}

/// Manages exactly one active live at a time (TikTok vertical swipe).
class ActiveLiveNotifier extends StateNotifier<LiveSessionUiState> {
  final Ref _ref;
  StreamSubscription<SocketEvent>? _socketSub;
  String? _activeLiveId;
  bool _busy = false;
  bool _disposed = false;
  LiveEntity? _pendingActivate;

  ActiveLiveNotifier(this._ref) : super(const LiveSessionUiState());

  String? get activeLiveId => _activeLiveId;

  Future<void> activate(LiveEntity live) async {
    if (_disposed) return;
    if (_busy) {
      _pendingActivate = live;
      return;
    }
    if (_activeLiveId == live.id &&
        state.connectionState == LiveConnectionState.connected) {
      return;
    }

    _busy = true;
    _pendingActivate = null;
    try {
      await _teardown(silent: true);
      if (_disposed) return;
      _activeLiveId = live.id;

      final random = Random(live.id.hashCode);
      final avatars = List.generate(
        3,
        (i) => 'https://i.pravatar.cc/150?u=${live.id}_v$i',
      );
      final isPk = live.metadata?['isPk'] == true;

      state = LiveSessionUiState(
        session: LiveSessionEntity(
          live: live,
          connectionState: LiveConnectionState.connecting,
        ),
        topViewerAvatars: avatars,
        pkScoreLeft: isPk
            ? (live.metadata?['scoreLeft'] as int? ??
                8000 + random.nextInt(8000))
            : 0,
        pkScoreRight: isPk
            ? (live.metadata?['scoreRight'] as int? ??
                1000 + random.nextInt(3000))
            : 0,
      );

      if (live.status == LiveStatus.ended) {
        state = state.copyWith(
          session: state.session!.copyWith(
            connectionState: LiveConnectionState.liveEnded,
          ),
        );
        return;
      }
      if (live.status == LiveStatus.banned) {
        state = state.copyWith(
          session: state.session!.copyWith(
            connectionState: LiveConnectionState.banned,
          ),
        );
        return;
      }

      final joinResult = await _ref.read(joinLiveUseCaseProvider)(live.id);
      if (_activeLiveId != live.id) return;

      await joinResult.fold((failure) async {
        final banned = failure.message.toLowerCase().contains('banned');
        final ended = failure.message.toLowerCase().contains('ended');
        state = state.copyWith(
          session: state.session!.copyWith(
            connectionState: banned
                ? LiveConnectionState.banned
                : ended
                    ? LiveConnectionState.liveEnded
                    : LiveConnectionState.error,
            errorMessage: failure.message,
          ),
        );
      }, (result) async {
        final socket = _ref.read(socketServiceProvider);

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
            // JWT payload is parts[1], URL-safe base64.
            String payload = parts[1];
            // Add padding if missing.
            while (payload.length % 4 != 0) {
              payload += '=';
            }
            final bytes = base64Url.decode(payload);
            final Map<String, dynamic> claims =
                jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
            final subClaims = Map<String, dynamic>.of(claims);
            // Remove sensitive fields if present (never in viewer LiveKit JWT,
            // but be defensive).
            subClaims.remove('secret');
            subClaims.remove('apiKey');
            subClaims.remove('apiSecret');
            subClaims.remove('privateKey');
            debugPrint(
              '[DEBUG-QOS] JWT-CLAIMS (viewer token, public only):'
              '  exp=${subClaims['exp']}'
              '  room=${subClaims['room'] ?? subClaims['roomName']}'
              '  identity=${subClaims['identity']}'
              '  canPublish=${subClaims['canPublish']}'
              '  canSubscribe=${subClaims['canSubscribe']}'
              '  canPublishData=${subClaims['canPublishData']}'
              '  hiddenClaims=${subClaims['hidden']}'
              '  maxVideoBitrate=${subClaims['maxVideoBitrate']}'
              '  maxQuality=${subClaims['maxQuality'] ?? subClaims['video_max_quality']}'
              '  otherKeys=${subClaims.keys.where((k) => !const <String>{'exp','room','roomName','identity','canPublish','canSubscribe','canPublishData','hidden','maxVideoBitrate','maxQuality','video_max_quality','nbf','iat','iss','jti','sub'}.contains(k)).join(',')}'
              '  allClaimKeysSorted=${(subClaims.keys.toList()..sort()).join(',')}',
            );
          }
        } catch (e) {
          debugPrint('[DEBUG-QOS] JWT-CLAIMS (decode failed): $e');
        }

        final liveKit = _ref.read(liveKitServiceProvider);
        try {
          await liveKit.connect(
            url: result.liveKitUrl,
            token: result.liveKitToken,
            roomName: result.liveId,
            mockStreamUrl: result.live.streamUrl,
          );
        } catch (_) {
          if (_activeLiveId != live.id) return;
          state = state.copyWith(
            session: state.session!.copyWith(
              connectionState: LiveConnectionState.error,
              errorMessage: 'Failed to connect to stream',
            ),
          );
          return;
        }

        if (_activeLiveId != live.id) return;

        // LiveKit is the critical path. Publish the connected state now so the
        // renderer can attach on the first subscribed track; overlays load in
        // parallel and must not delay the first video frame.
        state = state.copyWith(
          session: state.session!.copyWith(
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
        );

        final socketFuture = socket.connect(
          liveId: result.liveId,
          token: result.socketToken,
        );
        final coinsFuture =
            _ref.read(giftRepositoryProvider).getCoinBalance();
        final commentsFuture = _ref
            .read(commentRepositoryProvider)
            .getComments(liveId: live.id, limit: 20);

        try {
          final results = await Future.wait<dynamic>([
            socketFuture,
            coinsFuture,
            commentsFuture,
          ]);
          if (_activeLiveId != live.id) return;

          final coins = results[1];
          final commentsResult = results[2];
          final comments = commentsResult.fold(
            (_) => <CommentEntity>[],
            (batch) => batch.comments.reversed.toList(),
          );
          _listenSocket(live.id);
          state = state.copyWith(
            session: state.session!.copyWith(
              isSocketConnected: true,
              coinBalance: coins.getOrElse(() => 1250),
            ),
            comments: comments,
          );
        } catch (_) {
          // A slow/failing overlay service must not take down an already
          // connected LiveKit video. Socket reconnect handling remains active
          // when it becomes available on the next join.
        }

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (_activeLiveId == live.id) {
            state = state.copyWith(showJoinSuccess: false);
          }
        });
      });
    } finally {
      _busy = false;
      final pending = _pendingActivate;
      _pendingActivate = null;
      if (!_disposed && pending != null && pending.id != _activeLiveId) {
        await activate(pending);
      }
    }
  }

  void _listenSocket(String liveId) {
    _socketSub?.cancel();
    _socketSub = _ref.read(socketServiceProvider).events.listen((event) {
      if (_activeLiveId != liveId || event.liveId != liveId) return;
      _onSocketEvent(event);
    });
  }

  void _onSocketEvent(SocketEvent event) {
    final session = state.session;
    if (session == null) return;

    if (event is LiveCommentEvent) {
      final next = [...state.comments, event.comment];
      state = state.copyWith(
        comments: next.length > 80 ? next.sublist(next.length - 80) : next,
      );
    } else if (event is UserJoinedEvent) {
      final joinNotice = CommentEntity(
        id: 'join_${event.timestamp.microsecondsSinceEpoch}',
        liveId: event.liveId,
        userId: event.userId,
        username: event.username,
        userAvatar: event.avatarUrl,
        content: 'joined',
        createdAt: event.timestamp,
        metadata: const {'type': 'join'},
      );
      state = state.copyWith(comments: [...state.comments, joinNotice]);
    } else if (event is LiveLikeEvent) {
      final isSelf = event.userId == 'current_user';
      state = state.copyWith(
        session: session.copyWith(
          live: session.live.copyWith(likeCount: event.likeCount),
        ),
        floatingHeartBurst: isSelf
            ? state.floatingHeartBurst
            : state.floatingHeartBurst + event.delta.clamp(1, 3),
      );
    } else if (event is LiveViewersEvent) {
      state = state.copyWith(
        session: session.copyWith(
          live: session.live.copyWith(viewerCount: event.viewerCount),
        ),
      );
    } else if (event is LiveGiftEvent) {
      var left = state.pkScoreLeft;
      var right = state.pkScoreRight;
      if (state.isPk) {
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
        metadata: const {'type': 'gift'},
      );
      final nextComments = [...state.comments, giftNotice];
      state = state.copyWith(
        recentGifts: [event.gift, ...state.recentGifts].take(8).toList(),
        activeGiftAnimation: event.gift,
        pkScoreLeft: left,
        pkScoreRight: right,
        comments: nextComments.length > 80
            ? nextComments.sublist(nextComments.length - 80)
            : nextComments,
      );
    } else if (event is LiveEndedEvent) {
      state = state.copyWith(
        session: session.copyWith(
          connectionState: LiveConnectionState.liveEnded,
          errorMessage: event.reason,
        ),
      );
    } else if (event is NetworkLostEvent) {
      state = state.copyWith(
        session: session.copyWith(
          connectionState: LiveConnectionState.networkLost,
          isSocketConnected: false,
        ),
      );
    } else if (event is ReconnectingEvent) {
      state = state.copyWith(
        session: session.copyWith(
          connectionState: LiveConnectionState.reconnecting,
          reconnectAttempt: event.attempt,
        ),
      );
      _ref.read(liveKitServiceProvider).reconnect();
    } else if (event is ReconnectedEvent) {
      state = state.copyWith(
        session: session.copyWith(
          connectionState: LiveConnectionState.connected,
          isSocketConnected: true,
          isLiveKitConnected: true,
        ),
      );
    }
  }

  Future<void> sendComment(String content) async {
    final id = _activeLiveId;
    if (id == null || content.trim().isEmpty) return;
    final result = await _ref.read(commentRepositoryProvider).sendComment(
          liveId: id,
          content: content.trim(),
        );
    result.fold((_) {}, (comment) {
      if (!state.comments.any((c) => c.id == comment.id)) {
        state = state.copyWith(comments: [...state.comments, comment]);
      }
    });
  }

  Future<void> like({int burst = 1}) async {
    final session = state.session;
    final id = _activeLiveId;
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

  Future<void> sendGift(GiftEntity gift, {int quantity = 1}) async {
    final session = state.session;
    final id = _activeLiveId;
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
        if (_activeLiveId == id) state = state.copyWith(coinDelta: 0);
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
      session: session.copyWith(
        live: session.live.copyWith(isFollowing: next),
      ),
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
    _activeLiveId = null;
    await activate(live);
  }

  Future<void> _teardown({bool silent = false}) async {
    _socketSub?.cancel();
    _socketSub = null;
    final id = _activeLiveId;
    _activeLiveId = null;

    if (id != null) {
      try {
        await _ref.read(leaveLiveUseCaseProvider)(id);
      } catch (_) {}
    }
    try {
      await _ref.read(socketServiceProvider).disconnect();
    } catch (_) {}
    try {
      await _ref.read(liveKitServiceProvider).disconnect();
    } catch (_) {}

    if (!silent && !_disposed) {
      state = const LiveSessionUiState();
    }
  }

  Future<void> deactivate() => _teardown(silent: false);

  void simulateNetworkLoss() {
    // Real socket does not support simulated drops — UI retry re-joins.
  }

  @override
  void dispose() {
    _disposed = true;
    _socketSub?.cancel();
    _socketSub = null;
    // Sync tearDown: MUST happen inside dispose() so the Notifier lifecycle
    // (auto-dispose / ProviderScope) cleanly releases ALL resources —
    // LiveKit room, remote tracks, socket — no matter which exit path the
    // user takes (nav pop, back button, swipe out).
    //
    // We do NOT await the Future from _teardown because dispose() must be
    // synchronous; the operation is fire-and-forget to its own event loop
    // turn and will never touch `state` after dispose (silent=true).
    unawaited(_teardown(silent: true));
    super.dispose();
  }
}

final activeLiveProvider =
    StateNotifierProvider<ActiveLiveNotifier, LiveSessionUiState>((ref) {
  return ActiveLiveNotifier(ref);
});
