import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/fake_socket_service.dart';
import '../../domain/entities/live_entity.dart';
import '../../domain/entities/live_session_entity.dart';
import '../providers/live_session_provider.dart';
import 'comment_input_bar.dart';
import 'comments_section.dart';
import 'fallback_media.dart';
import 'fan_club_widgets.dart';
import 'first_gift_modal.dart';
import 'floating_gifts.dart';
import 'floating_hearts.dart';
import 'gift_goal_card.dart';
import 'gift_picker_sheet.dart';
import 'guest_panel.dart';
import 'league_overlay.dart';
import 'live_state_overlay.dart';
import 'live_video_player.dart';
import 'multi_guest_grid.dart';
import 'ranking_sheet.dart';
import 'tiktok_live_chrome.dart';
import 'tiktok_live_tokens.dart';

/// One full-screen TikTok LIVE room page inside the vertical feed.
class LiveRoomPage extends ConsumerStatefulWidget {
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
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends ConsumerState<LiveRoomPage> {
  bool _showComposer = false;
  bool _giftGoalDismissed = false;
  bool _firstGiftPrompted = false;
  final List<FloatingHeart> _tapHearts = [];

  @override
  void initState() {
    super.initState();
    // Never modify providers synchronously in lifecycle methods.
    if (widget.isActive) {
      _scheduleActivate();
    }
  }

  @override
  void didUpdateWidget(covariant LiveRoomPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _scheduleActivate();
    }
  }

