import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart' show ConnectionState;
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../../../core/network/live_api_client.dart';
import '../../../../../core/models/live_battle.dart';
import '../../../../../core/models/live_competition_request.dart';
import '../../../data/services/fake_livekit_service.dart';
import '../../../data/services/fake_socket_service.dart';
import '../../../domain/entities/comment_entity.dart';
import '../../../domain/entities/live_entity.dart';
import '../../../domain/entities/live_session_entity.dart';
import '../../../domain/entities/socket_event.dart';
import '../../../domain/repositories/comment_repository.dart';
import '../../../domain/repositories/gift_repository.dart';
import '../../../domain/repositories/guest_repository.dart';
import '../../../domain/repositories/live_repository.dart';
import '../../../domain/repositories/like_repository.dart';
import '../../../domain/usecases/ban_viewer_usecase.dart';
import '../../../domain/usecases/delete_comment_usecase.dart';
import '../../../domain/usecases/join_live_usecase.dart';
import '../../../domain/usecases/leave_live_usecase.dart';
import '../../../domain/usecases/like_live_usecase.dart';
import '../../../domain/usecases/mute_viewer_chat_usecase.dart';
import '../../../domain/usecases/unban_viewer_usecase.dart';
import '../../../domain/usecases/unmute_viewer_chat_usecase.dart';
import 'live_viewer_event.dart';
import 'live_viewer_state.dart';

class LiveViewerBloc extends Bloc<LiveViewerEvent, LiveViewerState> {
  LiveViewerBloc({
    required this.joinLiveUseCase,
    required this.leaveLiveUseCase,
    required this.likeLiveUseCase,
    required this.giftSocketService,
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
    required this.guestRepository,
  }) : super(const LiveViewerState()) {
    on<LiveViewerActivated>(_onActivated);
    on<LiveViewerDeactivated>(_onDeactivated);
    on<LiveViewerRetryRequested>(_onRetryRequested);
    on<LiveViewerCommentSent>(_onCommentSent);
    on<LiveViewerLiked>(_onLiked);
    on<LiveViewerGiftBalanceRefreshRequested>(_onGiftBalanceRefreshRequested);
    on<LiveViewerGiftComboReceived>(_onGiftComboReceived);
    on<LiveViewerGiftComboConsumed>(_onGiftComboConsumed);
    on<LiveViewerFollowToggled>(_onFollowToggled);
    on<LiveViewerHeartBurstConsumed>(_onHeartBurstConsumed);
    on<LiveViewerGiftAnimationCleared>(_onGiftAnimationCleared);
    on<LiveViewerModerationBannerConsumed>(_onModerationBannerConsumed);
    on<LiveViewerJoinSuccessConsumed>(_onJoinSuccessConsumed);
    on<LiveViewerBattleSupportersRefreshRequested>(
      _onBattleSupportersRefreshRequested,
    );
    on<LiveViewerSocketEventReceived>(_onSocketEventReceived);
    on<LiveViewerCommentDeletedRequested>(_onCommentDeletedRequested);
    on<LiveViewerViewerChatMuteRequested>(_onViewerChatMuteRequested);
    on<LiveViewerViewerChatUnmuteRequested>(_onViewerChatUnmuteRequested);
    on<LiveViewerViewerBannedRequested>(_onViewerBannedRequested);
    on<LiveViewerViewerUnbannedRequested>(_onViewerUnbannedRequested);
    on<LiveViewerSendStateChanged>(_onSendStateChanged);
    on<LiveViewerGuestSeatRequested>(_onGuestSeatRequested);
    on<LiveViewerGuestInviteAnswered>(_onGuestInviteAnswered);
    on<LiveViewerLeftStage>(_onLeftStage);
    on<LiveViewerCompetitionRequested>(_onCompetitionRequested);
    on<LiveViewerGuestsRefreshed>(_onGuestsRefreshed);
    on<LiveViewerGuestApprovalChecked>(_onGuestApprovalChecked);
    on<LiveViewerLiveKitStateChanged>(_onLiveKitStateChanged);
    on<LiveViewerBattleRoomStateChanged>(_onBattleRoomStateChanged);

    _liveKitSub = liveKitService.stateStream.listen((mediaState) {
      if (!isClosed) add(LiveViewerLiveKitStateChanged(mediaState));
    });
    _battleSub = liveKitService.battleStateStream.listen((mediaState) {
      if (!isClosed) add(LiveViewerBattleRoomStateChanged(mediaState));
    });
  }
  final JoinLiveUseCase joinLiveUseCase;
  final LeaveLiveUseCase leaveLiveUseCase;
  final LikeLiveUseCase likeLiveUseCase;
  final AuctionSocketService giftSocketService;
  final BanViewerUseCase banViewerUseCase;
  final UnbanViewerUseCase unbanViewerUseCase;
  final MuteViewerChatUseCase muteViewerChatUseCase;
  final UnmuteViewerChatUseCase unmuteViewerChatUseCase;
  final DeleteCommentUseCase deleteCommentUseCase;
  final GuestRepository guestRepository;
  final LiveRepository liveRepository;
  final CommentRepository commentRepository;
  final GiftRepository giftRepository;
  final LikeRepository likeRepository;
  final SocketService socketService;
  final LiveKitService liveKitService;
  final LiveApiClient apiClient;

