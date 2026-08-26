import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/live_gift_sheet.dart';
import '../../../../core/utils/build_safe_notifier.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../domain/repositories/guest_repository.dart';
import '../bloc/live_viewer/live_viewer_bloc.dart';
import '../bloc/live_viewer/live_viewer_event.dart';
import '../bloc/live_viewer/live_viewer_state.dart';
import 'comment_input_bar.dart';
import 'comments_section.dart';
import 'fallback_media.dart';
import 'fan_club_widgets.dart';
import 'floating_gifts.dart';
import 'floating_hearts.dart';
import 'gift_goal_card.dart';
import '../../data/services/fake_livekit_service.dart' show LiveKitService;
import '../di/live_viewer_injector.dart' as di;
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
  bool _giftGoalDismissed = false;
  final List<FloatingHeart> _tapHearts = [];

  @override
  void initState() {
    super.initState();
    _scheduleActivate();
  }

  @override
  void didUpdateWidget(covariant LiveRoomPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live.id != widget.live.id) {
      _deactivateIfThis();
      _scheduleActivate();
    } else if (widget.isActive && !oldWidget.isActive) {
      _scheduleActivate();
    } else if (!widget.isActive && oldWidget.isActive) {
      _deactivateIfThis();
    }
  }

  @override
  void dispose() {
    _deactivateIfThis();
    super.dispose();
  }

  void _deactivateIfThis() {
    final viewerBloc = context.read<LiveViewerBloc>();
    if (viewerBloc.activeLiveId == widget.live.id) {
      viewerBloc.add(const LiveViewerDeactivated());
    }
  }

  void _scheduleActivate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LiveViewerBloc>().add(LiveViewerActivated(widget.live));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined Fan Club'),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _openLeague(LiveEntity live) {
    final entries = List.generate(6, (i) {
      return RankingEntry(
        rank: i + 1,
        userId: 'lg_$i',
        username: 'League Star ${i + 1}',
        avatarUrl: 'https://i.pravatar.cc/150?u=lg_${live.id}_$i',
        score: 8300000 - i * 900000,
      );
    });
    showLeagueMatchOverlay(
      context,
      entries: entries,
      myEntry: const RankingEntry(
        rank: 99,
        userId: 'me',
        username: 'You',
        avatarUrl: 'https://i.pravatar.cc/150?u=me',
        score: 1100000,
      ),
      pointsToNext: 1100000,
      onSendGift: _openGifts,
    );
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
    return BlocBuilder<LiveViewerBloc, LiveViewerState>(
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
        final isPk = isThisRoom ? state.isPk : live.metadata?['isPk'] == true;
        // Someone actually publishing on stage puts the room in grid layout on
        // its own — waiting for a metadata flag meant an accepted co-host was
        // invisible to everyone watching.
        final stageGuests = isThisRoom
            ? state.activeGuests
            : const <GuestSummary>[];
        final hasLiveGuests = stageGuests.isNotEmpty;
        final isMultiGrid =
            live.metadata?['isMultiGrid'] == true || (hasLiveGuests && !isPk);
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
        final guests = _guestsFrom(live, stageGuests);
        final barTotalH = 42 + 8 + (bottomPad < 16 ? 16.0 : bottomPad);
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
        final contentBottom = barTotalH + giftGoalH + 8;

        return GestureDetector(
          onDoubleTap: () {
            _spawnHearts(5);
            context.read<LiveViewerBloc>().add(const LiveViewerLiked(burst: 5));
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
                              isActive: widget.isActive && connected,
                              battleRoom: isThisRoom
                                  ? di.sl<LiveKitService>().battleRoom
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
                                        final battle = state.battle;
                                        final winner = battle?.winnerLiveId;
                                        final decided =
                                            battle != null &&
                                            winner != null &&
                                            winner.isNotEmpty;
                                        final leftWon =
                                            decided && winner == live.id;

                                        return Stack(
                                          alignment: Alignment.topCenter,
                                          clipBehavior: Clip.none,
                                          children: [
                                            PkBattleBar(
                                              scoreLeft: state.pkScoreLeft,
                                              scoreRight: state.pkScoreRight,
                                            ),
                                            // TikTok calls the round on the
                                            // panels themselves, not only in
                                            // the score numbers.
                                            if (decided) ...[
                                              Positioned(
                                                top: 28,
                                                left: 8,
                                                child: _PkResultBadge(
                                                  won: leftWon,
                                                ),
                                              ),
                                              Positioned(
                                                top: 28,
                                                right: 8,
                                                child: _PkResultBadge(
                                                  won: !leftWon,
                                                ),
                                              ),
                                            ],
                                            Positioned(
                                              top: 26,
                                              child: _PkBattleTimer(
                                                endTime: battle?.endTime,
                                                multiplier:
                                                    battle?.multiplier ?? 1,
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
                                avatars:
                                    (live.metadata?['pkContributorsLeft']
                                            as List?)
                                        ?.cast<String>() ??
                                    const <String>[],
                                isLeft: true,
                              ),
                            ),
                            Expanded(
                              child: _PkContributors(
                                avatars:
                                    (live.metadata?['pkContributorsRight']
                                            as List?)
                                        ?.cast<String>() ??
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
                            padding: const EdgeInsets.fromLTRB(10, 4, 54, 0),
                            child: BlocBuilder<LiveViewerBloc, LiveViewerState>(
                              buildWhen: (prev, curr) =>
                                  prev.comments != curr.comments ||
                                  prev.pinnedComment != curr.pinnedComment,
                              builder: (context, state) {
                                final pinned = state.pinnedComment;
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final pinH = pinned == null ? 0.0 : 50.0;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (pinned != null) ...[
                                          PinnedCommentBar(comment: pinned),
                                          const SizedBox(height: 6),
                                        ],
                                        _buildCommentsSection(
                                          context: context,
                                          state: state,
                                          live: live,
                                          height: (constraints.maxHeight - pinH)
                                              .clamp(
                                                40.0,
                                                constraints.maxHeight,
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
                      // Real LiveKit tiles once the server says someone is on
                      // stage; the mock grid stays for rooms the guest API has
                      // nothing to say about.
                      if (hasLiveGuests)
                        ViewerStage(
                          live: live,
                          guests: stageGuests,
                          liveKit: di.sl<LiveKitService>(),
                          isSelfOnStage: state.isOnStage,
                          currentUserId: state.currentUserId,
                          // Always reserve a usable comment band and the
                          // composer on short phones / large text scales.
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
                            padding: const EdgeInsets.fromLTRB(10, 2, 16, 0),
                            child: BlocBuilder<LiveViewerBloc, LiveViewerState>(
                              buildWhen: (prev, curr) =>
                                  prev.comments != curr.comments ||
                                  prev.pinnedComment != curr.pinnedComment,
                              builder: (context, state) {
                                final pinned = state.pinnedComment;
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final pinH = pinned == null ? 0.0 : 50.0;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (pinned != null) ...[
                                          PinnedCommentBar(comment: pinned),
                                          const SizedBox(height: 6),
                                        ],
                                        _buildCommentsSection(
                                          context: context,
                                          state: state,
                                          live: live,
                                          height: (constraints.maxHeight - pinH)
                                              .clamp(
                                                40.0,
                                                constraints.maxHeight,
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
                LiveVideoPlayer(
                  live: live,
                  isActive: widget.isActive && connected,
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
                        : (widget.live.metadata?['topViewerAvatars'] as List?)
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
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Joined Fan Club'),
                          backgroundColor: AppColors.surface,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
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
                        level: 12,
                      ),
                      ...guests,
                    ],
                    onRequestTap: () => _openGuestRequest(live),
                  ),
                ),
              if (isPk && isThisRoom)
                Positioned(
                  right: 10,
                  bottom: barTotalH + 72,
                  child: Column(
                    children: [
                      _SideAction(icon: Icons.back_hand_outlined, onTap: () {}),
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
                      _SideAction(icon: Icons.layers_outlined, onTap: () {}),
                    ],
                  ),
                ),
              if (isThisRoom && !isPk)
                Positioned(
                  right: 0,
                  top: headerBottom,
                  bottom: barTotalH + 48,
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
                  bottom: barTotalH + 8 + giftGoalH,
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
                            // A fixed 216 is most of a short phone once the
                            // header, the bars and a pinned comment are out.
                            // Cap it at the space actually between them.
                            height: math.min(
                              TikTokLiveTokens.commentFeedH,
                              (MediaQuery.sizeOf(context).height -
                                      headerBottom -
                                      barTotalH -
                                      giftGoalH -
                                      (pinned == null ? 0 : 58) -
                                      24)
                                  .clamp(64.0, TikTokLiveTokens.commentFeedH),
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
                  bottom: barTotalH + 6,
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
                                  live.metadata?['giftGoalCurrent'] as int? ??
                                  7,
                              target:
                                  live.metadata?['giftGoalTarget'] as int? ?? 8,
                            );
                      return GiftGoalCard(
                        title: 'Help ${live.hostName} reach the gift goal!',
                        current: goal.current,
                        target: goal.target,
                        onSend: () {
                          _openGifts();
                        },
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
                      prev.activeGiftAnimation != curr.activeGiftAnimation ||
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
              // Sits directly above the input bar so an invite (or the leave
              // control once on stage) is never buried behind the HUD.
              if (widget.isActive && isThisRoom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: barTotalH + 6,
                  child: const GuestStagePrompt(),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BlocBuilder<LiveViewerBloc, LiveViewerState>(
                  buildWhen: (prev, curr) {
                    final pm = prev.live?.metadata;
                    final cm = curr.live?.metadata;
                    final pShare = pm?['shareCount'] as int? ?? 111;
                    final cShare = cm?['shareCount'] as int? ?? 111;
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
                        ? (state.live?.metadata?['shareCount'] as int? ?? 111)
                        : (live.metadata?['shareCount'] as int? ?? 111);
                    return TikTokLiveBottomBar(
                      onTypeTap: () {
                        if (chatMuted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Your chat is muted on this live'),
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
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Treasure chest'),
                                  backgroundColor: AppColors.surface,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                      onRoseTap: widget.isActive ? _sendRose : null,
                      onMultiGuestTap: widget.isActive
                          ? () => _openGuestRequest(live)
                          : null,
                      shareCount: shareCount,
                      commentField: _showComposer
                          ? CommentInputBar(
                              enabled: connected && !chatMuted,
                              isSending: isCommentSending,
                              hintText: chatMuted ? 'Chat muted' : 'Write...',
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
                      reconnectAttempt: state.session?.reconnectAttempt ?? 0,
                      onRetry: () => context.read<LiveViewerBloc>().add(
                        const LiveViewerRetryRequested(),
                      ),
                      onLeave: widget.onClose,
                    );
                  },
                ),
            ],
          ),
        );
      },
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
  final bool isActive;
  final Room? battleRoom;

  const _PkVideoLayout({
    required this.live,
    required this.isActive,
    required this.battleRoom,
  });

  @override
  Widget build(BuildContext context) {
    final guestName = live.metadata?['guestName'] as String? ?? 'Guest';
    final guestAvatar = live.metadata?['guestAvatar'] as String?;
    const badgeTop = 38.0;

    return ClipRect(
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
                  fit: BoxFit.fitWidth,
                ),
                const Positioned(
                  left: 8,
                  top: badgeTop,
                  child: _PkCornerBadge(label: 'B2'),
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
                  liveId: live.id,
                  guestName: guestName,
                  guestAvatar: guestAvatar,
                  room: battleRoom,
                  fit: BoxFit.fitWidth,
                ),
                const Positioned(
                  right: 8,
                  top: badgeTop,
                  child: _PkCornerBadge(label: 'B1'),
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
    );
  }
}

class _PkGuestFeed extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final currentRoom = room;
    if (currentRoom != null) {
      return BuildSafeListenableBuilder(
        listenable: currentRoom,
        builder: (_, _) {
          final track = _remoteVideoTrack(currentRoom);
          return track == null
              ? _fallback()
              : VideoTrackRenderer(track, fit: VideoViewFit.cover);
        },
      );
    }
    return _fallback();
  }

  VideoTrack? _remoteVideoTrack(Room room) {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (publication.subscribed && !publication.muted && track != null) {
          return track;
        }
      }
    }
    return null;
  }

  Widget _fallback() {
    final url =
        guestAvatar ?? 'https://i.pravatar.cc/600?u=${liveId.hashCode + 99}';
    return ColoredBox(
      color: Colors.black,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        placeholder: (_, _) => const ColoredBox(color: Color(0xFF2A1A3A)),
        errorWidget: (_, _, _) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5A2A6A), Color(0xFF2A4A7A)],
            ),
          ),
          alignment: Alignment.center,
          child: ClipOval(
            child: SizedBox(
              width: 72,
              height: 72,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    FallbackAvatar(seed: liveId, name: guestName, radius: 36),
              ),
            ),
          ),
        ),
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
        // TikTok's round clock: a dark capsule under the seam, the time in
        // tabular figures so the digits do not jitter every second, and the
        // speed-boost multiplier as its own pink chip beside it rather than
        // crammed into the same string.
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (multiplier > 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2D55), Color(0xFFFF5C8A)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '×${multiplier.toStringAsFixed(multiplier % 1 == 0 ? 0 : 1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xE60A2430),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// WIN / LOSE capsule shown on a panel once the round has a winner.
class _PkResultBadge extends StatelessWidget {
  const _PkResultBadge({required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: won
            ? const LinearGradient(
                colors: [Color(0xFFFFC93C), Color(0xFFFFA000)],
              )
            : null,
        color: won ? null : const Color(0xCC4A4A4A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        won ? 'WIN' : 'LOSE',
        style: TextStyle(
          color: won ? const Color(0xFF4A2800) : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1.1,
          letterSpacing: 0.4,
        ),
      ),
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
    final list = avatars.take(3).toList();
    if (list.isEmpty) return const SizedBox(height: 34);
    final ring = isLeft ? const Color(0xFFFF5A8A) : const Color(0xFF25F4EE);
    final ranks = isLeft ? const [3, 2, 1] : const [1, 2, 3];

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
                    imageUrl: list[i],
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
                    '${ranks[i]}',
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
