import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/live_gift_sheet.dart';
import '../../../../core/utils/app_media_cache_manager.dart';
import '../../../../core/utils/build_safe_notifier.dart';
import '../../../../core/widgets/safe_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../domain/repositories/guest_repository.dart';
import '../bloc/live_viewer/live_viewer_bloc.dart';
import '../bloc/live_viewer/live_viewer_event.dart';
import '../bloc/live_viewer/live_viewer_state.dart';
import '../bloc/live_detail/live_detail_bloc.dart';
import '../di/live_viewer_injector.dart' as di;
import '../../../live/domain/repositories/live_interactive_repository.dart';
import '../../../live/domain/usecases/live_interactive_usecases.dart';
import '../../../live/presentation/bloc/live_interactive/live_interactive_bloc.dart';
import '../../../live/presentation/bloc/live_interactive/live_interactive_event.dart';
import '../../../live/presentation/widgets/room/live_interactive_host_toolbar.dart';
import 'live_interactive_viewer_panel.dart';
import 'comment_input_bar.dart';
import 'comments_section.dart';
import 'fallback_media.dart';
import 'fan_club_widgets.dart';
import 'floating_gifts.dart';
import 'floating_hearts.dart';
import 'gift_goal_card.dart';
import '../../data/services/fake_livekit_service.dart' show LiveKitService;
import '../../data/services/fake_socket_service.dart' show SocketService;
import 'guest_panel.dart';
import 'viewer_stage.dart';
import 'guest_stage_prompt.dart';
import 'league_overlay.dart';
import 'live_state_overlay.dart';
import 'live_video_player.dart';
import 'multi_guest_grid.dart';
import 'ranking_sheet.dart';
import 'tiktok_live_chrome.dart';
import 'tiktok_live_tokens.dart';

class LiveRoomPage extends StatefulWidget {
  final LiveEntity live;
  final bool isActive;
  final VoidCallback? onClose;

  const LiveRoomPage({
    super.key,
    required this.live,
    required this.isActive,
    this.onClose,
  });

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  bool _showComposer = false;
  bool _showLiveFeatures = false;
  bool _giftGoalDismissed = false;
  final List<FloatingHeart> _tapHearts = [];
  final Set<String> _preloadedImageUrls = <String>{};
  LiveInteractiveBloc? _interactiveBloc;
  LiveDetailBloc? _detailBloc;

  /// Captured while the element is still mounted so [dispose] never has to
  /// walk the widget tree.
  LiveViewerBloc? _viewerBloc;

  @override
  void initState() {
    super.initState();
    _scheduleActivate();
    _interactiveBloc = LiveInteractiveBloc(
      useCases: LiveInteractiveUseCases(di.sl<LiveInteractiveRepository>()),
      socketEvents: di.sl<SocketService>().events,
      liveId: widget.live.id,
    );
    _detailBloc = di.sl<LiveDetailBloc>();
    if (widget.isActive) {
      _scheduleInteractive();
    }
    _scheduleImagePreload(<String?>[
      widget.live.hostAvatar,
      widget.live.thumbnailUrl,
    ]);
  }

  @override
  void didUpdateWidget(covariant LiveRoomPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live.id != widget.live.id) {
      _showLiveFeatures = false;
      _interactiveBloc?.close();
      _interactiveBloc = LiveInteractiveBloc(
        useCases: LiveInteractiveUseCases(di.sl<LiveInteractiveRepository>()),
        socketEvents: di.sl<SocketService>().events,
        liveId: widget.live.id,
      );
      _detailBloc?.close();
      _detailBloc = di.sl<LiveDetailBloc>();
      _scheduleActivate();
      _scheduleInteractive();
    } else if (widget.isActive && !oldWidget.isActive) {
      _scheduleActivate();
      _scheduleInteractive();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewerBloc = context.read<LiveViewerBloc>();
  }

  @override
  void dispose() {
    _deactivateIfThis();
    _interactiveBloc?.close();
    _detailBloc?.close();
    super.dispose();
  }

  /// A PageView disposes pages that fall out of its cache window, which during
  /// a swipe happens *after* the incoming page has already started its own
  /// session. Naming the live makes the BLoC drop this request unless it is
  /// still the one the viewer wants, so leaving the feed tears the room down
  /// while swiping past does not.
  void _deactivateIfThis() {
    final viewerBloc = _viewerBloc;
    if (viewerBloc == null || viewerBloc.isClosed) return;
    viewerBloc.add(LiveViewerDeactivated(liveId: widget.live.id));
  }