  StreamSubscription<SocketEvent>? _socketSub;
  StreamSubscription<GiftComboPayload>? _giftComboSub;
  StreamSubscription<LiveKitConnectionState>? _liveKitSub;
  StreamSubscription<LiveKitConnectionState>? _battleSub;
  String? _activeLiveId;
  bool _busy = false;
  LiveEntity? _pendingActivate;
  bool _deactivateRequested = false;
  String? _currentUserId;
  Timer? _bannerClearTimer;
  Timer? _joinSuccessClearTimer;
  Timer? _guestApprovalTimer;
  Timer? _battleSupportersRefreshTimer;
  DateTime? _battleSupportersRefreshedAt;
  String? _battleOpponentLiveId;

  /// Keeps one media connect per battle/opponent pair while allowing a newer
  /// battle to invalidate an older in-flight operation.
  final _battleConnectKeys = <String>{};
  int _battleOperationGeneration = 0;
  var _battleRoomRecoveryInFlight = false;
  bool _tearingDown = false;
  bool _recoveringMedia = false;
  int _mediaRecoveryAttempt = 0;

  String? get activeLiveId => _activeLiveId;

  // ---------- Event handlers ----------

  Future<void> _onActivated(
    LiveViewerActivated event,
    Emitter<LiveViewerState> emit,
  ) async {
    if (_busy) {
      _pendingActivate = event.live;
      // The newest visible page wins over an older close/deactivate request.
      _deactivateRequested = false;
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

      emit(
        LiveViewerState(
          session: LiveSessionEntity(
            live: live,
            connectionState: LiveConnectionState.connecting,
          ),
          topViewerAvatars: initialAvatars.isNotEmpty
              ? initialAvatars
              : const [],
          pkScoreLeft: isPk
              ? ((live.metadata?['scoreLeft'] as num?)?.toInt() ?? 0)
              : 0,
          pkScoreRight: isPk
              ? ((live.metadata?['scoreRight'] as num?)?.toInt() ?? 0)
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
          } catch (_) {
            // Diagnostics only; token parsing must never block joining.
          }

          try {
            await liveKitService.connect(
              url: result.liveKitUrl,
              token: result.liveKitToken,
              roomName: result.liveId,
              mockStreamUrl: result.live.streamUrl,
              mediaHints: result.mediaHints,
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
                add(const LiveViewerJoinSuccessConsumed());
              }
            },
          );

          // Subscribe before dialing so a fast initial connection cannot be
          // missed. Realtime is independent from LiveKit: a HUD timeout must
          // never tear down video or block comments/coin enrichment.
          _listenSocket(live.id);
          _listenGiftSocket(live.id);
          unawaited(
            socketService
                .connect(liveId: result.liveId, token: result.socketToken)
                .catchError((_) {}),
          );
          unawaited(
            giftSocketService.ensureJoined(liveId: live.id).catchError((_) {}),
          );
          final coinsFuture = giftRepository.getCoinBalance();
          final commentsFuture = commentRepository.getComments(
            liveId: live.id,
            limit: 20,
          );
          final meFuture = _loadCurrentUserId();
          final guestsFuture = guestRepository.listGuests(live.id);
          final topGiftersFuture = _loadTopGifterAvatars(live.id);

          try {
            final results = await Future.wait<dynamic>([
              coinsFuture,
              commentsFuture,
              meFuture,
              guestsFuture,
              topGiftersFuture,
            ]);
            if (_activeLiveId != live.id) return;

            final coins = results[0];
            final commentsResult = results[1];
            _currentUserId = results[2] as String? ?? _currentUserId;
            final guestsResult = results[3];
            final topGifters = results[4] as List<String>?;
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

            emit(
              state.copyWith(
                session: state.session!.copyWith(
                  isSocketConnected: socketService.isConnected,
                  coinBalance: coins.getOrElse(() => 1250),
                ),
                comments: comments,
                pinnedComment: pinned,
                currentUserId: _currentUserId,
                guests: guestsResult.fold(
                  (_) => state.guests,
                  (items) => items,
                ),
                topViewerAvatars: topGifters ?? state.topViewerAvatars,
              ),
            );
          } catch (_) {}
          await _refreshBattle(live.id, emit);
        },
      );
    } finally {
      final shouldDeactivate = _deactivateRequested;
      _deactivateRequested = false;
      if (shouldDeactivate) {
        _pendingActivate = null;
        await _teardown(silent: false, emit: emit);
      }
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
    // Activated/Deactivated have separate BLoC event types and can otherwise
    // run concurrently. A late teardown from the previous PageView page would
    // then disconnect the brand-new room opened by the visible page.
    if (_busy) {
      _pendingActivate = null;
      _deactivateRequested = true;
      return;
    }
    _busy = true;
    try {
      await _teardown(silent: false, emit: emit);
    } finally {
      _busy = false;
      final pending = _pendingActivate;
      _pendingActivate = null;
      if (pending != null) add(LiveViewerActivated(pending));
    }
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
    final inMutedUserIds =
        currentUserUid != null && state.mutedUserIds.contains(currentUserUid);
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
        final msg = failure.message;
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
              comments: _capComments([...emitState.comments, comment]),
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

  Future<void> _onGiftBalanceRefreshRequested(
    LiveViewerGiftBalanceRefreshRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final session = state.session;
    final id = _activeLiveId;
    if (session == null || id == null) return;
    final result = await giftRepository.getCoinBalance();
    if (_activeLiveId != id || isClosed) return;
    result.fold(
      (_) {},
      (balance) =>
          emit(state.copyWith(session: session.copyWith(coinBalance: balance))),
    );
  }

  Future<void> _onGiftComboReceived(
    LiveViewerGiftComboReceived event,
    Emitter<LiveViewerState> emit,
  ) async {
    final session = state.session;
    final id = _activeLiveId;
    if (session == null || id == null) return;
    final eventLiveId = event.payload.liveId.trim();
    if (eventLiveId.isNotEmpty && eventLiveId != id) return;
    emit(state.copyWith(latestGiftCombo: event.payload));
  }

  Future<void> _onGiftComboConsumed(
    LiveViewerGiftComboConsumed event,
    Emitter<LiveViewerState> emit,
  ) async {
    // Only the combo that was actually presented is released, so a gift that
    // arrived while the previous one was playing is still rendered.
    if (!identical(state.latestGiftCombo, event.payload)) return;
    emit(state.copyWith(clearGiftCombo: true));
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

  Future<void> _onJoinSuccessConsumed(
    LiveViewerJoinSuccessConsumed event,
    Emitter<LiveViewerState> emit,
  ) async {
    if (state.showJoinSuccess) {
      emit(state.copyWith(showJoinSuccess: false));
    }
  }

  Future<void> _onBattleSupportersRefreshRequested(
    LiveViewerBattleSupportersRefreshRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = _activeLiveId;
    final battle = state.battle;
    if (liveId == null || battle?.isActive != true) return;
    final opponentId = battle!.opponentLiveId(liveId);
    if (opponentId.isEmpty || opponentId == liveId) return;
    _battleSupportersRefreshedAt = DateTime.now();

    final results = await Future.wait<List<String>?>([
      _loadTopGifterAvatars(liveId),
      _loadTopGifterAvatars(opponentId),
    ]);
    if (isClosed || _activeLiveId != liveId) return;
    emit(
      state.copyWith(
        topViewerAvatars: results[0] ?? state.topViewerAvatars,
        opponentTopGifterAvatars: results[1] ?? state.opponentTopGifterAvatars,
      ),
    );
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
          moderationBanner: 'Failed to mute: ${failure.message}',
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
          moderationBanner: 'Failed to unmute: ${failure.message}',
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
          moderationBanner: 'Failed to ban: ${failure.message}',
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
          moderationBanner: 'Failed to unban: ${failure.message}',
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

  // ---------- Multi-guest ----------

  /// Ask the host for a seat on stage. Permissions are granted before the
  /// request leaves the device, so acceptance can publish without another UI
  /// pause. Capture still starts only after server-issued publish credentials.
  Future<void> _onGuestSeatRequested(
    LiveViewerGuestSeatRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = state.live?.id;
    if (liveId == null || liveId.isEmpty || state.isGuestActionBusy) return;

    emit(state.copyWith(isGuestActionBusy: true));
    try {
      await liveKitService.prepareStage();
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            isGuestActionBusy: false,
            moderationBanner: error.toString().replaceFirst('Bad state: ', ''),
          ),
        );
      }
      return;
    }
    final result = await guestRepository.requestSeat(liveId);
    if (isClosed) return;
    await result.fold(
      (failure) async => emit(
        state.copyWith(
          isGuestActionBusy: false,
          moderationBanner: 'تعذر إرسال طلب الانضمام: ${failure.message}',
        ),
      ),
      (credentials) async {
        if (credentials != null && credentials.isUsable) {
          await _joinGuestStage(
            liveId: liveId,
            credentials: credentials,
            emit: emit,
          );
          return;
        }
        emit(
          state.copyWith(
            isGuestActionBusy: true,
            moderationBanner: 'تم إرسال طلب الانضمام إلى المضيف',
          ),
        );
        // Keep the request pending while we wait for the host. Socket.IO is
        // still the fast path; this bounded token poll covers an acceptance
        // event lost during a reconnect without ever granting publication to
        // a user the backend has not marked ACTIVE.
        _scheduleGuestApprovalCheck(liveId);
      },
    );
    add(const LiveViewerGuestsRefreshed());
  }

  /// Accept or decline an invite. Accepting swaps the subscribe-only LiveKit
  /// connection for the publish one the server just issued.
  Future<void> _onGuestInviteAnswered(
    LiveViewerGuestInviteAnswered event,
    Emitter<LiveViewerState> emit,
  ) async {
    final invite = state.pendingGuestInvite;
    if (invite == null) return;

    // Clear first either way: an invite left standing through a failed accept
    // is what makes the button look dead.
    emit(state.copyWith(clearPendingGuestInvite: true));
    if (!event.accepted) return;

    emit(state.copyWith(isGuestActionBusy: true));
    final result = await guestRepository.acceptInvite(invite.liveId);
    if (isClosed) return;

    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            isGuestActionBusy: false,
            moderationBanner: 'تعذر الانضمام إلى المسرح: ${failure.message}',
          ),
        );
      },
      (creds) async {
        if (!creds.isUsable) {
          emit(
            state.copyWith(
              isGuestActionBusy: false,
              moderationBanner:
                  'قبلت الدعوة، لكن الخادم لم يرسل بيانات LiveKit للنشر.',
            ),
          );
          return;
        }
        await _joinGuestStage(
          liveId: invite.liveId,
          credentials: creds,
          emit: emit,
        );
      },
    );
  }

  /// Step off the stage and go back to watching.
  Future<void> _onLeftStage(
    LiveViewerLeftStage event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = state.live?.id;
    if (liveId == null || liveId.isEmpty) return;

    emit(state.copyWith(isGuestActionBusy: true));
    await liveKitService.leaveStage();
    final result = await guestRepository.leaveStage(liveId);
    if (isClosed) return;
    emit(
      state.copyWith(
        isGuestActionBusy: false,
        isOnStage: false,
        moderationBanner: result.fold(
          (failure) =>
              'غادرت المسرح محلياً، لكن الخادم لم يستجب: '
              '${failure.message}',
          (_) => 'غادرت المسرح',
        ),
      ),
    );
    add(const LiveViewerGuestsRefreshed());
  }

  Future<void> _onCompetitionRequested(
    LiveViewerCompetitionRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = state.live?.id;
    if (liveId == null || liveId.isEmpty || !state.isOnStage) return;
    if (state.isGuestActionBusy) return;

    emit(state.copyWith(isGuestActionBusy: true));
    final result = await commentRepository.sendComment(
      liveId: liveId,
      content: liveCompetitionRequestContent,
    );
    if (isClosed || _activeLiveId != liveId) return;
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            isGuestActionBusy: false,
            moderationBanner: 'تعذر إرسال طلب المنافسة: ${failure.message}',
          ),
        );
      },
      (comment) async {
        if (comment.userId.isNotEmpty) {
          _currentUserId ??= comment.userId;
        }
        final comments = state.comments.any((item) => item.id == comment.id)
            ? state.comments
            : [...state.comments, comment];
        emit(
          state.copyWith(
            comments: comments,
            currentUserId: _currentUserId,
            isGuestActionBusy: false,
            moderationBanner: 'تم إرسال طلب المنافسة إلى المضيف',
          ),
        );
      },
    );
    _scheduleBannerClear();
  }

  Future<void> _onGuestsRefreshed(
    LiveViewerGuestsRefreshed event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = state.live?.id;
    if (liveId == null || liveId.isEmpty) return;
    final result = await guestRepository.listGuests(liveId);
    if (isClosed) return;
    result.fold((_) {}, (guests) => emit(state.copyWith(guests: guests)));
  }

  Future<void> _onGuestApprovalChecked(
    LiveViewerGuestApprovalChecked event,
    Emitter<LiveViewerState> emit,
  ) async {
    if (_activeLiveId != event.liveId ||
        state.isOnStage ||
        !state.isGuestActionBusy) {
      _guestApprovalTimer?.cancel();
      _guestApprovalTimer = null;
      return;
    }

    final result = await guestRepository.refreshStageCredentials(event.liveId);
    if (isClosed || _activeLiveId != event.liveId) return;

    final credentials = result.fold<GuestStageCredentials?>(
      (_) => null,
      (c) => c,
    );
    if (credentials != null && credentials.isUsable) {
      _guestApprovalTimer?.cancel();
      _guestApprovalTimer = null;
      await _joinGuestStage(
        liveId: event.liveId,
        credentials: credentials,
        emit: emit,
      );
      return;
    }

    if (event.attempt >= 15) {
      _guestApprovalTimer?.cancel();
      _guestApprovalTimer = null;
      emit(
        state.copyWith(
          isGuestActionBusy: false,
          moderationBanner: 'طلب الانضمام ما زال بانتظار المضيف',
        ),
      );
      return;
    }

    _scheduleGuestApprovalCheck(event.liveId, attempt: event.attempt + 1);
  }

  Future<void> _onLiveKitStateChanged(
    LiveViewerLiveKitStateChanged event,
    Emitter<LiveViewerState> emit,
  ) async {
    final session = state.session;
    final liveId = _activeLiveId;
    if (session == null || liveId == null || _tearingDown) return;
    if (session.connectionState == LiveConnectionState.liveEnded ||
        session.connectionState == LiveConnectionState.banned) {
      return;
    }

    switch (event.state) {
      case LiveKitConnectionState.connected:
        _mediaRecoveryAttempt = 0;
        emit(
          state.copyWith(
            session: session.copyWith(
              connectionState: LiveConnectionState.connected,
              isLiveKitConnected: true,
              reconnectAttempt: 0,
            ),
          ),
        );
        return;
      case LiveKitConnectionState.connecting:
      case LiveKitConnectionState.reconnecting:
        if (_busy || _recoveringMedia) return;
        emit(
          state.copyWith(
            session: session.copyWith(
              connectionState: LiveConnectionState.reconnecting,
              isLiveKitConnected: false,
            ),
          ),
        );
        return;
      case LiveKitConnectionState.disconnected:
      case LiveKitConnectionState.failed:
        // connect() deliberately disconnects the previous Room first. Ignore
        // that internal transition while activation/recovery is in flight.
        if (_busy || _recoveringMedia) return;
        emit(
          state.copyWith(
            session: session.copyWith(
              connectionState: LiveConnectionState.reconnecting,
              isLiveKitConnected: false,
            ),
          ),
        );
        await _recoverMedia(liveId, emit);
        return;
    }
  }

  /// A terminal LiveKit disconnect cannot safely reuse its old JWT (tokens
  /// expire and ICE restarts can outlive them). Re-join REST to obtain fresh
  /// subscribe credentials, or a fresh publish token when this viewer is on
  /// the guest stage, then rebuild the Room with bounded backoff.
  Future<void> _recoverMedia(
    String liveId,
    Emitter<LiveViewerState> emit,
  ) async {
    if (_recoveringMedia || _tearingDown || _activeLiveId != liveId) return;
    _recoveringMedia = true;
    try {
      for (var attempt = 1; attempt <= 4; attempt++) {
        if (_tearingDown || isClosed || _activeLiveId != liveId) return;
        _mediaRecoveryAttempt = attempt;
        if (attempt > 1) {
          await Future<void>.delayed(Duration(seconds: attempt - 1));
        }
        if (_tearingDown || isClosed || _activeLiveId != liveId) return;

        try {
          if (state.isOnStage) {
            final credentials = await guestRepository.refreshStageCredentials(
              liveId,
            );
            final creds = credentials.fold<GuestStageCredentials?>(
              (_) => null,
              (value) => value,
            );
            if (creds == null || !creds.isUsable) continue;
            await liveKitService.joinStage(
              url: creds.url,
              token: creds.token,
              roomName: liveId,
              mediaHints: creds.mediaHints,
            );
          } else {
            final joined = await joinLiveUseCase(liveId);
            final result = joined.fold<JoinLiveResult?>(
              (_) => null,
              (value) => value,
            );
            if (result == null) continue;
            await liveKitService.connect(
              url: result.liveKitUrl,
              token: result.liveKitToken,
              roomName: result.liveId,
              mockStreamUrl: result.live.streamUrl,
              mediaHints: result.mediaHints,
            );
          }
          if (isClosed || _activeLiveId != liveId) return;
          final current = state.session;
          if (current != null) {
            emit(
              state.copyWith(
                session: current.copyWith(
                  connectionState: LiveConnectionState.connected,
                  isLiveKitConnected: true,
                  reconnectAttempt: 0,
                ),
                // Recovery is intentionally silent; the viewer keeps the last
                // frame instead of seeing disconnect/reconnect banners.
                moderationBanner: null,
              ),
            );
          }
          _mediaRecoveryAttempt = 0;
          return;
        } catch (_) {
          final current = state.session;
          if (current != null && !isClosed) {
            emit(
              state.copyWith(
                session: current.copyWith(
                  connectionState: LiveConnectionState.reconnecting,
                  isLiveKitConnected: false,
                  reconnectAttempt: attempt,
                ),
              ),
            );
          }
        }
      }

      final current = state.session;
      if (current != null && !isClosed && _activeLiveId == liveId) {
        emit(
          state.copyWith(
            session: current.copyWith(
              connectionState: LiveConnectionState.networkLost,
              isLiveKitConnected: false,
              reconnectAttempt: _mediaRecoveryAttempt,
              errorMessage: 'تعذر استعادة اتصال الفيديو. اضغط لإعادة المحاولة.',
            ),
          ),
        );
      }
    } finally {
      _recoveringMedia = false;
    }
  }

  // ---------- Internal helpers ----------

  void _listenSocket(String liveId) {
    _socketSub?.cancel();
    _socketSub = socketService.events.listen((event) {
      if (_activeLiveId != liveId || event.liveId != liveId) return;
      add(LiveViewerSocketEventReceived(event));
    });
  }

  void _listenGiftSocket(String liveId) {
    _giftComboSub?.cancel();
    _giftComboSub = giftSocketService.onGiftCombo.listen((payload) {
      if (_activeLiveId != liveId) return;
      final payloadLiveId = payload.liveId.trim();
      if (payloadLiveId.isNotEmpty && payloadLiveId != liveId) return;
      add(LiveViewerGiftComboReceived(payload));
    });
  }

  Future<void> _handleSocketEvent(
    SocketEvent event,
    Emitter<LiveViewerState> emit,
  ) async {
    final session = state.session;
    if (session == null) return;

    if (event is LiveGuestInviteEvent) {
      // Parked in state: the prompt has to still be tappable a few seconds
      // after it lands, which a one-shot banner never was.
      emit(
        state.copyWith(
          pendingGuestInvite: PendingGuestInvite(
            liveId: event.liveId,
            hostName: event.hostName ?? 'المضيف',
            role: event.role,
          ),
        ),
      );
      return;
    }

    if (event is LiveGuestUpdateEvent) {
      if (event.affectsStage) {
        add(const LiveViewerGuestsRefreshed());
      }
      // Being removed from the stage has to stop the camera locally too — the
      // server revoking the grant does not turn the hardware off by itself.
      final isMe = _isMe(event.guestUserId);
      if (isMe && event.updateType == 'joined' && !state.isOnStage) {
        final result = await guestRepository.refreshStageCredentials(
          event.liveId,
        );
        if (isClosed) return;
        await result.fold(
          (failure) async => emit(
            state.copyWith(
              isGuestActionBusy: false,
              moderationBanner:
                  'تم قبولك، لكن تعذر تشغيل الكاميرا: ${failure.message}',
            ),
          ),
          (credentials) => _joinGuestStage(
            liveId: event.liveId,
            credentials: credentials,
            emit: emit,
          ),
        );
        return;
      }
      if (isMe &&
          (event.updateType == 'kicked' || event.updateType == 'left')) {
        await liveKitService.leaveStage();
        emit(state.copyWith(isOnStage: false));
      } else if (isMe && event.updateType == 'muted') {
        await liveKitService.setStageMicrophoneEnabled(false);
      } else if (isMe && event.updateType == 'unmuted') {
        await liveKitService.setStageMicrophoneEnabled(true);
      } else if (isMe && event.updateType == 'camera_off') {
        await liveKitService.setStageCameraEnabled(false);
      } else if (isMe && event.updateType == 'camera_on') {
        await liveKitService.setStageCameraEnabled(true);
      }
      return;
    }

    if (event is LiveBattleEvent) {
      await _applyBattle(event.battle, emit);
      _scheduleBattleSupportersRefresh();
      return;
    }

    if (event is LiveTopGiftersUpdatedEvent) {
      emit(state.copyWith(topViewerAvatars: event.avatarUrls));
      return;
    }

    if (event is LiveCommentEvent) {
      // Silently drop comments from viewers who have been banned.
      if (state.bannedUserIds.contains(event.comment.userId)) return;
      if (state.comments.any((comment) => comment.id == event.comment.id)) {
        return;
      }
      final next = [...state.comments, event.comment];
      emit(
        state.copyWith(
          comments: _capComments(next),
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
      await _applyModeration(event, emit);
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
          comments: _capComments(next),
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
        ),
      );
    } else if (event is LiveEndedEvent) {
      await _disconnectBattleOpponent();
      emit(
        state.copyWith(
          session: session.copyWith(
            connectionState: LiveConnectionState.liveEnded,
            errorMessage: event.reason,
          ),
          clearBattle: true,
          clearBattleOpponent: true,
          battleRoom: null,
          opponentTopGifterAvatars: const [],
        ),
      );
    } else if (event is NetworkLostEvent) {
      emit(
        state.copyWith(
          session: session.copyWith(
            // Socket.IO carries comments and HUD events only. Keep rendering
            // the LiveKit stream while it reconnects in the background.
            connectionState: session.isLiveKitConnected
                ? LiveConnectionState.connected
                : LiveConnectionState.networkLost,
            isSocketConnected: false,
          ),
        ),
      );
    } else if (event is ReconnectingEvent) {
      emit(
        state.copyWith(
          session: session.copyWith(
            connectionState: session.isLiveKitConnected
                ? LiveConnectionState.connected
                : LiveConnectionState.reconnecting,
            reconnectAttempt: event.attempt,
            isSocketConnected: false,
          ),
        ),
      );
    } else if (event is ReconnectedEvent) {
      final mediaConnected =
          liveKitService.state == LiveKitConnectionState.connected;
      emit(
        state.copyWith(
          session: session.copyWith(
            connectionState: mediaConnected
                ? LiveConnectionState.connected
                : LiveConnectionState.reconnecting,
            isSocketConnected: true,
            // Socket.IO only restores comments/HUD. It must never hide a
            // still-disconnected LiveKit video room.
            isLiveKitConnected: mediaConnected,
          ),
        ),
      );
    }
  }

  Future<void> _applyModeration(
    LiveModerationEvent event,
    Emitter<LiveViewerState> emit,
  ) async {
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
          // Must be awaited: `emit` is handed to it, and an emit that lands
          // after this handler returns trips bloc's `!_isCompleted` assertion
          // and aborts the rest of the socket event pipeline.
          await _kickBanned(event.reason, emit);
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

  void _scheduleGuestApprovalCheck(String liveId, {int attempt = 1}) {
    _guestApprovalTimer?.cancel();
    _guestApprovalTimer = Timer(const Duration(seconds: 2), () {
      if (!isClosed && _activeLiveId == liveId) {
        add(LiveViewerGuestApprovalChecked(liveId: liveId, attempt: attempt));
      }
    });
  }

  Future<void> _joinGuestStage({
    required String liveId,
    required GuestStageCredentials credentials,
    required Emitter<LiveViewerState> emit,
  }) async {
    if (!credentials.isUsable) {
      emit(
        state.copyWith(
          isGuestActionBusy: false,
          moderationBanner: 'الخادم لم يرسل بيانات LiveKit للنشر.',
        ),
      );
      return;
    }
    try {
      _guestApprovalTimer?.cancel();
      _guestApprovalTimer = null;
      await liveKitService.joinStage(
        url: credentials.url,
        token: credentials.token,
        roomName: liveId,
        mediaHints: credentials.mediaHints,
      );
      if (isClosed || _activeLiveId != liveId) return;
      emit(
        state.copyWith(
          isGuestActionBusy: false,
          isOnStage: true,
          moderationBanner: credentials.isCoHost
              ? 'انضممت كمضيف مشارك'
              : 'انضممت إلى المسرح',
        ),
      );
      add(const LiveViewerGuestsRefreshed());
    } catch (e) {
      if (isClosed) return;
      final message = e.toString().replaceFirst('Bad state: ', '');
      emit(
        state.copyWith(
          isGuestActionBusy: false,
          isOnStage: false,
          moderationBanner: 'تعذر تشغيل الكاميرا للنشر: $message',
        ),
      );
    }
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

  /// How deep the viewer keeps its comment backlog. One constant so every
  /// append trims identically — the room used to trim socket comments and join
  /// notices but let the viewer's own sends grow for the whole watch session.
  static const int _commentBacklogLimit = 80;

  static List<CommentEntity> _capComments(List<CommentEntity> comments) {
    if (comments.length <= _commentBacklogLimit) return comments;
    return comments.sublist(comments.length - _commentBacklogLimit);
  }

  Future<List<String>?> _loadTopGifterAvatars(String liveId) async {
    try {
      final result = await giftRepository.getTopGifters(liveId, limit: 3);
      return result.fold<List<String>?>(
        (_) => null,
        (entries) => entries
            .map((entry) => entry.avatarUrl?.trim())
            .whereType<String>()
            .where((url) => url.isNotEmpty)
            .take(3)
            .toList(growable: false),
      );
    } catch (_) {
      // Supporter enrichment must never block the video room.
      return null;
    }
  }

  /// Debounced, but with a ceiling.
  ///
  /// Battle score events land on every gift, and a plain trailing debounce
  /// never fires while they keep coming — each one pushed the timer out again,
  /// so the ring froze during exactly the burst it exists to show.
  static const Duration _supportersRefreshMaxWait = Duration(seconds: 4);

  void _scheduleBattleSupportersRefresh() {
    final last = _battleSupportersRefreshedAt;
    if (last != null &&
        DateTime.now().difference(last) >= _supportersRefreshMaxWait) {
      _battleSupportersRefreshTimer?.cancel();
      _battleSupportersRefreshTimer = null;
      if (!isClosed && state.battle?.isActive == true) {
        add(const LiveViewerBattleSupportersRefreshRequested());
      }
      return;
    }
    _battleSupportersRefreshTimer?.cancel();
    _battleSupportersRefreshTimer = Timer(
      const Duration(milliseconds: 600),
      () {
        if (!isClosed && state.battle?.isActive == true) {
          add(const LiveViewerBattleSupportersRefreshRequested());
        }
      },
    );
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

  Future<void> _refreshBattle(
    String liveId,
    Emitter<LiveViewerState> emit,
  ) async {
    try {
      final payload = await apiClient.get(ApiEndpoints.liveBattle(liveId));
      if (_activeLiveId != liveId || isClosed) return;
      final raw = payload['battle'] ?? payload['data'];
      if (raw == null && payload['id'] == null) {
        // A socket `started` event can beat this initial GET. Keep the newer
        // event instead of replacing it with an older no-battle snapshot.
        if (state.battle?.isActive == true) return;
        await _disconnectBattleOpponent();
        emit(
          state.copyWith(
            clearBattle: true,
            clearBattleOpponent: true,
            battleRoom: null,
            opponentTopGifterAvatars: const [],
            pkScoreLeft: 0,
            pkScoreRight: 0,
          ),
        );
        return;
      }
      final source = raw is Map ? Map<String, dynamic>.from(raw) : payload;
      if (source['id'] != null) {
        await _applyBattle(LiveBattle.fromJson(source), emit);
      }
    } catch (_) {
      // A room can simply have no battle; watching the primary video must not
      // fail because this optional enrichment endpoint is unavailable.
    }
  }

  Future<void> _applyBattle(
    LiveBattle battle,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = _activeLiveId;
    if (liveId == null || isClosed) return;
    battle = battle.withTimingFrom(state.battle);
    final opponentId = battle.isActive ? battle.opponentLiveId(liveId) : '';
    final previousOpponentId = state.battle?.isActive == true
        ? state.battle!.opponentLiveId(liveId)
        : '';
    final battleIdentityChanged =
        !battle.isActive ||
        state.battle?.id != battle.id ||
        previousOpponentId != opponentId;
    if (battleIdentityChanged) _battleRoomRecoveryInFlight = false;
    final currentBattleRoom = state.battleRoom;
    final roomNeedsReplacement =
        battleIdentityChanged ||
        currentBattleRoom == null ||
        currentBattleRoom.connectionState == ConnectionState.disconnected;
    final battleKey = battle.isActive ? '${battle.id}:$opponentId' : '';
    final connectionAlreadyInFlight = _battleConnectKeys.contains(battleKey);
    final startsMediaOperation =
        !battle.isActive || (roomNeedsReplacement && !connectionAlreadyInFlight);
    final operationGeneration = startsMediaOperation
        ? ++_battleOperationGeneration
        : _battleOperationGeneration;

    emit(
      state.copyWith(
        battle: battle,
        battleRoom: roomNeedsReplacement ? null : currentBattleRoom,
        pkScoreLeft: battle.scoreFor(liveId),
        pkScoreRight: battle.opponentScoreFor(liveId),
      ),
    );
    if (!battle.isActive) {
      await _disconnectBattleOpponent(invalidate: false);
      if (
        isClosed ||
        _tearingDown ||
        operationGeneration != _battleOperationGeneration
      ) {
        return;
      }
      emit(
        state.copyWith(
          clearBattleOpponent: true,
          battleRoom: null,
          opponentTopGifterAvatars: const [],
        ),
      );
      return;
    }
    if (opponentId.isEmpty || opponentId == liveId) return;
    if (connectionAlreadyInFlight) return;
    if (_battleRoomRecoveryInFlight) return;
    if (!roomNeedsReplacement) return;
    _battleConnectKeys.add(battleKey);
    try {
      await _connectBattleOpponent(
        battle: battle,
        liveId: liveId,
        opponentId: opponentId,
        generation: operationGeneration,
        emit: emit,
      );
    } finally {
      _battleConnectKeys.remove(battleKey);
    }
  }

  Future<void> _onBattleRoomStateChanged(
    LiveViewerBattleRoomStateChanged event,
    Emitter<LiveViewerState> emit,
  ) async {
    if (
      isClosed ||
      _tearingDown ||
      _activeLiveId == null ||
      state.battle?.isActive != true
    ) {
      return;
    }
    switch (event.state) {
      case LiveKitConnectionState.disconnected:
      case LiveKitConnectionState.failed:
        if (
          event.state == LiveKitConnectionState.disconnected &&
          _battleConnectKeys.isEmpty
        ) {
          _battleRoomRecoveryInFlight = true;
        } else {
          _battleRoomRecoveryInFlight = false;
        }
        if (state.battleRoom != null) {
          emit(state.copyWith(battleRoom: null));
        }
        return;
      case LiveKitConnectionState.connected:
        _battleRoomRecoveryInFlight = false;
        final room = liveKitService.battleRoom;
        if (room != null) emit(state.copyWith(battleRoom: room));
        return;
      case LiveKitConnectionState.connecting:
      case LiveKitConnectionState.reconnecting:
        return;
    }
  }

  Future<void> _connectBattleOpponent({
    required LiveBattle battle,
    required String liveId,
    required String opponentId,
    required int generation,
    required Emitter<LiveViewerState> emit,
  }) async {
    await _disconnectBattleOpponent(invalidate: false);
    final result = await joinLiveUseCase(opponentId);
    if (_activeLiveId != liveId ||
        isClosed ||
        generation != _battleOperationGeneration) {
      return;
    }
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(moderationBanner: 'تعذر فتح فيديو الخصم'),
        );
        _scheduleBannerClear();
      },
      (join) async {
        if (generation != _battleOperationGeneration || isClosed) return;
        final supportersFuture = _loadTopGifterAvatars(opponentId);
        emit(state.copyWith(battleOpponentLive: join.live));
        try {
          await liveKitService.connectBattle(
            url: join.liveKitUrl,
            token: join.liveKitToken,
            roomName: opponentId,
            mediaHints: join.mediaHints,
          );
          _battleRoomRecoveryInFlight = false;
          if (_activeLiveId != liveId ||
              isClosed ||
              generation != _battleOperationGeneration) {
            return;
          }
          _battleOpponentLiveId = opponentId;
          final room = liveKitService.battleRoom;
          emit(
            state.copyWith(
              battle: battle,
              battleOpponentLive: join.live,
              battleRoom: room,
            ),
          );
          final opponentSupporters = await supportersFuture;
          if (_activeLiveId != liveId ||
              isClosed ||
              generation != _battleOperationGeneration) {
            return;
          }
          // A new state instance makes the PK renderer read battleRoom now;
          // track changes after that are driven by the Room notifier itself.
          emit(
            state.copyWith(
              battle: battle,
              battleOpponentLive: join.live,
              battleRoom: room,
              opponentTopGifterAvatars:
                  opponentSupporters ?? state.opponentTopGifterAvatars,
            ),
          );
        } catch (_) {
          // The opponent's video is one part of their side of the stage. Their
          // name, avatar and supporter ring are already fetched and must still
          // land: bailing here left the right-hand side of a battle blank even
          // though everything except the video had arrived.
          final opponentSupporters = await supportersFuture;
          if (isClosed ||
              _tearingDown ||
              _activeLiveId != liveId ||
              generation != _battleOperationGeneration) {
            return;
          }
          // Short and human. This used to interpolate the raw exception, which
          // put a wrapped SocketException — host, URI, query string and all —
          // across the middle of the live.
          emit(
            state.copyWith(
              battle: battle,
              battleOpponentLive: join.live,
              opponentTopGifterAvatars:
                  opponentSupporters ?? state.opponentTopGifterAvatars,
              moderationBanner: 'تعذر عرض فيديو الخصم',
            ),
          );
          _scheduleBannerClear();
        }
      },
    );
  }

  Future<void> _disconnectBattleOpponent({bool invalidate = true}) async {
    if (invalidate) _battleOperationGeneration++;
    _battleRoomRecoveryInFlight = false;
    final opponentId = _battleOpponentLiveId;
    _battleOpponentLiveId = null;
    if (!isClosed && state.battleRoom != null) {
      emit(state.copyWith(battleRoom: null));
    }
    try {
      await liveKitService.disconnectBattle();
    } catch (_) {}
    if (opponentId != null) {
      try {
        await leaveLiveUseCase(opponentId);
      } catch (_) {}
    }
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
    _tearingDown = true;
    _socketSub?.cancel();
    _socketSub = null;
    _giftComboSub?.cancel();
    _giftComboSub = null;
    _bannerClearTimer?.cancel();
    _joinSuccessClearTimer?.cancel();
    _battleSupportersRefreshTimer?.cancel();
    _battleSupportersRefreshTimer = null;
    _guestApprovalTimer?.cancel();
    _guestApprovalTimer = null;
    await _disconnectBattleOpponent();
    final id = _activeLiveId;
    _activeLiveId = null;
    if (id != null) {
      giftSocketService.leaveLive(id);
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
    _tearingDown = false;
    _recoveringMedia = false;
    _mediaRecoveryAttempt = 0;
    if (!silent && !isClosed) {
      emit(const LiveViewerState());
    }
  }

  @override
  Future<void> close() async {
    _tearingDown = true;
    _battleOperationGeneration++;
    _battleConnectKeys.clear();
    await _liveKitSub?.cancel();
    _liveKitSub = null;
    await _battleSub?.cancel();
    _battleSub = null;
    _socketSub?.cancel();
    _socketSub = null;
    _giftComboSub?.cancel();
    _giftComboSub = null;
    _bannerClearTimer?.cancel();
    _joinSuccessClearTimer?.cancel();
    _battleSupportersRefreshTimer?.cancel();
    _battleSupportersRefreshTimer = null;
    _guestApprovalTimer?.cancel();
    _guestApprovalTimer = null;
    await _disconnectBattleOpponent();
    final id = _activeLiveId;
    _activeLiveId = null;
    if (id != null) {
      giftSocketService.leaveLive(id);
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