  void _scheduleActivate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      ref.read(activeLiveProvider.notifier).activate(widget.live);
      _maybeShowFirstGift();
    });
  }

  void _maybeShowFirstGift() {
    if (_firstGiftPrompted || !widget.isActive) return;
    _firstGiftPrompted = true;
    Future.delayed(const Duration(milliseconds: 1600), () async {
      if (!mounted || !widget.isActive) return;
      final sent = await showFirstGiftModal(
        context,
        hostName: widget.live.hostName,
      );
      if (sent == true && mounted) {
        final rose = MockGiftCatalog.byId('gift_rose');
        if (rose != null) {
          ref.read(activeLiveProvider.notifier).sendGift(rose);
        }
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

  void _openGifts(int balance) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => GiftPickerSheet(
        coinBalance: balance,
        onGiftSelected: (gift) {
          Navigator.pop(ctx);
          ref.read(activeLiveProvider.notifier).sendGift(gift);
        },
      ),
    );
  }

  void _sendRose() {
    final rose = MockGiftCatalog.byId('gift_rose');
    if (rose != null) {
      ref.read(activeLiveProvider.notifier).sendGift(rose);
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
      onSendGift: () => _openGifts(
        ref.read(activeLiveProvider).session?.coinBalance ?? 1250,
      ),
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

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(activeLiveProvider);
    final isThisRoom = ui.live?.id == widget.live.id;
    final live = isThisRoom ? (ui.live ?? widget.live) : widget.live;
    final connected = isThisRoom &&
        (ui.connectionState == LiveConnectionState.connected ||
            ui.connectionState == LiveConnectionState.reconnecting);
    final isPk = live.metadata?['isPk'] == true;
    final isMultiGrid = live.metadata?['isMultiGrid'] == true;
    final isMultiGuest = live.metadata?['isMultiGuest'] == true;
    final showFanClub =
        !isPk && !isMultiGrid && live.metadata?['showFanClub'] != false;
    // Multi-grid reference always shows the gift-goal card above the bar.
    final showGiftGoal = !isPk &&
        !_giftGoalDismissed &&
        (isMultiGrid || live.metadata?['showGiftGoal'] == true);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final guests = _guestsFrom(live);
    final shareCount = live.metadata?['shareCount'] as int? ?? 111;

    // Bottom chrome — raised SafeArea(min 16) + padding 8 + row 42.
    final barTotalH = 42 + 8 + (bottomPad < 16 ? 16.0 : bottomPad);
    final giftGoalH = showGiftGoal ? (isMultiGrid ? 112.0 : 96.0) : 0.0;
    final screenW = MediaQuery.sizeOf(context).width;
    // PK: keep letterboxed aspect; center vertically with comments below.
    final pkVideoH = screenW / TikTokLiveTokens.pkVideoAspect;
    // Top chrome height + black gap before media (matches reference marks).
    final chromeGap = isMultiGrid
        ? TikTokLiveTokens.multiGridChromeGap
        : TikTokLiveTokens.badgeGapBelow;
    final headerBottom = MediaQuery.paddingOf(context).top +
        TikTokLiveTokens.topChromeBodyH +
        chromeGap;
    final contentBottom = barTotalH + giftGoalH + 8;

    return GestureDetector(
      onDoubleTap: () {
        if (!widget.isActive) return;
        _spawnHearts(5);
        ref.read(activeLiveProvider.notifier).like(burst: 5);
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
          // PK: video under header; contributor rows under video; comments below
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
                            child: PkBattleBar(
                              scoreLeft: ui.pkScoreLeft,
                              scoreRight: ui.pkScoreRight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Thin black gap + contributor avatars under the split (ref)
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PkContributors(
                            avatars: (live.metadata?['pkContributorsLeft']
                                        as List?)
                                    ?.cast<String>() ??
                                const <String>[],
                            isLeft: true,
                          ),
                        ),
                        Expanded(
                          child: _PkContributors(
                            avatars: (live.metadata?['pkContributorsRight']
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return CommentsSection(
                              comments: ui.comments,
                              height: constraints.maxHeight,
                              alignTop: false,
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
            // Grid under header; comments fill remaining space flush below (no pad/void)
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return CommentsSection(
                              comments: ui.comments,
                              height: constraints.maxHeight,
                              alignTop: false,
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

          // Soft bottom gradient only (no solid black void under grid)
          IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.sizeOf(context).height *
                    (isPk || isMultiGrid ? 0.32 : 0.36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(
                          alpha: (isPk || isMultiGrid) ? 0.72 : 0.97),
                      Colors.black.withValues(
                          alpha: (isPk || isMultiGrid) ? 0.28 : 0.82),
                      Colors.black.withValues(
                          alpha: (isPk || isMultiGrid) ? 0.06 : 0.45),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.28, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Soft top scrim for header readability
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

          // Top chrome
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TikTokLiveTopBar(
              live: live,
              topViewerAvatars: isThisRoom
                  ? ui.topViewerAvatars
                  : const [
                      'https://i.pravatar.cc/150?u=a',
                      'https://i.pravatar.cc/150?u=b',
                      'https://i.pravatar.cc/150?u=c',
                    ],
              onFollow: () {
                if (widget.isActive) {
                  ref.read(activeLiveProvider.notifier).toggleFollow();
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
              onHourlyRankTap:
                  widget.isActive ? () => _openRanking(live) : null,
              onLeagueTap: widget.isActive ? () => _openLeague(live) : null,
            ),
          ),

          // PK bar is inside the PK video stack above.

          // Fan club CTA (solo / multi-guest only)
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

          // Vertical guest panel
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

          // Mid-right floating actions — above bottom bar in comment zone
          if (isPk && widget.isActive)
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
                      ref.read(activeLiveProvider.notifier).like(burst: 3);
                    },
                  ),
                  const SizedBox(height: 12),
                  _SideAction(icon: Icons.layers_outlined, onTap: () {}),
                ],
              ),
            ),

          // Comments (solo / sidebar — PK & multi-grid comments are in columns above)
          if (widget.isActive && isThisRoom && !isMultiGrid && !isPk)
            Positioned(
              left: TikTokLiveTokens.commentLeft,
              right: isMultiGuest ? 68 : 56,
              bottom: barTotalH + 8 + giftGoalH,
              child: CommentsSection(
                comments: ui.comments,
                height: TikTokLiveTokens.commentFeedH,
              ),
            ),

          // Gift goal — sits just above the action bar (multi-grid reference B)
          if (widget.isActive && isThisRoom && showGiftGoal)
            Positioned(
              left: 10,
              right: 10,
              bottom: barTotalH + 6,
              child: GiftGoalCard(
                title: 'Help ${live.hostName} reach the gift goal!',
                current: live.metadata?['giftGoalCurrent'] as int? ?? 7,
                target: live.metadata?['giftGoalTarget'] as int? ?? 8,
                onSend: () {
                  final rose = MockGiftCatalog.byId('gift_rose');
                  if (rose != null) {
                    ref.read(activeLiveProvider.notifier).sendGift(rose);
                  }
                },
                onClose: () => setState(() => _giftGoalDismissed = true),
              ),
            ),

          // Floating gifts / hearts
          if (widget.isActive && isThisRoom) ...[
            FloatingGiftsLayer(
              recentGifts: ui.recentGifts,
              activeGift: ui.activeGiftAnimation,
              onAnimationComplete: () =>
                  ref.read(activeLiveProvider.notifier).clearGiftAnimation(),
            ),
            FloatingHeartsOverlay(
              burst: ui.floatingHeartBurst,
              onConsumed: () =>
                  ref.read(activeLiveProvider.notifier).consumeHeartBurst(),
            ),
            ..._tapHearts,
          ],

          // Bottom action bar — raised to match reference
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TikTokLiveBottomBar(
              onTypeTap: () => setState(() => _showComposer = true),
              onGiftTap: () => _openGifts(ui.session?.coinBalance ?? 1250),
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
                      enabled: connected,
                      onSend: (text) {
                        ref.read(activeLiveProvider.notifier).sendComment(text);
                        setState(() => _showComposer = false);
                      },
                    )
                  : null,
            ),
          ),

          if (widget.isActive && isThisRoom)
            LiveStateOverlay(
              state: ui.connectionState,
              message: ui.session?.errorMessage,
              reconnectAttempt: ui.session?.reconnectAttempt ?? 0,
              onRetry: () => ref.read(activeLiveProvider.notifier).retry(),
              onLeave: widget.onClose,
            ),
        ],
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SideAction({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

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
    // Badges sit just under the PK score bar inside the video pane.
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
                errorWidget: (_, __, ___) => FallbackAvatar(
                  seed: liveId,
                  name: guestName,
                  radius: 36,
                ),
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
    // Left team shows ranks 3→1; right team 1→3 (reference).
    final ranks = isLeft ? const [3, 2, 1] : const [1, 2, 3];

    return Row(
      mainAxisAlignment:
          isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
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
                      child: const Icon(Icons.person,
                          size: 14, color: Colors.white54),
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

  const _GuestChip({
    required this.name,
    this.avatar,
    this.showAdd = false,
  });

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
                  errorWidget: (_, __, ___) => FallbackAvatar(
                    seed: name,
                    name: name,
                    radius: 9,
                  ),
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