  void _scheduleActivate() {
    // PageView keeps neighbouring TikTok-style pages mounted. An off-screen
    // page must never replace the one LiveKit room owned by the visible page.
    if (!widget.isActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      debugPrint('[ViewerLive] open liveId=${widget.live.id}');
      // GET /lives/:id is optional detail enrichment. The feed already has a
      // valid join candidate, so detail latency must not block LiveKit media.
      context.read<LiveViewerBloc>().add(LiveViewerActivated(widget.live));
      _detailBloc?.add(LiveDetailRequested(widget.live.id));
    });
  }

  void _scheduleImagePreload(Iterable<String?> urls) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final screenWidth = MediaQuery.sizeOf(context).width;
      for (final raw in urls) {
        final url = raw?.trim() ?? '';
        if (url.isEmpty || !_preloadedImageUrls.add(url)) continue;
        unawaited(
          precacheSafeNetworkImage(
            context,
            url,
            width: screenWidth,
          ).catchError((_) {}),
        );
      }
    });
  }

  void _spawnHearts(int count) {
    for (var i = 0; i < count; i++) {
      Future.delayed(Duration(milliseconds: i * 70), () {
        if (!mounted) return;
        late FloatingHeart heart;
        heart = FloatingHeart(
          key: UniqueKey(),
          startRight: 20,
          startBottom: 118 + MediaQuery.paddingOf(context).bottom,
          onComplete: () {
            if (!mounted) return;
            setState(() => _tapHearts.remove(heart));
          },
        );
        setState(() => _tapHearts.add(heart));
      });
    }
  }

  void _openGifts() {
    final viewerState = context.read<LiveViewerBloc>().state;
    final canSendToHost =
        viewerState.currentUserId == null ||
        viewerState.currentUserId != widget.live.hostId;
    LiveGiftSheet.show(
      context,
      liveId: widget.live.id,
      receiverId: widget.live.hostId,
      canSendToHost: canSendToHost,
      onGiftSent: (_) {
        if (!mounted) return;
        context.read<LiveViewerBloc>().add(
          const LiveViewerGiftBalanceRefreshRequested(),
        );
      },
    );
  }

  void _sendRose() {
    _openGifts();
  }

  Future<void> _openGuestRequest(LiveEntity live) async {
    final bloc = context.read<LiveViewerBloc>();
    final requested = await showGuestRequestSheet(
      context,
      hostName: live.hostName,
      hostAvatar: live.hostAvatar,
      viewerAvatar: 'https://i.pravatar.cc/150?u=me',
    );
    if (requested != true) return;
    // Real request now (`POST /lives/:id/guests/request`) — this used to stop
    // at a SnackBar, so the host never saw anyone asking to come on stage.
    bloc.add(const LiveViewerGuestSeatRequested());
  }

  void _openRanking(LiveEntity live) {
    showHourlyRankingSheet(
      context,
      liveId: live.id,
      hostName: live.hostName,
      hostAvatar: live.hostAvatar,
      onJoinFanClub: () {
        unawaited(_joinFanClub(live.hostId));
      },
    );
  }

  void _scheduleInteractive() {
    if (!widget.isActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      _interactiveBloc?.add(
        LiveInteractiveStarted(widget.live.id, userId: widget.live.hostId),
      );
    });
  }

  Future<void> _openLeague(LiveEntity live) async {
    try {
      final repository = di.sl<LiveInteractiveRepository>();
      final rawEntries = await repository.getGlobalHourlyLeaderboard();
      final entries = rawEntries
          .map((entry) {
            final user = (entry.live['user'] as Map?)?.cast<String, dynamic>();
            final userId =
                user?['id']?.toString() ??
                entry.live['userId']?.toString() ??
                entry.live['id']?.toString() ??
                '';
            return RankingEntry(
              rank: entry.rank,
              userId: userId,
              username:
                  user?['username']?.toString() ??
                  user?['fullName']?.toString() ??
                  'Creator',
              avatarUrl: user?['avatarUrl']?.toString(),
              score: entry.score,
              isLive: true,
            );
          })
          .where((entry) => entry.userId.isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No league data is available yet.')),
        );
        return;
      }
      final matchingHostEntries = entries.where(
        (entry) => entry.userId == live.hostId,
      );
      final hostEntry = matchingHostEntries.isEmpty
          ? null
          : matchingHostEntries.first;
      final hostLeague = await repository.getHostLeague(live.hostId);
      if (!mounted) return;
      final myEntry =
          hostEntry ??
          RankingEntry(
            rank: 0,
            userId: live.hostId,
            username: live.hostName,
            avatarUrl: live.hostAvatar,
            score: hostLeague.totalLiveEarnedCoins,
            isLive: true,
          );
      showLeagueMatchOverlay(
        context,
        entries: entries,
        myEntry: myEntry,
        pointsToNext: hostLeague.nextTier == null
            ? 0
            : hostLeague.progressPercentage.toInt(),
        onSendGift: _openGifts,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('League unavailable: $error')));
    }
  }

  Future<void> _joinFanClub(String creatorId) async {
    try {
      final repository = di.sl<LiveInteractiveRepository>();
      final status = await repository.getFanClub(creatorId);
      if (!status.enabled) {
        throw StateError('This creator has not enabled a fan club.');
      }
      if (!status.isMember) await repository.subscribeFanClub(creatorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.isMember
                ? 'Already a fan club member'
                : 'Joined ${status.name ?? 'Fan Club'}',
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fan club unavailable: $error')));
    }
  }

  /// Stage slots for the grid. The live roster from `GET /lives/:id/guests`
  /// wins whenever the server has one; `metadata.guests` stays as the fallback
  /// for rooms the guest API has nothing to say about.
  List<GuestSlotData> _guestsFrom(LiveEntity live, List<GuestSummary> roster) {
    if (roster.isNotEmpty) {
      return roster
          .map(
            (g) => GuestSlotData(
              userId: g.userId,
              name: g.displayName,
              avatarUrl: g.avatarUrl,
              isMuted: g.mutedByHost,
            ),
          )
          .toList(growable: false);
    }
    final raw = live.metadata?['guests'];
    if (raw is! List) return const [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return GuestSlotData(
        userId: m['id'] as String?,
        name: m['name'] as String?,
        avatarUrl: m['avatar'] as String?,
        level: m['level'] as int?,
        isMuted: m['muted'] == true,
      );
    }).toList();
  }

  List<String> _moderatorIdsFrom(LiveEntity live) {
    final raw = live.metadata?['moderators'];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  Widget _buildCommentsSection({
    required BuildContext context,
    required LiveViewerState state,
    required LiveEntity live,
    required double height,
    bool alignTop = false,
    bool highContrast = false,
  }) {
    final moderators = _moderatorIdsFrom(live);
    final bloc = context.read<LiveViewerBloc>();
    return CommentsSection(
      comments: state.comments,
      height: height,
      alignTop: alignTop,
      highContrast: highContrast,
      currentUserId: state.currentUserId,
      hostId: live.hostId,
      moderatorIds: moderators,
      mutedUserIds: state.mutedUserIds,
      bannedUserIds: state.bannedUserIds,
      onDeleteComment: (commentId, targetUserId) {
        bloc.add(
          LiveViewerCommentDeletedRequested(
            commentId,
            targetUserId: targetUserId,
          ),
        );
      },
      onPinComment: (commentId, pinned) {
        bloc.add(
          LiveViewerCommentPinToggledRequested(commentId, pinned: pinned),
        );
      },
      onMuteUser: (userId, username, reason) {
        bloc.add(
          LiveViewerViewerChatMuteRequested(
            userId,
            username: username,
            reason: reason,
          ),
        );
      },
      onUnmuteUser: (userId, username) {
        bloc.add(
          LiveViewerViewerChatUnmuteRequested(userId, username: username),
        );
      },
      onBanUser: (userId, username, reason) {
        bloc.add(
          LiveViewerViewerBannedRequested(
            userId,
            username: username,
            reason: reason,
          ),
        );
      },
      onUnbanUser: (userId, username) {
        bloc.add(LiveViewerViewerUnbannedRequested(userId, username: username));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LiveInteractiveBloc>.value(value: _interactiveBloc!),
        BlocProvider<LiveDetailBloc>.value(value: _detailBloc!),
      ],
      child: BlocListener<LiveDetailBloc, LiveDetailState>(
        listenWhen: (previous, current) =>
            previous.live != current.live || previous.error != current.error,
        listener: (context, state) {
          if (!widget.isActive) return;
          final live = state.live;
          if (live != null &&
              live.id.isNotEmpty &&
              live.id == widget.live.id) {
            context.read<LiveViewerBloc>().add(LiveViewerActivated(live));
          }
        },
        child: BlocConsumer<LiveViewerBloc, LiveViewerState>(
          listenWhen: (previous, current) =>
              previous.battleOpponentLive != current.battleOpponentLive ||
              previous.topViewerAvatars != current.topViewerAvatars ||
              previous.opponentTopGifterAvatars !=
                  current.opponentTopGifterAvatars,
          listener: (context, state) {
            _scheduleImagePreload(<String?>[
              state.battleOpponentLive?.hostAvatar,
              state.battleOpponentLive?.thumbnailUrl,
              ...state.topViewerAvatars,
              ...state.opponentTopGifterAvatars,
            ]);
          },
          buildWhen: (prev, curr) {
            final prevLive = prev.live;
            final currLive = curr.live;
            final prevInfo = prevLive == null
                ? null
                : (
                    prevLive.id,
                    prevLive.hostId,
                    prevLive.hostName,
                    prevLive.hostAvatar,
                    prevLive.title,
                    prevLive.description,
                    prevLive.thumbnailUrl,
                    prevLive.streamUrl,
                    prevLive.category,
                    prevLive.status,
                    prevLive.startTime,
                    prevLive.endTime,
                    prevLive.isLive,
                    prevLive.isFollowing,
                    prevLive.metadata,
                  );
            final currInfo = currLive == null
                ? null
                : (
                    currLive.id,
                    currLive.hostId,
                    currLive.hostName,
                    currLive.hostAvatar,
                    currLive.title,
                    currLive.description,
                    currLive.thumbnailUrl,
                    currLive.streamUrl,
                    currLive.category,
                    currLive.status,
                    currLive.startTime,
                    currLive.endTime,
                    currLive.isLive,
                    currLive.isFollowing,
                    currLive.metadata,
                  );
            return prev.connectionState != curr.connectionState ||
                (prev.live?.id) != (curr.live?.id) ||
                prev.guests != curr.guests ||
                prev.isOnStage != curr.isOnStage ||
                prev.battle != curr.battle ||
                prev.battleOpponentLive != curr.battleOpponentLive ||
                prev.battleRoom != curr.battleRoom ||
                prev.topViewerAvatars != curr.topViewerAvatars ||
                prev.opponentTopGifterAvatars !=
                    curr.opponentTopGifterAvatars ||
                prevInfo != currInfo;
          },
          builder: (context, state) {
            final connectionState = state.connectionState;
            final activeLiveId = state.live?.id;
            final isThisRoom = activeLiveId == widget.live.id;
            LiveEntity live;
            if (isThisRoom && state.live != null) {
              final l = state.live!;
              live = LiveEntity(
                id: l.id,
                hostId: l.hostId,
                hostName: l.hostName,
                hostAvatar: l.hostAvatar,
                title: l.title,
                description: l.description,
                thumbnailUrl: l.thumbnailUrl,
                streamUrl: l.streamUrl,
                category: l.category,
                status: l.status,
                startTime: l.startTime,
                endTime: l.endTime,
                isLive: l.isLive,
                isFollowing: l.isFollowing,
                metadata: l.metadata,
                viewerCount: 0,
                likeCount: 0,
              );
            } else {
              live = widget.live;
            }
            final connected =
                isThisRoom &&
                (connectionState == LiveConnectionState.connected ||
                    connectionState == LiveConnectionState.reconnecting);
            debugPrint(
              '[LiveRoom] liveId=${widget.live.id}'
              ' state=${connectionState.name}'
              ' isThisRoom=$isThisRoom'
              ' active=${widget.isActive}'
              ' liveKitUsable=$connected'
              ' overlayExpected=${widget.isActive && isThisRoom && !(connectionState == LiveConnectionState.connected || connectionState == LiveConnectionState.idle || connectionState == LiveConnectionState.reconnecting || connectionState == LiveConnectionState.networkLost)}'
              ' stack=media,gradients,chrome,comments,gifts,overlay,interactivePanel',
            );
            final isPk = isThisRoom
                ? state.isPk
                : live.metadata?['isPk'] == true;
            final stageGuests = isThisRoom
                ? state.activeGuests
                : const <GuestSummary>[];
            final hasLiveGuests = stageGuests.isNotEmpty;
            final isMultiGrid =
                live.metadata?['isMultiGrid'] == true ||
                (hasLiveGuests && !isPk);
            final isMultiGuest =
                live.metadata?['isMultiGuest'] == true || hasLiveGuests;
            final showFanClub =
                !isPk && !isMultiGrid && live.metadata?['showFanClub'] != false;
            final giftGoalTarget =
                (live.metadata?['giftGoalTarget'] as num?)?.toInt() ?? 0;
            final showGiftGoal =
                !isPk &&
                !_giftGoalDismissed &&
                live.metadata?['showGiftGoal'] == true &&
                giftGoalTarget > 0;
            final bottomPad = MediaQuery.paddingOf(context).bottom;
            final viewBottomPad = MediaQuery.viewPaddingOf(context).bottom;
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final guests = _guestsFrom(live, stageGuests);
            final barTotalH = 42 + 8 + (bottomPad < 16 ? 16.0 : bottomPad);
            final canvasBarTotalH =
                42 + 8 + (viewBottomPad < 16 ? 16.0 : viewBottomPad);
            final giftGoalH = showGiftGoal ? (isMultiGrid ? 112.0 : 96.0) : 0.0;
            final screenW = MediaQuery.sizeOf(context).width;
            final screenH = MediaQuery.sizeOf(context).height;
            final pkVideoH = screenW / TikTokLiveTokens.pkVideoAspect;
            final chromeGap = isMultiGrid
                ? TikTokLiveTokens.multiGridChromeGap
                : TikTokLiveTokens.badgeGapBelow;
            final headerBottom =
                MediaQuery.paddingOf(context).top +
                TikTokLiveTokens.topChromeBodyH +
                chromeGap;
            final contentBottom = canvasBarTotalH + giftGoalH + 8;

            return GestureDetector(
              onDoubleTap: () {
                _spawnHearts(5);
                context.read<LiveViewerBloc>().add(
                  const LiveViewerLiked(burst: 5),
                );
              },
              onTap: () {
                if (_showComposer) {
                  FocusScope.of(context).unfocus();
                  setState(() => _showComposer = false);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isPk)
                    Positioned(
                      top: headerBottom,
                      left: 0,
                      right: 0,
                      bottom: contentBottom,
                      child: Column(
                        children: [
                          SizedBox(
                            height: pkVideoH,
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _PkVideoLayout(
                                  live: live,
                                  opponentLive: state.battleOpponentLive,
                                  isActive: widget.isActive && isThisRoom,
                                  battleRoom: isThisRoom
                                      ? state.battleRoom
                                      : null,
                                ),
                                if (isThisRoom)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child:
                                        BlocBuilder<
                                          LiveViewerBloc,
                                          LiveViewerState
                                        >(
                                          buildWhen: (prev, curr) =>
                                              prev.pkScoreLeft !=
                                                  curr.pkScoreLeft ||
                                              prev.pkScoreRight !=
                                                  curr.pkScoreRight ||
                                              prev.battle != curr.battle,
                                          builder: (context, state) {
                                            return Stack(
                                              alignment: Alignment.topCenter,
                                              clipBehavior: Clip.none,
                                              children: [
                                                PkBattleBar(
                                                  scoreLeft: state.pkScoreLeft,
                                                  scoreRight:
                                                      state.pkScoreRight,
                                                ),
                                                Positioned(
                                                  top: 22,
                                                  child: _PkBattleTimer(
                                                    endTime:
                                                        state.battle?.endTime,
                                                    multiplier:
                                                        state
                                                            .battle
                                                            ?.multiplier ??
                                                        1,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _PkContributors(
                                    avatars: isThisRoom
                                        ? state.topViewerAvatars
                                        : (live.metadata?['pkContributorsLeft']
                                                      as List?)
                                                  ?.map(
                                                    (item) => item.toString(),
                                                  )
                                                  .toList() ??
                                              const <String>[],
                                    isLeft: true,
                                  ),
                                ),
                                Expanded(
                                  child: _PkContributors(
                                    avatars: isThisRoom
                                        ? state.opponentTopGifterAvatars
                                        : (live.metadata?['pkContributorsRight']
                                                      as List?)
                                                  ?.map(
                                                    (item) => item.toString(),
                                                  )
                                                  .toList() ??
                                              const <String>[],
                                    isLeft: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.isActive && isThisRoom)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  4,
                                  54,
                                  0,
                                ),
                                child:
                                    BlocBuilder<
                                      LiveViewerBloc,
                                      LiveViewerState
                                    >(
                                      buildWhen: (prev, curr) =>
                                          prev.comments != curr.comments ||
                                          prev.pinnedComment !=
                                              curr.pinnedComment,
                                      builder: (context, state) {
                                        final pinned = state.pinnedComment;
                                        return LayoutBuilder(
                                          builder: (context, constraints) {
                                            final pinH = pinned == null
                                                ? 0.0
                                                : 50.0;
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (pinned != null) ...[
                                                  PinnedCommentBar(
                                                    comment: pinned,
                                                  ),
                                                  const SizedBox(height: 6),
                                                ],
                                                _buildCommentsSection(
                                                  context: context,
                                                  state: state,
                                                  live: live,
                                                  height:
                                                      (constraints.maxHeight -
                                                              pinH)
                                                          .clamp(
                                                            40.0,
                                                            constraints
                                                                .maxHeight,
                                                          ),
                                                  alignTop: false,
                                                  highContrast: true,
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                              ),
                            )
                          else
                            const Spacer(),
                        ],
                      ),
                    )
                  else if (isMultiGrid)
                    Positioned(
                      top: headerBottom,
                      left: 0,
                      right: 0,
                      bottom: contentBottom,
                      child: Column(
                        children: [
                          if (hasLiveGuests)
                            ViewerStage(
                              live: live,
                              guests: stageGuests,
                              liveKit: di.sl<LiveKitService>(),
                              isSelfOnStage: state.isOnStage,
                              currentUserId: state.currentUserId,
                              maxHeight: math.max(
                                180,
                                screenH - headerBottom - contentBottom - 112,
                              ),
                            )
                          else
                            MultiGuestGrid(
                              live: live,
                              isActive: widget.isActive && connected,
                              guests: guests,
                              onRequestTap: () => _openGuestRequest(live),
                            ),
                          if (widget.isActive && isThisRoom)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  2,
                                  16,
                                  0,
                                ),
                                child:
                                    BlocBuilder<
                                      LiveViewerBloc,
                                      LiveViewerState
                                    >(
                                      buildWhen: (prev, curr) =>
                                          prev.comments != curr.comments ||
                                          prev.pinnedComment !=
                                              curr.pinnedComment,
                                      builder: (context, state) {
                                        final pinned = state.pinnedComment;
                                        return LayoutBuilder(
                                          builder: (context, constraints) {
                                            final pinH = pinned == null
                                                ? 0.0
                                                : 50.0;
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (pinned != null) ...[
                                                  PinnedCommentBar(
                                                    comment: pinned,
                                                  ),
                                                  const SizedBox(height: 6),
                                                ],
                                                _buildCommentsSection(
                                                  context: context,
                                                  state: state,
                                                  live: live,
                                                  height:
                                                      (constraints.maxHeight -
                                                              pinH)
                                                          .clamp(
                                                            40.0,
                                                            constraints
                                                                .maxHeight,
                                                          ),
                                                  alignTop: false,
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                              ),
                            )
                          else
                            const Spacer(),
                        ],
                      ),
                    )
                  else
                    // Bound as soon as the BLoC owns this live, not once it
                    // reports connected: the renderer then already exists when
                    // the first track is subscribed, and the player verifies
                    // room ownership itself before attaching to anything.
                    LiveVideoPlayer(
                      live: live,
                      isActive: widget.isActive && isThisRoom,
                      liveKitOnly: true,
                    ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: isPk || isMultiGrid
                            ? MediaQuery.sizeOf(context).height * 0.34
                            : TikTokLiveTokens.bottomScrimH,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(
                                alpha: (isPk || isMultiGrid)
                                    ? 0.76
                                    : TikTokLiveTokens.bottomScrimAlpha,
                              ),
                              Colors.black.withValues(
                                alpha: (isPk || isMultiGrid) ? 0.3 : 0.78,
                              ),
                              Colors.black.withValues(
                                alpha: (isPk || isMultiGrid) ? 0.08 : 0.38,
                              ),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.28, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height:
                            MediaQuery.paddingOf(context).top +
                            TikTokLiveTokens.topScrimH,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(
                                alpha: TikTokLiveTokens.topScrimAlpha,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: BlocBuilder<LiveViewerBloc, LiveViewerState>(
                      buildWhen: (prev, curr) {
                        final pCount = (
                          prev.live?.viewerCount ?? 0,
                          prev.live?.likeCount ?? 0,
                          prev.live?.isFollowing ?? false,
                        );
                        final cCount = (
                          curr.live?.viewerCount ?? 0,
                          curr.live?.likeCount ?? 0,
                          curr.live?.isFollowing ?? false,
                        );
                        return prev.topViewerAvatars != curr.topViewerAvatars ||
                            pCount != cCount;
                      },
                      builder: (context, state) {
                        final avatars = isThisRoom
                            ? state.topViewerAvatars
                            : (widget.live.metadata?['topViewerAvatars']
                                          as List?)
                                      ?.map((e) => e.toString())
                                      .where((url) => url.isNotEmpty)
                                      .take(3)
                                      .toList() ??
                                  const <String>[];
                        final counts = isThisRoom
                            ? (
                                viewer: state.live?.viewerCount ?? 0,
                                like: state.live?.likeCount ?? 0,
                                following: state.live?.isFollowing ?? false,
                              )
                            : (
                                viewer: widget.live.viewerCount,
                                like: widget.live.likeCount,
                                following: widget.live.isFollowing,
                              );
                        final liveForTop = live.copyWith(
                          viewerCount: counts.viewer,
                          likeCount: counts.like,
                          isFollowing: counts.following,
                        );
                        return TikTokLiveTopBar(
                          live: liveForTop,
                          topViewerAvatars: avatars,
                          onFollow: () {
                            if (widget.isActive) {
                              context.read<LiveViewerBloc>().add(
                                const LiveViewerFollowToggled(),
                              );
                            }
                          },
                          onClose: () {
                            if (widget.onClose != null) {
                              widget.onClose!();
                            }
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/');
                            }
                          },
                          onHourlyRankTap: widget.isActive
                              ? () => _openRanking(live)
                              : null,
                          onLeagueTap: widget.isActive
                              ? () => _openLeague(live)
                              : null,
                        );
                      },
                    ),
                  ),
                  if (showFanClub && !isMultiGrid)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top + 78,
                      left: TikTokLiveTokens.topInsetH,
                      child: FanClubJoinButton(
                        onTap: () => unawaited(_joinFanClub(live.hostId)),
                      ),
                    ),
                  if (isMultiGuest && !isPk && !isMultiGrid)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top + 108,
                      right: 4,
                      child: GuestRequestPanel(
                        slots: [
                          GuestSlotData(
                            userId: live.hostId,
                            name: live.hostName,
                            avatarUrl: live.hostAvatar,
                            isHost: true,
                          ),
                          ...guests,
                        ],
                        onRequestTap: () => _openGuestRequest(live),
                      ),
                    ),
                  if (isPk && isThisRoom)
                    Positioned(
                      right: 10,
                      bottom: barTotalH + keyboardInset + 72,
                      child: Column(
                        children: [
                          _SideAction(
                            icon: Icons.back_hand_outlined,
                            onTap: () {},
                          ),
                          const SizedBox(height: 12),
                          _SideAction(
                            icon: Icons.favorite,
                            iconColor: const Color(0xFFFF2D55),
                            onTap: () {
                              _spawnHearts(3);
                              context.read<LiveViewerBloc>().add(
                                const LiveViewerLiked(burst: 3),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _SideAction(
                            icon: Icons.layers_outlined,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  if (isThisRoom && !isPk)
                    Positioned(
                      right: 0,
                      top: headerBottom,
                      bottom: barTotalH + keyboardInset + 48,
                      width: 64,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          _spawnHearts(2);
                          context.read<LiveViewerBloc>().add(
                            const LiveViewerLiked(burst: 1),
                          );
                        },
                      ),
                    ),
                  if (widget.isActive && isThisRoom && !isMultiGrid && !isPk)
                    Positioned(
                      left: TikTokLiveTokens.commentLeft,
                      right: isMultiGuest ? 68 : 56,
                      bottom: barTotalH + keyboardInset + 8 + giftGoalH,
                      child: BlocBuilder<LiveViewerBloc, LiveViewerState>(
                        buildWhen: (prev, curr) =>
                            prev.comments != curr.comments ||
                            prev.pinnedComment != curr.pinnedComment,
                        builder: (context, state) {
                          final pinned = state.pinnedComment;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (pinned != null) ...[
                                PinnedCommentBar(comment: pinned),
                                const SizedBox(height: 8),
                              ],
                              _buildCommentsSection(
                                context: context,
                                state: state,
                                live: live,
                                height: math.min(
                                  TikTokLiveTokens.commentFeedH,
                                  (MediaQuery.sizeOf(context).height -
                                          headerBottom -
                                          barTotalH -
                                          keyboardInset -
                                          giftGoalH -
                                          (pinned == null ? 0 : 58) -
                                          24)
                                      .clamp(
                                        64.0,
                                        TikTokLiveTokens.commentFeedH,
                                      ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  if (widget.isActive && isThisRoom && showGiftGoal)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: barTotalH + keyboardInset + 6,
                      child: BlocBuilder<LiveViewerBloc, LiveViewerState>(
                        buildWhen: (prev, curr) {
                          final pm = prev.live?.metadata;
                          final cm = curr.live?.metadata;
                          final p = (
                            pm?['giftGoalCurrent'] as int? ?? 0,
                            pm?['giftGoalTarget'] as int? ?? 0,
                          );
                          final c = (
                            cm?['giftGoalCurrent'] as int? ?? 0,
                            cm?['giftGoalTarget'] as int? ?? 0,
                          );
                          return p != c;
                        },
                        builder: (context, state) {
                          final goal = isThisRoom
                              ? (
                                  current:
                                      state.live?.metadata?['giftGoalCurrent']
                                          as int? ??
                                      0,
                                  target:
                                      state.live?.metadata?['giftGoalTarget']
                                          as int? ??
                                      0,
                                )
                              : (
                                  current:
                                      live.metadata?['giftGoalCurrent']
                                          as int? ??
                                      7,
                                  target:
                                      live.metadata?['giftGoalTarget']
                                          as int? ??
                                      8,
                                );
                          return GiftGoalCard(
                            title: 'Help ${live.hostName} reach the gift goal!',
                            current: goal.current,
                            target: goal.target,
                            onSend: () => _openGifts(),
                            onClose: () =>
                                setState(() => _giftGoalDismissed = true),
                          );
                        },
                      ),
                    ),
                  if (widget.isActive && isThisRoom)
                    BlocBuilder<LiveViewerBloc, LiveViewerState>(
                      buildWhen: (prev, curr) =>
                          prev.recentGifts != curr.recentGifts ||
                          prev.activeGiftAnimation !=
                              curr.activeGiftAnimation ||
                          prev.latestGiftCombo != curr.latestGiftCombo,
                      builder: (context, state) {
                        final bloc = context.read<LiveViewerBloc>();
                        return FloatingGiftsLayer(
                          recentGifts: state.recentGifts,
                          activeGift: state.activeGiftAnimation,
                          latestCombo: state.latestGiftCombo,
                          onAnimationComplete: () => context
                              .read<LiveViewerBloc>()
                              .add(const LiveViewerGiftAnimationCleared()),
                          onComboConsumed: (payload) {
                            if (bloc.isClosed) return;
                            bloc.add(LiveViewerGiftComboConsumed(payload));
                          },
                        );
                      },
                    ),
                  if (isThisRoom) ...[
                    BlocBuilder<LiveViewerBloc, LiveViewerState>(
                      buildWhen: (prev, curr) =>
                          prev.floatingHeartBurst != curr.floatingHeartBurst,
                      builder: (context, state) {
                        return FloatingHeartsOverlay(
                          burst: state.floatingHeartBurst,
                          onConsumed: () => context.read<LiveViewerBloc>().add(
                            const LiveViewerHeartBurstConsumed(),
                          ),
                        );
                      },
                    ),
                    ..._tapHearts,
                  ],
                  if (widget.isActive && isThisRoom)
                    BlocBuilder<LiveViewerBloc, LiveViewerState>(
                      buildWhen: (prev, curr) =>
                          prev.moderationBanner != curr.moderationBanner,
                      builder: (context, state) {
                        final banner = state.moderationBanner;
                        if (banner == null || banner.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          left: 12,
                          right: 12,
                          top: headerBottom + 8,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                banner,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  if (widget.isActive && isThisRoom)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: barTotalH + keyboardInset + 6,
                      child: const GuestStagePrompt(),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: keyboardInset,
                    child: BlocBuilder<LiveViewerBloc, LiveViewerState>(
                      buildWhen: (prev, curr) {
                        final pm = prev.live?.metadata;
                        final cm = curr.live?.metadata;
                        final pShare = pm?['shareCount'] as int?;
                        final cShare = cm?['shareCount'] as int?;
                        return prev.session?.coinBalance !=
                                curr.session?.coinBalance ||
                            prev.chatMuted != curr.chatMuted ||
                            prev.isCommentSending != curr.isCommentSending ||
                            pShare != cShare;
                      },
                      builder: (context, state) {
                        final chatMuted = isThisRoom ? state.chatMuted : false;
                        final isCommentSending = isThisRoom
                            ? state.isCommentSending
                            : false;
                        final shareCount = isThisRoom
                            ? (state.live?.metadata?['shareCount'] as int?)
                            : (live.metadata?['shareCount'] as int?);
                        return TikTokLiveBottomBar(
                          onTypeTap: () {
                            if (chatMuted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Your chat is muted on this live',
                                  ),
                                  backgroundColor: AppColors.surface,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            setState(() => _showComposer = true);
                          },
                          onGiftTap: _openGifts,
                          onShareTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Share @${live.hostName}'),
                                backgroundColor: AppColors.surface,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          onTreasureTap: (isPk || isMultiGrid)
                              ? null
                              : widget.isActive
                              ? () => _openTreasureBoxes(context)
                              : null,
                          onRoseTap: widget.isActive ? _sendRose : null,
                          onMultiGuestTap: widget.isActive
                              ? () => _openGuestRequest(live)
                              : null,
                          shareCount: shareCount,
                          commentField: _showComposer
                              ? CommentInputBar(
                                  enabled: connected && !chatMuted,
                                  isSending: isCommentSending,
                                  hintText: chatMuted
                                      ? 'Chat muted'
                                      : 'Write...',
                                  onSend: (text) {
                                    if (isCommentSending) return;
                                    context.read<LiveViewerBloc>().add(
                                      LiveViewerCommentSent(text),
                                    );
                                  },
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                  if (widget.isActive && isThisRoom)
                    BlocBuilder<LiveViewerBloc, LiveViewerState>(
                      buildWhen: (prev, curr) =>
                          prev.connectionState != curr.connectionState ||
                          prev.session?.errorMessage !=
                              curr.session?.errorMessage ||
                          prev.session?.reconnectAttempt !=
                              curr.session?.reconnectAttempt,
                      builder: (context, state) {
                        return LiveStateOverlay(
                          state: state.connectionState,
                          message: state.session?.errorMessage,
                          reconnectAttempt:
                              state.session?.reconnectAttempt ?? 0,
                          onRetry: () => context.read<LiveViewerBloc>().add(
                            const LiveViewerRetryRequested(),
                          ),
                          onLeave: widget.onClose,
                        );
                      },
                    ),
                  if (widget.isActive && isThisRoom)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: barTotalH + giftGoalH + 18,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            alignment: Alignment.bottomCenter,
                            child: Visibility(
                              visible: _showLiveFeatures,
                              maintainState: true,
                              child: LiveInteractiveViewerPanel(
                                liveId: live.id,
                                isHost: state.currentUserId == live.hostId,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: LiveInteractiveToggleButton(
                              onTap: () => setState(
                                () => _showLiveFeatures = !_showLiveFeatures,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openTreasureBoxes(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Treasure boxes are loading…'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SideAction({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 18),
      ),
    );
  }
}

class _PkVideoLayout extends StatelessWidget {
  final LiveEntity live;
  final LiveEntity? opponentLive;
  final bool isActive;
  final Room? battleRoom;

  const _PkVideoLayout({
    required this.live,
    required this.opponentLive,
    required this.isActive,
    required this.battleRoom,
  });

  @override
  Widget build(BuildContext context) {
    final guestName =
        opponentLive?.hostName ??
        live.metadata?['guestName'] as String? ??
        'Guest';
    final guestAvatar =
        opponentLive?.hostAvatar ?? live.metadata?['guestAvatar'] as String?;
    // Only the host's own tier is known here; the opponent's side stays bare
    // rather than showing a placeholder league.
    final hostTier = (live.metadata?['hostLeagueTier'] as String?)?.trim();
    const badgeTop = 38.0;

    return ClipRect(
      child: Directionality(
        // Keep the host on the physical left and the opponent on the physical
        // right in Arabic too. Ambient RTL must not swap the two live tracks.
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LiveVideoPlayer(
                    live: live,
                    isActive: isActive,
                    fit: BoxFit.cover,
                    compact: true,
                    liveKitOnly: true,
                  ),
                  if (hostTier != null && hostTier.isNotEmpty)
                    Positioned(
                      left: 8,
                      top: badgeTop,
                      child: _PkCornerBadge(label: hostTier),
                    ),
                ],
              ),
            ),
            Container(width: 1, color: Colors.white.withValues(alpha: 0.28)),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PkGuestFeed(
                    liveId: opponentLive?.id ?? live.id,
                    guestName: guestName,
                    guestAvatar: guestAvatar,
                    room: battleRoom,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 10,
                    child: _GuestChip(
                      name: guestName,
                      avatar: guestAvatar,
                      showAdd: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PkGuestFeed extends StatefulWidget {
  final String liveId;
  final String guestName;
  final String? guestAvatar;
  final Room? room;
  final BoxFit fit;

  const _PkGuestFeed({
    required this.liveId,
    required this.guestName,
    this.guestAvatar,
    this.room,
    this.fit = BoxFit.fitWidth,
  });

  @override
  State<_PkGuestFeed> createState() => _PkGuestFeedState();
}

class _PkGuestFeedState extends State<_PkGuestFeed> {
  @override
  Widget build(BuildContext context) {
    final currentRoom = widget.room;
    if (currentRoom != null) {
      return BuildSafeListenableBuilder(
        listenable: currentRoom,
        builder: (_, _) {
          // The PK tile is half the screen width, and `adaptiveStream`
          // measures exactly that renderer to pick the simulcast layer. A
          // manual `setVideoQuality` here used to cap it at MEDIUM/640x960 —
          // livekit_client 2.11 takes the smaller of the manual and adaptive
          // sizes, so the cap could only ever make the opponent look worse.
          final track = _remoteVideoTrack(currentRoom);
          if (track != null) {
            return VideoTrackRenderer(
              track,
              fit: VideoViewFit.cover,
              placeholderBuilder: (_) => _fallback(context),
            );
          }
          return _fallback(context);
        },
      );
    }
    return _fallback(context);
  }

  /// Muted publications are kept so a host covering their camera leaves the
  /// renderer in place instead of destroying and rebuilding it.
  RemoteVideoTrack? _remoteVideoTrack(Room room) {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (publication.subscribed && track != null) return track;
      }
    }
    return null;
  }

  Widget _fallback(BuildContext context) {
    final url = widget.guestAvatar?.trim();
    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2A31), Color(0xFF121216)],
        ),
      ),
      alignment: Alignment.center,
      child: ClipOval(
        child: SizedBox(
          width: 72,
          height: 72,
          child: FallbackAvatar(
            seed: widget.liveId,
            name: widget.guestName,
            radius: 36,
          ),
        ),
      ),
    );
    if (url == null || url.isEmpty) return placeholder;

    final memCacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 4096)
            .toInt();
    return ColoredBox(
      color: Colors.black,
      child: CachedNetworkImage(
        imageUrl: url,
        cacheManager: AppMediaCacheManager.instance,
        memCacheWidth: memCacheWidth,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

class _PkBattleTimer extends StatelessWidget {
  const _PkBattleTimer({required this.endTime, required this.multiplier});

  final DateTime? endTime;
  final double multiplier;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(
        const Duration(seconds: 1),
        (value) => value,
      ),
      builder: (_, _) {
        final seconds = math.max(
          0,
          endTime?.difference(DateTime.now()).inSeconds ?? 0,
        );
        final time =
            '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
            '${(seconds % 60).toString().padLeft(2, '0')}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xE60A2430),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            '${multiplier > 1 ? '×${multiplier.toStringAsFixed(1)}  ' : ''}$time',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

class _PkCornerBadge extends StatelessWidget {
  final String label;

  const _PkCornerBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2B6CFF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond, size: 9, color: Color(0xFFB8D4FF)),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PkContributors extends StatelessWidget {
  final List<String> avatars;
  final bool isLeft;

  const _PkContributors({required this.avatars, this.isLeft = true});

  @override
  Widget build(BuildContext context) {
    final ranked = avatars
        .take(3)
        .indexed
        .map((item) => (url: item.$2, rank: item.$1 + 1))
        .toList(growable: false);
    final list = isLeft ? ranked.reversed.toList(growable: false) : ranked;
    if (list.isEmpty) return const SizedBox(height: 34);
    final ring = isLeft ? const Color(0xFFFF5A8A) : const Color(0xFF25F4EE);

    return Row(
      mainAxisAlignment: isLeft
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 1.8),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: list[i].url,
                    cacheManager: AppMediaCacheManager.instance,
                    memCacheWidth: 128,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: AppColors.surface,
                      child: const Icon(
                        Icons.person,
                        size: 14,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ring,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Text(
                    '${list[i].rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GuestChip extends StatelessWidget {
  final String name;
  final String? avatar;
  final bool showAdd;

  const _GuestChip({required this.name, this.avatar, this.showAdd = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 6, 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatar != null) ...[
            ClipOval(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CachedNetworkImage(
                  imageUrl: avatar!,
                  cacheManager: AppMediaCacheManager.instance,
                  memCacheWidth: 72,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      FallbackAvatar(seed: name, name: name, radius: 9),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          if (showAdd) ...[
            const SizedBox(width: 4),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 12, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }
}
