import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart' show ConnectionState;
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../../../core/network/live_api_client.dart';
import '../../../../../core/models/live_battle.dart';
import '../../../../../core/models/live_competition_request.dart';
import '../../../data/services/fake_livekit_service.dart';
import '../../../data/services/live_session_diagnostics.dart';
import '../../../data/services/live_viewer_media_preloader.dart';
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
import '../../../domain/usecases/pin_comment_usecase.dart';
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
    required this.pinCommentUseCase,
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
    on<LiveViewerCommentPinToggledRequested>(_onCommentPinToggledRequested);
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

    _liveKitSub = liveKitService.sessionStream.listen((update) {
      if (!isClosed) add(LiveViewerLiveKitStateChanged(update));
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
  final PinCommentUseCase pinCommentUseCase;
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
  StreamSubscription<LiveKitSessionUpdate>? _liveKitSub;
  StreamSubscription<LiveKitConnectionState>? _battleSub;

  /// The live the viewer is currently watching, once its session has started.
  String? _activeLiveId;

  /// The live the viewer *wants* to be watching.
  ///
  /// Set synchronously at the top of every activation, before any await, so a
  /// teardown request that arrives afterwards can tell whether it refers to
  /// the current intent or to a page that has already been replaced. This is
  /// the single source of truth for "is this async continuation still
  /// relevant"; [_activeLiveId] only follows it once the work has begun.
  String? _requestedLiveId;

  /// Incremented whenever the intended live changes. Async continuations
  /// captured before the change compare against it instead of against
  /// [_activeLiveId], which cannot distinguish A → B → A.
  int _sessionGeneration = 0;

  /// Serializes activation and teardown. Both are multi-step network
  /// operations against shared singletons (socket, LiveKit service), so
  /// interleaving them lets one live's teardown land on another live's setup.
  Future<void> _sessionQueue = Future<void>.value();

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

  /// The live whose session has actually started.
  String? get activeLiveId => _activeLiveId;

  /// The live the viewer is meant to be watching, known from the instant an
  /// activation is dispatched rather than once it has done any work. Callers
  /// deciding whether the on-screen room still exists must use this, not
  /// [activeLiveId], which lags by one network round trip.
  String? get requestedLiveId => _requestedLiveId;

  /// Runs [body] with exclusive ownership of the session.
  ///
  /// The BLoC event transformer is concurrent, so `Activated` and
  /// `Deactivated` handlers start as soon as their events arrive. The handler
  /// awaits this, which keeps its `Emitter` alive for the whole body while
  /// guaranteeing that no other session operation runs at the same time.
  Future<T> _runExclusive<T>(Future<T> Function() body) {
    final result = _sessionQueue.then<T>((_) => body());
    // A failed operation must not wedge the queue for the next live.
    _sessionQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  // ---------- Event handlers ----------

  Future<void> _onActivated(
    LiveViewerActivated event,
    Emitter<LiveViewerState> emit,
  ) async {
    final live = event.live;
    if (_requestedLiveId == live.id && _activeLiveId == live.id) {
      // Both the PageView and the room widget announce the visible page, and
      // an app resume announces it again. Re-running activation on a session
      // that is already the intended one would tear down a working room.
      return;
    }
    _requestedLiveId = live.id;
    final generation = ++_sessionGeneration;

    // Only the part that mutates shared singletons — the room, the socket, the
    // audio session — is exclusive. Chat history, coin balance, the guest
    // roster and the battle snapshot are per-session reads; holding the lock
    // across them would make the next swipe wait for the previous live's REST
    // enrichment before it could even start connecting.
    final joined = await _runExclusive(
      () => _startSession(live, generation, emit),
    );
    if (joined == null || generation != _sessionGeneration) return;
    await _enrichSession(
      live: live,
      result: joined,
      generation: generation,
      emit: emit,
    );
  }

  /// Brings up the room, the socket and the visible session state.
  ///
  /// Returns the join payload when the viewer is watching, or null when the
  /// activation ended in a terminal state or was superseded.
  Future<JoinLiveResult?> _startSession(
    LiveEntity live,
    int generation,
    Emitter<LiveViewerState> emit,
  ) async {
    {
      if (generation != _sessionGeneration) return null;

      // The LiveKit room is owned by the media service and replaced
      // atomically inside its own connect(); tearing it down here as well
      // would release and re-acquire the audio session and add the old
      // room's teardown to the critical path of the new join.
      await _teardown(silent: true, releaseMedia: false, emit: emit);
      if (generation != _sessionGeneration) return null;

      _activeLiveId = live.id;
      // The previous neighbour window is now worthless, and this live's poster
      // is what the viewer is about to look at.
      LiveViewerMediaPreloader.instance.cancelPending();
      unawaited(
        LiveViewerMediaPreloader.instance.prefetchLive(live, urgent: true),
      );

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
      debugPrint(
        '[LiveRoom] state=connecting liveId=${live.id}'
        ' gen=$generation source=viewer_activation',
      );

      if (live.status == LiveStatus.ended) {
        await _releaseMediaForFailedActivation();
        if (generation != _sessionGeneration) return null;
        emit(
          state.copyWith(
            session: state.session!.copyWith(
              connectionState: LiveConnectionState.liveEnded,
            ),
          ),
        );
        return null;
      }
      if (live.status == LiveStatus.banned) {
        await _releaseMediaForFailedActivation();
        if (generation != _sessionGeneration) return null;
        emit(
          state.copyWith(
            session: state.session!.copyWith(
              connectionState: LiveConnectionState.banned,
            ),
          ),
        );
        return null;
      }

      final joinResult = await joinLiveUseCase(live.id);
      if (generation != _sessionGeneration) return null;

      return joinResult.fold(
        (failure) async {
          await _releaseMediaForFailedActivation();
          if (generation != _sessionGeneration) return null;
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
          return null;
        },
        (result) async {
          try {
            debugPrint(
              '[LiveKit] join credentials present'
              ' liveId=${result.liveId}'
              ' urlPresent=${result.liveKitUrl.isNotEmpty}'
              ' tokenPresent=${result.liveKitToken.isNotEmpty}',
            );
            await liveKitService.connect(
              url: result.liveKitUrl,
              token: result.liveKitToken,
              roomName: result.liveId,
              mockStreamUrl: result.live.streamUrl,
              mediaHints: result.mediaHints,
            );
          } catch (error) {
            debugPrint(
              '[LiveKit] connect failed step=room.connect'
              ' errorType=${error.runtimeType}',
            );
            if (generation != _sessionGeneration) return null;
            emit(
              state.copyWith(
                session: state.session!.copyWith(
                  connectionState: LiveConnectionState.error,
                  errorMessage: 'Failed to connect to stream',
                ),
              ),
            );
            return null;
          }
          if (generation != _sessionGeneration) return null;

          final joinedAvatars = _avatarsFromLive(result.live);
          emit(
            state.copyWith(
              session: state.session!.copyWith(
                live: result.live.copyWith(
                  // Keep feed/detail metadata while retaining fields that are
                  // only present on the join payload, such as activeAuctions.
                  metadata: {...?live.metadata, ...?result.live.metadata},
                  isFollowing: live.isFollowing,
                ),
                connectionState: LiveConnectionState.connected,
                isLiveKitConnected: true,
                socketToken: result.socketToken,
                liveKitToken: result.liveKitToken,
                coinBalance: 0,
              ),
              showJoinSuccess: true,
              topViewerAvatars: joinedAvatars.isNotEmpty
                  ? joinedAvatars
                  : state.topViewerAvatars,
            ),
          );
          debugPrint(
            '[LiveRoom] state=connected liveId=${live.id}'
            ' liveKitConnected=true',
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
          return result;
        },
      );
    }
  }

  /// Loads everything the room shows around the video.
  ///
  /// Runs outside the session lock: none of it touches the room, the socket or
  /// the audio session, and all of it is discarded if the viewer has moved on.
  Future<void> _enrichSession({
    required LiveEntity live,
    required JoinLiveResult result,
    required int generation,
    required Emitter<LiveViewerState> emit,
  }) async {
    try {
      final results = await Future.wait<dynamic>([
        giftRepository.getCoinBalance(),
        commentRepository.getComments(liveId: live.id, limit: 20),
        _loadCurrentUserId(),
        guestRepository.listGuests(live.id),
        _loadTopGifterAvatars(live.id),
      ]);
      if (generation != _sessionGeneration || state.session == null) return;

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
            coinBalance: coins.getOrElse(() => 0),
          ),
          comments: comments,
          pinnedComment: pinned,
          currentUserId: _currentUserId,
          guests: guestsResult.fold((_) => state.guests, (items) => items),
          topViewerAvatars: topGifters ?? state.topViewerAvatars,
        ),
      );
    } catch (error) {
      debugPrint('[LiveRoom] session enrichment failed: $error');
    }
    if (generation != _sessionGeneration) return;
    await _refreshBattle(live.id, emit);
  }

  /// Closes the media room after an activation that never reached
  /// `liveKitService.connect()`.
  ///
  /// Activation deliberately leaves the previous room running so the new join
  /// is not delayed by its teardown, on the assumption that connect() will
  /// replace it. When the join never happens — ended live, banned viewer,
  /// failed join request — that assumption no longer holds and the previous
  /// live would keep playing underneath the error.
  Future<void> _releaseMediaForFailedActivation() async {
    try {
      await liveKitService.disconnect();
    } catch (error) {
      debugPrint('[LiveKit] release after failed activation: $error');
    }
  }

  Future<void> _onDeactivated(
    LiveViewerDeactivated event,
    Emitter<LiveViewerState> emit,
  ) async {
    // A page being disposed during a swipe emits this for the live it was
    // showing, which by then is no longer the one the viewer wants. Honouring
    // it would close the room the incoming page just opened.
    final target = event.liveId;
    if (target != null && target != _requestedLiveId) {
      debugPrint(
        '[LiveRoom] ignored stale deactivate liveId=$target'
        ' requested=$_requestedLiveId',
      );
      return;
    }
    _requestedLiveId = null;
    final generation = ++_sessionGeneration;
    await _runExclusive(() async {
      if (generation != _sessionGeneration) return;
      await _teardown(silent: false, releaseMedia: true, emit: emit);
    });
  }

  Future<void> _onRetryRequested(
    LiveViewerRetryRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final live = state.live;
    if (live == null) return;
    _mediaRecoveryAttempt = 0;
    _activeLiveId = null;
    _requestedLiveId = null;
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

  Future<void> _onCommentPinToggledRequested(
    LiveViewerCommentPinToggledRequested event,
    Emitter<LiveViewerState> emit,
  ) async {
    final liveId = _activeLiveId;
    if (liveId == null) return;
    final originalComments = List<CommentEntity>.from(state.comments);
    CommentEntity? comment;
    for (final item in state.comments) {
      if (item.id == event.commentId) {
        comment = item;
        break;
      }
    }
    if (comment == null) return;
    final updated = comment.copyWith(isPinned: event.pinned);
    final nextComments = state.comments
        .map(
          (item) => event.pinned
              ? (item.id == event.commentId
                    ? updated
                    : item.copyWith(isPinned: false))
              : (item.id == event.commentId ? updated : item),
        )
        .toList(growable: false);
    emit(
      state.copyWith(
        comments: nextComments,
        pinnedComment: event.pinned ? updated : null,
        clearPinnedComment: !event.pinned,
      ),
    );
    final result = await pinCommentUseCase(
      liveId: liveId,
      commentId: event.commentId,
      pinned: event.pinned,
    );
    await result.fold((failure) async {
      emit(
        state.copyWith(
          comments: originalComments,
          pinnedComment: _firstPinnedComment(originalComments),
          clearPinnedComment: !originalComments.any((item) => item.isPinned),
          moderationBanner:
              'Failed to update pinned comment: ${failure.message}',
        ),
      );
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

    final update = event.update;
    debugPrint(
      '[LiveRoom] LiveKit event=${event.state.name}'
      ' blocState=${session.connectionState.name}'
      ' liveId=$liveId'
      ' mediaGen=${update.generation}'
      '${update.cause == null ? '' : ' cause=${update.cause!.name}'}'
      '${update.detail == null ? '' : ' detail=${update.detail}'}',
    );

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
        // The service emits this at the start of the connect the BLoC itself
        // just requested. Only a room that had already reached `connected`
        // going back to `connecting` is worth surfacing.
        if (session.connectionState != LiveConnectionState.connected) return;
        emit(
          state.copyWith(
            session: session.copyWith(
              connectionState: LiveConnectionState.reconnecting,
              isLiveKitConnected: false,
            ),
          ),
        );
        return;
      case LiveKitConnectionState.reconnecting:
        // LiveKit's own reconnect keeps the Room, its participants and its
        // subscriptions. Show the state and let the SDK finish; a manual
        // rebuild here would throw away a session that is about to resume.
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
        await _handleMediaDisconnect(
          liveId: liveId,
          session: session,
          cause: update.cause ?? LiveKitDisconnectCause.unknown,
          emit: emit,
        );
        return;
    }
  }

  /// Decides what a dead room means for the viewer.
  ///
  /// The three groups need opposite responses and conflating them is what
  /// made the viewer both retry rooms that would never come back and give up
  /// on rooms that only needed a fresh token.
  Future<void> _handleMediaDisconnect({
    required String liveId,
    required LiveSessionEntity session,
    required LiveKitDisconnectCause cause,
    required Emitter<LiveViewerState> emit,
  }) async {
    if (cause == LiveKitDisconnectCause.clientInitiated) return;

    if (cause == LiveKitDisconnectCause.roomClosed) {
      emit(
        state.copyWith(
          session: session.copyWith(
            connectionState: LiveConnectionState.liveEnded,
            isLiveKitConnected: false,
          ),
        ),
      );
      return;
    }

    if (cause == LiveKitDisconnectCause.duplicateIdentity) {
      emit(
        state.copyWith(
          session: session.copyWith(
            connectionState: LiveConnectionState.error,
            isLiveKitConnected: false,
            errorMessage:
                'تم فتح هذا البث على جهاز آخر. أغلقه ثم أعد المحاولة هنا.',
          ),
        ),
      );
      return;
    }

    if (_recoveringMedia) return;
    emit(
      state.copyWith(
        session: session.copyWith(
          connectionState: LiveConnectionState.reconnecting,
          isLiveKitConnected: false,
        ),
      ),
    );
    await _recoverMedia(liveId, emit);
  }

  /// Backoff schedule for rebuilding a dead room.
  ///
  /// The first attempt is immediate because the common case — a token that
  /// aged out, a signalling socket the OS killed on resume — succeeds at once
  /// and any wait is UX the viewer pays for nothing. Subsequent attempts back
  /// off so a server-side outage cannot turn a feed full of viewers into a
  /// retry storm. Five attempts spans ~15s, after which a human being told
  /// "tap to retry" is better than an indefinite spinner.
  static const _mediaRecoveryBackoff = <Duration>[
    Duration.zero,
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  /// A terminal LiveKit disconnect cannot safely reuse its old JWT (tokens
  /// expire and ICE restarts can outlive them). Re-join REST to obtain fresh
  /// subscribe credentials, or a fresh publish token when this viewer is on
  /// the guest stage, then rebuild the Room with bounded backoff.
  Future<void> _recoverMedia(
    String liveId,
    Emitter<LiveViewerState> emit,
  ) async {
    if (_recoveringMedia || _tearingDown || _activeLiveId != liveId) return;
    final generation = _sessionGeneration;
    _recoveringMedia = true;
    try {
      for (
        var attempt = 1;
        attempt <= _mediaRecoveryBackoff.length;
        attempt++
      ) {
        if (_tearingDown || isClosed || generation != _sessionGeneration) {
          return;
        }
        _mediaRecoveryAttempt = attempt;
        final backoff = _mediaRecoveryBackoff[attempt - 1];
        if (backoff > Duration.zero) {
          await Future<void>.delayed(backoff);
        }
        if (_tearingDown || isClosed || generation != _sessionGeneration) {
          return;
        }

        try {
          if (state.isOnStage) {
            final credentials = await guestRepository.refreshStageCredentials(
              liveId,
            );
            final creds = credentials.fold<GuestStageCredentials?>(
              (_) => null,
              (value) => value,
            );
            // Fetching credentials is a network round trip, and the viewer can
            // swipe during it. Without this check the recovery would rebuild
            // the room it was asked to abandon, on top of the new one.
            if (generation != _sessionGeneration) return;
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
            if (generation != _sessionGeneration) return;
            if (result == null) continue;
            await liveKitService.connect(
              url: result.liveKitUrl,
              token: result.liveKitToken,
              roomName: result.liveId,
              mockStreamUrl: result.live.streamUrl,
              mediaHints: result.mediaHints,
            );
          }
          if (isClosed || generation != _sessionGeneration) return;
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
          debugPrint(
            '[VIDEO-DIAG] media recovered liveId=$liveId attempt=$attempt',
          );
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
      if (current != null && !isClosed && generation == _sessionGeneration) {
        debugPrint(
          '[VIDEO-DIAG] media recovery exhausted liveId=$liveId'
          ' attempts=${_mediaRecoveryBackoff.length}',
        );
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

  CommentEntity? _firstPinnedComment(Iterable<CommentEntity> comments) {
    for (final comment in comments) {
      if (comment.isPinned) return comment;
    }
    return null;
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
      final avatars = result.fold<List<String>?>(
        (_) => null,
        (entries) => entries
            .map((entry) => entry.avatarUrl?.trim())
            .whereType<String>()
            .where((url) => url.isNotEmpty)
            .take(3)
            .toList(growable: false),
      );
      if (avatars != null) {
        unawaited(LiveViewerMediaPreloader.instance.prefetchUrls(avatars));
      }
      return avatars;
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
        !battle.isActive ||
        (roomNeedsReplacement && !connectionAlreadyInFlight);
    final operationGeneration = startsMediaOperation
        ? ++_battleOperationGeneration
        : _battleOperationGeneration;

    emit(
      state.copyWith(
        battle: battle,
        clearBattleOpponent: battleIdentityChanged,
        battleRoom: roomNeedsReplacement ? null : currentBattleRoom,
        pkScoreLeft: battle.scoreFor(liveId),
        pkScoreRight: battle.opponentScoreFor(liveId),
      ),
    );
    if (!battle.isActive) {
      await _disconnectBattleOpponent(invalidate: false);
      if (isClosed ||
          _tearingDown ||
          operationGeneration != _battleOperationGeneration) {
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
    if (isClosed ||
        _tearingDown ||
        _activeLiveId == null ||
        state.battle?.isActive != true) {
      return;
    }
    switch (event.state) {
      case LiveKitConnectionState.disconnected:
      case LiveKitConnectionState.failed:
        if (event.state == LiveKitConnectionState.disconnected &&
            _battleConnectKeys.isEmpty) {
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
        emit(state.copyWith(moderationBanner: 'تعذر فتح فيديو الخصم'));
        _scheduleBannerClear();
      },
      (join) async {
        if (generation != _battleOperationGeneration || isClosed) return;
        final supportersFuture = _loadTopGifterAvatars(opponentId);
        final mediaFuture = LiveViewerMediaPreloader.instance.prefetchLive(
          join.live,
        );
        try {
          await Future.wait<void>([
            liveKitService.connectBattle(
              url: join.liveKitUrl,
              token: join.liveKitToken,
              roomName: opponentId,
              mediaHints: join.mediaHints,
            ),
            mediaFuture,
          ]);
          _battleRoomRecoveryInFlight = false;
          if (_activeLiveId != liveId ||
              isClosed ||
              generation != _battleOperationGeneration) {
            return;
          }
          _battleOpponentLiveId = opponentId;
          final room = liveKitService.battleRoom;
          final opponentSupporters = await supportersFuture;
          if (_activeLiveId != liveId ||
              isClosed ||
              generation != _battleOperationGeneration) {
            return;
          }
          await LiveViewerMediaPreloader.instance.prefetchUrls(
            opponentSupporters ?? const <String>[],
          );
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
          await mediaFuture;
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
    final fullName = userMap?['fullName']?.toString();
    final handle = userMap?['username']?.toString();
    return CommentEntity(
      id: map['id']?.toString() ?? 'pinned',
      liveId: live.id,
      userId: userMap?['id']?.toString() ?? map['userId']?.toString() ?? '',
      username: (fullName != null && fullName.trim().isNotEmpty)
          ? fullName.trim()
          : (handle ?? 'User'),
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

  /// Ends the current session's non-media resources, and optionally its room.
  ///
  /// [releaseMedia] is false when a new live is being activated: that
  /// activation's `liveKitService.connect()` replaces the room atomically, so
  /// closing it here would only add a full audio-session release plus a
  /// socket teardown to the critical path of the join the viewer is waiting
  /// for. It is true whenever no new room is coming.
  Future<void> _teardown({
    required bool silent,
    required bool releaseMedia,
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
      // A viewer-count decrement. Nothing in the next session depends on its
      // response, and awaiting it puts a REST round trip between the viewer's
      // swipe and the new room's connect.
      unawaited(leaveLiveUseCase(id).then<void>((_) {}, onError: (_, _) {}));
    }
    try {
      await socketService.disconnect();
    } catch (_) {}
    if (releaseMedia) {
      try {
        await liveKitService.disconnect();
      } catch (_) {}
    }
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
