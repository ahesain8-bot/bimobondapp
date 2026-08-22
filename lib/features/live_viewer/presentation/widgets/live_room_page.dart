import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/fake_socket_service.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_session_entity.dart';
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
import 'gift_icon.dart';
import 'gift_picker_sheet.dart';
import 'guest_panel.dart';
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

  void _openGifts(int balance) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => GiftPickerSheet(
        coinBalance: balance,
        onGiftSelected: (gift) {
          Navigator.pop(ctx);
          context.read<LiveViewerBloc>().add(LiveViewerGiftSent(gift));
        },
      ),
    );
  }

  void _sendRose() {
    final rose = MockGiftCatalog.byId('gift_rose');
    if (rose != null) {
      context.read<LiveViewerBloc>().add(LiveViewerGiftSent(rose));
    }
  }

  Future<void> _openGuestRequest(LiveEntity live) async {
    final requested = await showGuestRequestSheet(
      context,
      hostName: live.hostName,
      hostAvatar: live.hostAvatar,
      viewerAvatar: 'https://i.pravatar.cc/150?u=me',
    );
    if (requested == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guest request sent'),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openRanking(LiveEntity live) {
    final entries = List.generate(8, (i) {
      return RankingEntry(
        rank: i + 1,
        userId: 'rank_$i',
        username: i == 2 ? live.hostName : 'Creator ${i + 1}',
        subtitle: i.isEven ? '#FanClub' : 'Rising star',
        avatarUrl: 'https://i.pravatar.cc/150?u=rank_${live.id}_$i',
        score: 900000 - i * 87000,
        isLive: i == 2 || i == 4 || i == 5,
      );
    });
    showHourlyRankingSheet(
      context,
      hostName: live.hostName,
      hostAvatar: live.hostAvatar,
      entries: entries,
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
    final viewerBloc = context.read<LiveViewerBloc>();
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
      onSendGift: () =>
          _openGifts(viewerBloc.state.session?.coinBalance ?? 1250),
    );
  }

  List<GuestSlotData> _guestsFrom(LiveEntity live) {
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
  }) {
    final moderators = _moderatorIdsFrom(live);
    final bloc = context.read<LiveViewerBloc>();
    return CommentsSection(
      comments: state.comments,
      height: height,
      alignTop: alignTop,
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
        final isPk = live.metadata?['isPk'] == true;
        final isMultiGrid = live.metadata?['isMultiGrid'] == true;
        final isMultiGuest = live.metadata?['isMultiGuest'] == true;
        final showFanClub =
            !isPk && !isMultiGrid && live.metadata?['showFanClub'] != false;
        final showGiftGoal =
            !isPk &&
            !_giftGoalDismissed &&
            (isMultiGrid || live.metadata?['showGiftGoal'] == true);
        final bottomPad = MediaQuery.paddingOf(context).bottom;
        final guests = _guestsFrom(live);
        final barTotalH = 42 + 8 + (bottomPad < 16 ? 16.0 : bottomPad);
        final giftGoalH = showGiftGoal ? (isMultiGrid ? 112.0 : 96.0) : 0.0;
        final screenW = MediaQuery.sizeOf(context).width;
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
                                              curr.pkScoreRight,
                                      builder: (context, state) {
                                        return PkBattleBar(
                                          scoreLeft: state.pkScoreLeft,
                                          scoreRight: state.pkScoreRight,
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
                    height:
                        MediaQuery.sizeOf(context).height *
                        (isPk || isMultiGrid ? 0.32 : 0.36),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(
                            alpha: (isPk || isMultiGrid) ? 0.72 : 0.97,
                          ),
                          Colors.black.withValues(
                            alpha: (isPk || isMultiGrid) ? 0.28 : 0.82,
                          ),
                          Colors.black.withValues(
                            alpha: (isPk || isMultiGrid) ? 0.06 : 0.45,
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
                    height: MediaQuery.paddingOf(context).top + 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
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
                            height: TikTokLiveTokens.commentFeedH,
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
                          final rose = MockGiftCatalog.byId('gift_rose');
                          if (rose != null) {
                            context.read<LiveViewerBloc>().add(
                              LiveViewerGiftSent(rose),
                            );
                          }
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
                      prev.activeGiftAnimation != curr.activeGiftAnimation,
                  builder: (context, state) {
                    return FloatingGiftsLayer(
                      recentGifts: state.recentGifts,
                      activeGift: state.activeGiftAnimation,
                      onAnimationComplete: () => context
                          .read<LiveViewerBloc>()
                          .add(const LiveViewerGiftAnimationCleared()),
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
                    final coinBalance = isThisRoom
                        ? state.session?.coinBalance
                        : null;
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
                      onGiftTap: () => _openGifts(coinBalance ?? 1250),
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

  const _PkVideoLayout({required this.live, required this.isActive});

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
  final BoxFit fit;

  const _PkGuestFeed({
    required this.liveId,
    required this.guestName,
    this.guestAvatar,
    this.fit = BoxFit.fitWidth,
  });

  @override
  Widget build(BuildContext context) {
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
        placeholder: (_, __) => const ColoredBox(color: Color(0xFF2A1A3A)),
        errorWidget: (_, __, ___) => Container(
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
                errorWidget: (_, __, ___) =>
                    FallbackAvatar(seed: liveId, name: guestName, radius: 36),
              ),
            ),
          ),
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
                    errorWidget: (_, __, ___) => Container(
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
                  errorWidget: (_, __, ___) =>
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
