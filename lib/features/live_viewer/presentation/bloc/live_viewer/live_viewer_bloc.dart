import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../../../core/network/live_api_client.dart';
import '../../../data/services/fake_livekit_service.dart';
import '../../../data/services/fake_socket_service.dart';
import '../../../domain/entities/comment_entity.dart';
import '../../../domain/entities/gift_entity.dart';
import '../../../domain/entities/live_entity.dart';
import '../../../domain/entities/live_session_entity.dart';
import '../../../domain/entities/socket_event.dart';
import '../../../domain/repositories/comment_repository.dart';
import '../../../domain/repositories/gift_repository.dart';
import '../../../domain/repositories/live_repository.dart';
import '../../../domain/repositories/like_repository.dart';
import '../../../domain/usecases/ban_viewer_usecase.dart';
import '../../../domain/usecases/delete_comment_usecase.dart';
import '../../../domain/usecases/join_live_usecase.dart';
import '../../../domain/usecases/leave_live_usecase.dart';
import '../../../domain/usecases/like_live_usecase.dart';
import '../../../domain/usecases/mute_viewer_chat_usecase.dart';
import '../../../domain/usecases/send_gift_usecase.dart';
import '../../../domain/usecases/unban_viewer_usecase.dart';
import '../../../domain/usecases/unmute_viewer_chat_usecase.dart';
import 'live_viewer_event.dart';
import 'live_viewer_state.dart';

class LiveViewerBloc extends Bloc<LiveViewerEvent, LiveViewerState> {
  LiveViewerBloc({
    required this.joinLiveUseCase,
    required this.leaveLiveUseCase,
    required this.likeLiveUseCase,
    required this.sendGiftUseCase,
    required this.banViewerUseCase,
    required this.unbanViewerUseCase,
    required this.muteViewerChatUseCase,
    required this.unmuteViewerChatUseCase,
    required this.deleteCommentUseCase,
    required this.liveRepository,
    required this.commentRepository,
    required this.giftRepository,
    required this.likeRepository,
    required this.socketService,
    required this.liveKitService,
    required this.apiClient,
  }) : super(const LiveViewerState()) {
    on<LiveViewerActivated>(_onActivated);
    on<LiveViewerDeactivated>(_onDeactivated);
    on<LiveViewerRetryRequested>(_onRetryRequested);
    on<LiveViewerCommentSent>(_onCommentSent);
    on<LiveViewerLiked>(_onLiked);
    on<LiveViewerGiftSent>(_onGiftSent);
    on<LiveViewerFollowToggled>(_onFollowToggled);
    on<LiveViewerHeartBurstConsumed>(_onHeartBurstConsumed);
    on<LiveViewerGiftAnimationCleared>(_onGiftAnimationCleared);
    on<LiveViewerModerationBannerConsumed>(_onModerationBannerConsumed);
    on<LiveViewerSocketEventReceived>(_onSocketEventReceived);
    on<LiveViewerCommentDeletedRequested>(_onCommentDeletedRequested);
    on<LiveViewerViewerChatMuteRequested>(_onViewerChatMuteRequested);
    on<LiveViewerViewerChatUnmuteRequested>(_onViewerChatUnmuteRequested);
    on<LiveViewerViewerBannedRequested>(_onViewerBannedRequested);
    on<LiveViewerViewerUnbannedRequested>(_onViewerUnbannedRequested);
    on<LiveViewerSendStateChanged>(_onSendStateChanged);
  }
  final JoinLiveUseCase joinLiveUseCase;
  final LeaveLiveUseCase leaveLiveUseCase;
  final LikeLiveUseCase likeLiveUseCase;
  final SendGiftUseCase sendGiftUseCase;
  final BanViewerUseCase banViewerUseCase;
  final UnbanViewerUseCase unbanViewerUseCase;
  final MuteViewerChatUseCase muteViewerChatUseCase;
  final UnmuteViewerChatUseCase unmuteViewerChatUseCase;
  final DeleteCommentUseCase deleteCommentUseCase;
  final LiveRepository liveRepository;
  final CommentRepository commentRepository;
  final GiftRepository giftRepository;
  final LikeRepository likeRepository;
  final SocketService socketService;
  final LiveKitService liveKitService;
  final LiveApiClient apiClient;

  StreamSubscription<SocketEvent>? _socketSub;
  String? _activeLiveId;
  bool _busy = false;
  LiveEntity? _pendingActivate;
  String? _currentUserId;
  Timer? _bannerClearTimer;
  Timer? _joinSuccessClearTimer;
  Timer? _coinDeltaClearTimer;

  String? get activeLiveId => _activeLiveId;

  // ---------- Event handlers ----------

  Future<void> _onActivated(
    LiveViewerActivated event,
    Emitter<LiveViewerState> emit,
  ) async {
    if (_busy) {
      _pendingActivate = event.live;
      return;
    }
    if (_activeLiveId == event.live.id &&
        state.connectionState == LiveConnectionState.connected) {
      return;
    }

    _busy = true;
    _pendingActivate = null;
    try {
      await _teardown(silent: true, emit: emit);
      _activeLiveId = event.live.id;
      final live = event.live;

      final isPk = live.metadata?['isPk'] == true;
      final initialAvatars = _avatarsFromLive(live);
      final random = Random();

      emit(
        LiveViewerState(
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
                    (8000 + random.nextInt(8000)))
              : 0,
          pkScoreRight: isPk
              ? ((live.metadata?['scoreRight'] as num?)?.toInt() ??
                    (1000 + random.nextInt(3000)))
              : 0,
          currentUserId: _currentUserId,
        ),
      );

      if (live.status == LiveStatus.ended) {
        emit(
          state.copyWith(
            session: state.session!.copyWith(
              connectionState: LiveConnectionState.liveEnded,
            ),
          ),
        );
        return;
      }
      if (live.status == LiveStatus.banned) {
        emit(
          state.copyWith(
            session: state.session!.copyWith(
              connectionState: LiveConnectionState.banned,
            ),
          ),
        );
        return;
      }

      final joinResult = await joinLiveUseCase(live.id);
      if (_activeLiveId != live.id) return;

      await joinResult.fold(
        (failure) async {
          final msg = failure.message;
          final banned = msg.toLowerCase().contains('banned');
          final ended = msg.toLowerCase().contains('ended');
          emit(
            state.copyWith(
              session: state.session!.copyWith(
                connectionState: banned
                    ? LiveConnectionState.banned
                    : ended
                    ? LiveConnectionState.liveEnded
                    : LiveConnectionState.error,
                errorMessage: msg,
              ),
            ),
          );
        },
        (result) async {
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
          } catch (e) {}

          try {
            await liveKitService.connect(
              url: result.liveKitUrl,
              token: result.liveKitToken,
              roomName: result.liveId,
              mockStreamUrl: result.live.streamUrl,
            );
          } catch (_) {
            if (_activeLiveId != live.id) return;
            emit(
              state.copyWith(
                session: state.session!.copyWith(
                  connectionState: LiveConnectionState.error,
                  errorMessage: 'Failed to connect to stream',
                ),
              ),
            );
            return;
          }
          if (_activeLiveId != live.id) return;

          final joinedAvatars = _avatarsFromLive(result.live);
          emit(
            state.copyWith(
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
              topViewerAvatars: joinedAvatars.isNotEmpty
                  ? joinedAvatars
                  : state.topViewerAvatars,
            ),
          );
          _joinSuccessClearTimer?.cancel();
          _joinSuccessClearTimer = Timer(
            const Duration(milliseconds: 1200),
            () {
              if (_activeLiveId == live.id && !isClosed) {
                emit(state.copyWith(showJoinSuccess: false));
              }
            },
          );

          final socketFuture = socketService.connect(
            liveId: result.liveId,
            token: result.socketToken,
          );
          final coinsFuture = giftRepository.getCoinBalance();
          final commentsFuture = commentRepository.getComments(
            liveId: live.id,
            limit: 20,
          );
          final meFuture = _loadCurrentUserId();

          try {
            final results = await Future.wait<dynamic>([
              socketFuture,
              coinsFuture,
              commentsFuture,
              meFuture,
            ]);
            if (_activeLiveId != live.id) return;

            final coins = results[1];
            final commentsResult = results[2];
            _currentUserId = results[3] as String? ?? _currentUserId;
            final comments = commentsResult
                .fold(
                  (_) => <CommentEntity>[],
                  (batch) => batch.comments.reversed.toList(),
                )
                .cast<CommentEntity>();
            CommentEntity? pinned;
            for (final c in comments) {
              if (c.isPinned) pinned = c;
            }
            pinned ??= _pinnedFromLiveMetadata(result.live);

            _listenSocket(live.id);
            emit(
              state.copyWith(
                session: state.session!.copyWith(
                  isSocketConnected: true,
                  coinBalance: coins.getOrElse(() => 1250),
                ),
                comments: comments,
                pinnedComment: pinned,
                currentUserId: _currentUserId,
              ),
            );
          } catch (_) {}
        },
      );
    } finally {
      _busy = false;
      final pending = _pendingActivate;
      _pendingActivate = null;
      if (pending != null && pending.id != _activeLiveId) {
        add(LiveViewerActivated(pending));
      }
    }
  }

  Future<void> _onDeactivated(
    LiveViewerDeactivated event,
    Emitter<LiveViewerState> emit,
  ) async {
    await _teardown(silent: false, emit: emit);
  }

  Future<void> _onRetryRequested(
    LiveViewerRetryRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final live = state.live;
    if (live == null) return;
    _activeLiveId = null;
    add(LiveViewerActivated(live));
  }

  Future<void> _onCommentSent(
    LiveViewerCommentSent event,
    Emitter<LiveViewerState> emit,
  ) async {
    final id = _activeLiveId;
    final content = event.content.trim();
    if (id == null || content.isEmpty) return;

    final currentUserUid = state.currentUserId ?? _currentUserId;
    final chatMutedFlag = state.chatMuted;
    final inMutedUserIds = currentUserUid != null && state.mutedUserIds.contains(currentUserUid);
    final muted = chatMutedFlag || inMutedUserIds;
    if (muted) {
      emit(state.copyWith(moderationBanner: 'Your chat is muted on this live'));
      _scheduleBannerClear();
      return;
    }

    emit(state.copyWith(isCommentSending: true));
    final result = await commentRepository.sendComment(
      liveId: id,
      content: content,
    );
    await result.fold(
      (failure) async {
        final msg = failure.message ?? 'Unknown error';
        final muted = msg.toLowerCase().contains('mute');
        emit(
          state.copyWith(
            isCommentSending: false,
            chatMuted: muted || state.chatMuted,
            moderationBanner: muted ? 'Your chat is muted on this live' : msg,
          ),
        );
        _scheduleBannerClear();
      },
      (comment) async {
        if (comment.userId.isNotEmpty) {
          _currentUserId ??= comment.userId;
        }
        final emitState = state.copyWith(isCommentSending: false);
        if (!state.comments.any((c) => c.id == comment.id)) {
          emit(
            emitState.copyWith(
              comments: [...emitState.comments, comment],
              currentUserId: _currentUserId,
            ),
          );
        } else {
          emit(emitState);
        }
      },
    );
  }

  Future<void> _onLiked(
    LiveViewerLiked event,
    Emitter<LiveViewerState> emit,
  ) async {
    final session = state.session;
    final id = _activeLiveId;
    if (session == null || id == null) return;
    emit(
      state.copyWith(
        session: session.copyWith(
          live: session.live.copyWith(
            likeCount: session.live.likeCount + event.burst,
          ),
          hasLiked: true,
        ),
        floatingHeartBurst: state.floatingHeartBurst + event.burst.clamp(1, 5),
      ),
    );
    await likeLiveUseCase(id, burst: event.burst);
  }

  Future<void> _onGiftSent(
    LiveViewerGiftSent event,
    Emitter<LiveViewerState> emit,
  ) async {
    final session = state.session;
    final id = _activeLiveId;
    if (session == null || id == null) return;
    final result = await sendGiftUseCase(
      liveId: id,
      giftId: event.gift.id,
      quantity: event.quantity,
      receiverId: session.live.hostId,
    );
    await result.fold((_) async {}, (sent) async {
      final balance = session.coinBalance - sent.totalCost;
      var left = state.pkScoreLeft;
      var right = state.pkScoreRight;
      if (state.isPk) left += sent.totalCost;
      emit(
        state.copyWith(
          session: session.copyWith(coinBalance: balance < 0 ? 0 : balance),
          recentGifts: [sent, ...state.recentGifts].take(8).toList(),
          activeGiftAnimation: sent,
          coinDelta: -sent.totalCost,
          pkScoreLeft: left,
          pkScoreRight: right,
        ),
      );
      _coinDeltaClearTimer?.cancel();
      _coinDeltaClearTimer = Timer(const Duration(milliseconds: 800), () {
        if (_activeLiveId == id && !isClosed) {
          emit(state.copyWith(coinDelta: 0));
        }
      });
    });
  }

  Future<void> _onFollowToggled(
    LiveViewerFollowToggled event,
    Emitter<LiveViewerState> emit,
  ) async {
    final session = state.session;
    if (session == null) return;
    final next = !session.live.isFollowing;
    emit(
      state.copyWith(
        session: session.copyWith(
          live: session.live.copyWith(isFollowing: next),
        ),
      ),
    );
    if (next) {
      await liveRepository.followHost(session.live.hostId);
    } else {
      await liveRepository.unfollowHost(session.live.hostId);
    }
  }

  Future<void> _onHeartBurstConsumed(
    LiveViewerHeartBurstConsumed event,
    Emitter<LiveViewerState> emit,
  ) async {
    if (state.floatingHeartBurst > 0) {
      emit(state.copyWith(floatingHeartBurst: 0));
    }
  }

  Future<void> _onGiftAnimationCleared(
    LiveViewerGiftAnimationCleared event,
    Emitter<LiveViewerState> emit,
  ) async {
    emit(state.copyWith(clearGiftAnimation: true));
  }

  Future<void> _onModerationBannerConsumed(
    LiveViewerModerationBannerConsumed event,
    Emitter<LiveViewerState> emit,
  ) async {
    if (state.moderationBanner != null) {
      emit(state.copyWith(clearModerationBanner: true));
    }
  }

  // ── New moderation / chat event handlers ──────────────

  Future<void> _onCommentDeletedRequested(
    LiveViewerCommentDeletedRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = _activeLiveId;
    if (liveId == null) return;
    // Optimistic removal from the visible comment list.
    final nextComments = state.comments
        .where((c) => c.id != event.commentId)
        .toList(growable: false);
    emit(
      state.copyWith(
        comments: nextComments,
        clearPinnedComment: state.pinnedComment?.id == event.commentId,
      ),
    );
    final result = await deleteCommentUseCase(
      commentId: event.commentId,
      liveId: liveId,
    );
    await result.fold((failure) async {
      emit(state.copyWith(moderationBanner: 'Failed to delete comment'));
      _scheduleBannerClear();
    }, (_) async {});
  }

  Future<void> _onViewerChatMuteRequested(
    LiveViewerViewerChatMuteRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = _activeLiveId;
    if (liveId == null) return;
    final nextMuted = Set<String>.from(state.mutedUserIds)..add(event.userId);
    emit(
      state.copyWith(
        mutedUserIds: nextMuted,
        moderationBanner: event.username != null
            ? '${event.username} muted'
            : 'Viewer chat muted',
      ),
    );
    _scheduleBannerClear();
    final result = await muteViewerChatUseCase(
      liveId: liveId,
      userId: event.userId,
      reason: event.reason,
    );
    await result.fold((failure) async {
      final revert = Set<String>.from(state.mutedUserIds)..remove(event.userId);
      emit(
        state.copyWith(
          mutedUserIds: revert,
          moderationBanner:
              'Failed to mute: ${failure.message ?? 'Unknown error'}',
        ),
      );
      _scheduleBannerClear();
    }, (_) async {});
  }

  Future<void> _onViewerChatUnmuteRequested(
    LiveViewerViewerChatUnmuteRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = _activeLiveId;
    if (liveId == null) return;
    final nextMuted = Set<String>.from(state.mutedUserIds)
      ..remove(event.userId);
    emit(
      state.copyWith(
        mutedUserIds: nextMuted,
        moderationBanner: event.username != null
            ? '${event.username} unmuted'
            : 'Viewer chat unmuted',
      ),
    );
    _scheduleBannerClear();
    final result = await unmuteViewerChatUseCase(
      liveId: liveId,
      userId: event.userId,
    );
    await result.fold((failure) async {
      final revert = Set<String>.from(state.mutedUserIds)..add(event.userId);
      emit(
        state.copyWith(
          mutedUserIds: revert,
          moderationBanner:
              'Failed to unmute: ${failure.message ?? 'Unknown error'}',
        ),
      );
      _scheduleBannerClear();
    }, (_) async {});
  }

  Future<void> _onViewerBannedRequested(
    LiveViewerViewerBannedRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = _activeLiveId;
    if (liveId == null) return;
    // Optimistic: add to banned set & remove existing comments.
    final nextBanned = Set<String>.from(state.bannedUserIds)..add(event.userId);
    final nextComments = state.comments
        .where((c) => c.userId != event.userId)
        .toList(growable: false);
    emit(
      state.copyWith(
        bannedUserIds: nextBanned,
        comments: nextComments,
        clearPinnedComment: state.pinnedComment?.userId == event.userId,
        moderationBanner: event.username != null
            ? '${event.username} banned'
            : 'Viewer banned',
      ),
    );
    _scheduleBannerClear();
    final result = await banViewerUseCase(
      liveId: liveId,
      userId: event.userId,
      reason: event.reason,
    );
    await result.fold((failure) async {
      final revertBanned = Set<String>.from(state.bannedUserIds)
        ..remove(event.userId);
      emit(
        state.copyWith(
          bannedUserIds: revertBanned,
          moderationBanner:
              'Failed to ban: ${failure.message ?? 'Unknown error'}',
        ),
      );
      _scheduleBannerClear();
    }, (_) async {});
  }

  Future<void> _onViewerUnbannedRequested(
    LiveViewerViewerUnbannedRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = _activeLiveId;
    if (liveId == null) return;
    final nextBanned = Set<String>.from(state.bannedUserIds)
      ..remove(event.userId);
    emit(
      state.copyWith(
        bannedUserIds: nextBanned,
        moderationBanner: event.username != null
            ? '${event.username} unbanned'
            : 'Viewer unbanned',
      ),
    );
    _scheduleBannerClear();
    final result = await unbanViewerUseCase(
      liveId: liveId,
      userId: event.userId,
    );
    await result.fold((failure) async {
      final revert = Set<String>.from(state.bannedUserIds)..add(event.userId);
      emit(
        state.copyWith(
          bannedUserIds: revert,
          moderationBanner:
              'Failed to unban: ${failure.message ?? 'Unknown error'}',
        ),
      );
      _scheduleBannerClear();
    }, (_) async {});
  }

  Future<void> _onSendStateChanged(
    LiveViewerSendStateChanged event,
    Emitter<LiveViewerState> emit,
  ) async {
    emit(state.copyWith(isCommentSending: event.isSending));
  }

  Future<void> _onSocketEventReceived(
    LiveViewerSocketEventReceived event,
    Emitter<LiveViewerState> emit,
  ) async {
    final ev = event.event;
    if (ev is! SocketEvent) return;
    await _handleSocketEvent(ev, emit);
  }

  // ---------- Internal helpers ----------

  void _listenSocket(String liveId) {
    _socketSub?.cancel();
    _socketSub = socketService.events.listen((event) {
      if (_activeLiveId != liveId || event.liveId != liveId) return;
      add(LiveViewerSocketEventReceived(event));
    });
  }

  Future<void> _handleSocketEvent(
    SocketEvent event,
    Emitter<LiveViewerState> emit,
  ) async {
    final session = state.session;
    if (session == null) return;

    if (event is LiveCommentEvent) {
      // Silently drop comments from viewers who have been banned.
      if (state.bannedUserIds.contains(event.comment.userId)) return;
      if (state.comments.any((comment) => comment.id == event.comment.id)) {
        return;
      }
      final next = [...state.comments, event.comment];
      emit(
        state.copyWith(
          comments: next.length > 80 ? next.sublist(next.length - 80) : next,
          pinnedComment: event.comment.isPinned
              ? event.comment
              : state.pinnedComment,
        ),
      );
    } else if (event is LiveCommentDeletedEvent) {
      emit(
        state.copyWith(
          comments: state.comments
              .where((c) => c.id != event.commentId)
              .toList(),
          clearPinnedComment: state.pinnedComment?.id == event.commentId,
        ),
      );
    } else if (event is LiveCommentPinnedEvent) {
      final pinned = event.comment.copyWith(isPinned: true);
      emit(
        state.copyWith(
          comments: [
            for (final c in state.comments)
              c.id == pinned.id ? pinned : c.copyWith(isPinned: false),
          ],
          pinnedComment: pinned,
        ),
      );
    } else if (event is LiveCommentUnpinnedEvent) {
      emit(
        state.copyWith(
          comments: [
            for (final c in state.comments)
              c.id == event.commentId ? c.copyWith(isPinned: false) : c,
          ],
          clearPinnedComment: true,
        ),
      );
    } else if (event is LiveModerationEvent) {
      _applyModeration(event, emit);
    } else if (event is UserJoinedEvent) {
      if (_isMe(event.userId)) {
        if (event.viewerCount != null) {
          emit(
            state.copyWith(
              session: session.copyWith(
                live: session.live.copyWith(viewerCount: event.viewerCount!),
              ),
            ),
          );
        }
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
      final next = [...state.comments, joinNotice];
      emit(
        state.copyWith(
          comments: next.length > 80 ? next.sublist(next.length - 80) : next,
          topViewerAvatars: _pushAvatar(
            state.topViewerAvatars,
            event.avatarUrl,
          ),
          session: event.viewerCount != null
              ? session.copyWith(
                  live: session.live.copyWith(viewerCount: event.viewerCount!),
                )
              : session,
        ),
      );
    } else if (event is LiveLikeEvent) {
      final isSelf = _isMe(event.userId);
      emit(
        state.copyWith(
          session: session.copyWith(
            live: session.live.copyWith(likeCount: event.likeCount),
          ),
          floatingHeartBurst: isSelf
              ? state.floatingHeartBurst
              : state.floatingHeartBurst + event.delta.clamp(1, 3),
        ),
      );
    } else if (event is LiveViewersEvent) {
      emit(
        state.copyWith(
          session: session.copyWith(
            live: session.live.copyWith(viewerCount: event.viewerCount),
          ),
          topViewerAvatars: event.topViewerAvatars.isNotEmpty
              ? event.topViewerAvatars
              : state.topViewerAvatars,
        ),
      );
    } else if (event is LiveGiftEvent) {
      final random = Random();
      var left = state.pkScoreLeft;
      var right = state.pkScoreRight;
      if (state.isPk) {
        if (random.nextBool()) {
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
      final nextComments = [...state.comments, giftNotice];
      emit(
        state.copyWith(
          recentGifts: [event.gift, ...state.recentGifts].take(8).toList(),
          activeGiftAnimation: event.gift,
          pkScoreLeft: left,
          pkScoreRight: right,
          comments: nextComments.length > 80
              ? nextComments.sublist(nextComments.length - 80)
              : nextComments,
        ),
      );
    } else if (event is LiveEndedEvent) {
      emit(
        state.copyWith(
          session: session.copyWith(
            connectionState: LiveConnectionState.liveEnded,
            errorMessage: event.reason,
          ),
        ),
      );
    } else if (event is NetworkLostEvent) {
      emit(
        state.copyWith(
          session: session.copyWith(
            connectionState: LiveConnectionState.networkLost,
            isSocketConnected: false,
          ),
        ),
      );
    } else if (event is ReconnectingEvent) {
      emit(
        state.copyWith(
          session: session.copyWith(
            connectionState: LiveConnectionState.reconnecting,
            reconnectAttempt: event.attempt,
          ),
        ),
      );
      try {
        await liveKitService.reconnect();
      } catch (_) {}
    } else if (event is ReconnectedEvent) {
      emit(
        state.copyWith(
          session: session.copyWith(
            connectionState: LiveConnectionState.connected,
            isSocketConnected: true,
            isLiveKitConnected: true,
          ),
        ),
      );
    }
  }

  void _applyModeration(
    LiveModerationEvent event,
    Emitter<LiveViewerState> emit,
  ) {
    final isMe = _isMe(event.userId);
    final targetId = event.userId;
    switch (event.moderationType) {
      case 'chat_muted':
        if (isMe) {
          emit(
            state.copyWith(
              chatMuted: true,
              moderationBanner: event.reason?.isNotEmpty == true
                  ? 'Chat muted: ${event.reason}'
                  : 'Your chat was muted',
            ),
          );
          _scheduleBannerClear();
          return;
        }
        if (targetId == null || targetId.isEmpty) return;
        final nextMuted = Set<String>.from(state.mutedUserIds)..add(targetId);
        emit(state.copyWith(mutedUserIds: nextMuted));
        return;
      case 'chat_unmuted':
        if (isMe) {
          emit(
            state.copyWith(
              chatMuted: false,
              moderationBanner: 'Your chat was unmuted',
            ),
          );
          _scheduleBannerClear();
          return;
        }
        if (targetId == null || targetId.isEmpty) return;
        final nextMuted = Set<String>.from(state.mutedUserIds)
          ..remove(targetId);
        emit(state.copyWith(mutedUserIds: nextMuted));
        return;
      case 'viewer_banned':
        if (isMe) {
          unawaited(_kickBanned(event.reason, emit));
          return;
        }
        if (targetId == null || targetId.isEmpty) return;
        // OTHER user was banned — hide all their comments and block new ones.
        final nextBanned = Set<String>.from(state.bannedUserIds)..add(targetId);
        final nextComments = state.comments
            .where((c) => c.userId != targetId)
            .toList(growable: false);
        emit(
          state.copyWith(
            bannedUserIds: nextBanned,
            comments: nextComments,
            clearPinnedComment: state.pinnedComment?.userId == targetId,
          ),
        );
        return;
      case 'viewer_unbanned':
        if (isMe) {
          emit(
            state.copyWith(
              chatMuted: false,
              moderationBanner: 'You were unbanned from this live',
            ),
          );
          _scheduleBannerClear();
          return;
        }
        if (targetId == null || targetId.isEmpty) return;
        final nextBanned = Set<String>.from(state.bannedUserIds)
          ..remove(targetId);
        emit(state.copyWith(bannedUserIds: nextBanned));
        return;
      case 'chat_rules_updated':
        // Chat mode / slow mode / blocked keywords changed — no state to
        // mutate server-side; simply show a brief banner when relevant.
        if (isMe) {
          emit(state.copyWith(moderationBanner: 'Chat rules updated'));
          _scheduleBannerClear();
        }
        return;
      default:
        if (isMe) {
          emit(
            state.copyWith(
              moderationBanner: 'Moderation update: ${event.moderationType}',
            ),
          );
          _scheduleBannerClear();
        }
        return;
    }
  }

  Future<void> _kickBanned(
    String? reason,
    Emitter<LiveViewerState> emit,
  ) async {
    final session = state.session;
    try {
      await socketService.disconnect();
    } catch (_) {}
    try {
      await liveKitService.disconnect();
    } catch (_) {}
    final id = _activeLiveId;
    if (id != null) {
      try {
        await leaveLiveUseCase(id);
      } catch (_) {}
    }
    if (isClosed || session == null) return;
    emit(
      state.copyWith(
        session: session.copyWith(
          connectionState: LiveConnectionState.banned,
          isSocketConnected: false,
          isLiveKitConnected: false,
          errorMessage: reason?.isNotEmpty == true
              ? reason
              : 'You are banned from this live',
        ),
        chatMuted: true,
      ),
    );
  }

  void _scheduleBannerClear() {
    _bannerClearTimer?.cancel();
    _bannerClearTimer = Timer(const Duration(seconds: 3), () {
      if (!isClosed) add(const LiveViewerModerationBannerConsumed());
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
    return [
      avatarUrl,
      ...current.where((url) => url != avatarUrl),
    ].take(3).toList();
  }

  Future<String?> _loadCurrentUserId() async {
    try {
      final payload = await apiClient.get(ApiEndpoints.authMe);
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

  Future<void> _teardown({
    required bool silent,
    required Emitter<LiveViewerState> emit,
  }) async {
    _socketSub?.cancel();
    _socketSub = null;
    _bannerClearTimer?.cancel();
    _joinSuccessClearTimer?.cancel();
    _coinDeltaClearTimer?.cancel();
    final id = _activeLiveId;
    _activeLiveId = null;
    if (id != null) {
      try {
        await leaveLiveUseCase(id);
      } catch (_) {}
    }
    try {
      await socketService.disconnect();
    } catch (_) {}
    try {
      await liveKitService.disconnect();
    } catch (_) {}
    if (!silent && !isClosed) {
      emit(const LiveViewerState());
    }
  }

  @override
  Future<void> close() async {
    _socketSub?.cancel();
    _socketSub = null;
    _bannerClearTimer?.cancel();
    _joinSuccessClearTimer?.cancel();
    _coinDeltaClearTimer?.cancel();
    final id = _activeLiveId;
    _activeLiveId = null;
    if (id != null) {
      try {
        await leaveLiveUseCase(id);
      } catch (_) {}
    }
    try {
      await socketService.disconnect();
    } catch (_) {}
    try {
      await liveKitService.disconnect();
    } catch (_) {}
    await super.close();
  }
}
