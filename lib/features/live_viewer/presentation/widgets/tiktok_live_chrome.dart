import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/live_entity.dart';
import 'animated_counter.dart';
import 'fallback_media.dart';
import 'tiktok_live_tokens.dart';

/// Viewer LIVE top chrome — host left, LIVE + viewers + close on the right.
class TikTokLiveTopBar extends StatelessWidget {
  final LiveEntity live;
  final List<String> topViewerAvatars;
  final VoidCallback onFollow;
  final VoidCallback onClose;
  final VoidCallback? onViewersTap;
  final VoidCallback? onHourlyRankTap;
  final VoidCallback? onLeagueTap;

  const TikTokLiveTopBar({
    super.key,
    required this.live,
    required this.topViewerAvatars,
    required this.onFollow,
    required this.onClose,
    this.onViewersTap,
    this.onHourlyRankTap,
    this.onLeagueTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TikTokLiveTokens.topInsetH,
          TikTokLiveTokens.topInsetV,
          TikTokLiveTokens.topInsetH,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _HostIdentity(live: live, onFollow: onFollow),
                    ),
                  ),
                  const _LiveBadge(),
                  const SizedBox(width: 6),
                  _ViewerEyePill(
                    viewerCount: live.viewerCount,
                    onTap: onViewersTap,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: TikTokLiveTokens.closeIcon,
                      height: TikTokLiveTokens.closeIcon,
                      child: Center(
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                          shadows: TikTokLiveTokens.glyphShadow,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _BadgeRow(
              live: live,
              onHourlyRankTap: onHourlyRankTap,
              onLeagueTap: onLeagueTap,
            ),
            const SizedBox(height: TikTokLiveTokens.badgeGapBelow),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TikTokLiveTokens.liveRed,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ViewerEyePill extends StatelessWidget {
  const _ViewerEyePill({required this.viewerCount, this.onTap});

  final int viewerCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xCC2A2A2E),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.remove_red_eye_outlined,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 4),
            AnimatedCounter(
              value: viewerCount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Host avatar + name — tap follows (mockup has no Follow chip).
class _HostIdentity extends StatelessWidget {
  final LiveEntity live;
  final VoidCallback onFollow;

  const _HostIdentity({required this.live, required this.onFollow});

  @override
  Widget build(BuildContext context) {
    final hostName = live.hostName.trim();
    return GestureDetector(
      onTap: onFollow,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: TikTokLiveTokens.hostAvatar,
              height: TikTokLiveTokens.hostAvatar,
              child: CachedNetworkImage(
                imageUrl: live.hostAvatar ?? '',
                fit: BoxFit.cover,
                placeholder: (_, _) => FallbackAvatar(
                  seed: live.hostId,
                  name: live.hostName,
                  radius: TikTokLiveTokens.hostAvatar / 2,
                ),
                errorWidget: (_, _, _) => FallbackAvatar(
                  seed: live.hostId,
                  name: live.hostName,
                  radius: TikTokLiveTokens.hostAvatar / 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              hostName,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TikTokLiveTokens.hostName,
            ),
          ),
          if (!live.isFollowing) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onFollow,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: TikTokLiveTokens.followRed,
                  borderRadius: BorderRadius.circular(TikTokLiveTokens.followR),
                ),
                child: Text(
                  AppLocalizations.of(context)?.liveFollow ?? 'Follow',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final LiveEntity live;
  final VoidCallback? onHourlyRankTap;
  final VoidCallback? onLeagueTap;

  const _BadgeRow({required this.live, this.onHourlyRankTap, this.onLeagueTap});

  /// Every pill here is backed by real room metadata. Anything the backend has
  /// not sent stays off the chrome rather than falling back to a stand-in
  /// number, so the row never claims a rank or a goal the room does not have.
  @override
  Widget build(BuildContext context) {
    final meta = live.metadata;
    final rawRank = meta?['hourlyRank'];
    final rank = rawRank is num
        ? rawRank.toInt()
        : int.tryParse(rawRank?.toString() ?? '');
    final location = meta?['location']?.toString().trim();
    final rawGoalProgress = meta?['goalProgress']?.toString().trim();
    final goalCurrent = meta?['giftGoalCurrent'];
    final goalTarget = meta?['giftGoalTarget'];
    final goalProgress = rawGoalProgress != null && rawGoalProgress.isNotEmpty
        ? rawGoalProgress
        : (meta?['showGiftGoal'] == true &&
                  goalCurrent != null &&
                  goalTarget != null
              ? '$goalCurrent/$goalTarget'
              : null);
    final leagueTier = meta?['hostLeagueTier']?.toString().trim();
    final isPopular = meta?['isPopular'] == true;
    final popularReason = meta?['popularReason']?.toString();
    final locationLabel =
        location == null || location.isEmpty || location.toLowerCase() == 'live'
        ? null
        : location;

    final leading = <Widget>[
      if (leagueTier != null && leagueTier.isNotEmpty)
        GestureDetector(
          onTap: onLeagueTap,
          child: _LeagueTierBadge(tier: leagueTier),
        ),
      if (rank != null)
        GestureDetector(
          onTap: onHourlyRankTap,
          child: _HourlyRankPill(rank: rank),
        ),
      if (goalProgress != null && goalProgress.isNotEmpty)
        _GiftGoalPill(progress: goalProgress),
      if (locationLabel != null) _RankPill(label: locationLabel),
    ];

    return SizedBox(
      height: TikTokLiveTokens.badgeH,
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          // Leading pills scroll on narrow phones; the league standing keeps
          // the opposite edge the way the reference chrome splits them.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  for (var i = 0; i < leading.length; i++) ...[
                    if (i > 0) const SizedBox(width: TikTokLiveTokens.badgeGap),
                    leading[i],
                  ],
                ],
              ),
            ),
          ),
          if (isPopular) ...[
            const SizedBox(width: TikTokLiveTokens.badgeGap),
            _PopularityBadge(reason: popularReason),
          ],
        ],
      ),
    );
  }
}

/// Hourly ranking pill — a compact frosted badge with a real rank.
class _HourlyRankPill extends StatelessWidget {
  final int rank;

  const _HourlyRankPill({required this.rank});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 12,
            color: TikTokLiveTokens.joinGold,
          ),
          const SizedBox(width: 3),
          Text('No.$rank', style: TikTokLiveTokens.badge),
        ],
      ),
    );
  }
}

class _GiftGoalPill extends StatelessWidget {
  final String progress;

  const _GiftGoalPill({required this.progress});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            size: 11,
            color: TikTokLiveTokens.joinGold,
          ),
          const SizedBox(width: 4),
          Text(
            progress,
            style: TikTokLiveTokens.badge.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankPill extends StatelessWidget {
  final String label;

  const _RankPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFC107),
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TikTokLiveTokens.badge.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Popularity badge — rendered only when the backend flags this host as
/// trending. The surface stays frosted so it matches the other top chips.
class _PopularityBadge extends StatelessWidget {
  final String? reason;

  const _PopularityBadge({this.reason});

  @override
  Widget build(BuildContext context) {
    final isBoost = reason == 'admin_boost';
    final iconColor = isBoost
        ? const Color(0xFFB7A5FF)
        : TikTokLiveTokens.hostTagOrange;

    return _Pill(
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 13, color: iconColor),
          const SizedBox(width: 3),
          Text(
            'Popular',
            style: TikTokLiveTokens.badge.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// League tier pill — shows host's `hostLeagueTier` (e.g. B2, A1, S+)
/// pulled from the backend `user` object.  Colored by tier letter.
class _LeagueTierBadge extends StatelessWidget {
  final String tier;

  const _LeagueTierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final t = tier.trim().toUpperCase();
    final Color color;
    if (t.startsWith('S')) {
      color = const Color(0xFFFFB800);
    } else if (t.startsWith('A')) {
      color = const Color(0xFFFF5A8A);
    } else if (t.startsWith('B')) {
      color = const Color(0xFF3D7EFF);
    } else if (t.startsWith('C')) {
      color = const Color(0xFF27C26F);
    } else {
      color = const Color(0xFF9AA0A6);
    }

    return _Pill(
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.diamond_rounded, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            t.isEmpty ? 'Tier' : 'League · $t',
            style: TikTokLiveTokens.badge.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;

  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: TikTokLiveTokens.badgeH,
      padding: const EdgeInsets.symmetric(
        horizontal: TikTokLiveTokens.badgePadH - 1,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TikTokLiveTokens.badgeBg(0.42),
        borderRadius: BorderRadius.circular(TikTokLiveTokens.badgeR),
      ),
      child: child,
    );
  }
}

/// PK battle score bar — TikTok Match style.
///
/// The seam starts at **50/50** and slides as [scoreLeft] / [scoreRight]
/// change (gift points from `liveBattle`). Scores and the split both animate.
class PkBattleBar extends StatefulWidget {
  final int scoreLeft;
  final int scoreRight;

  /// Marker that rides the seam between the two sides.
  final String seamMarker;

  const PkBattleBar({
    super.key,
    required this.scoreLeft,
    required this.scoreRight,
    this.seamMarker = '😘',
  });

  static const double _height = 20;

  static double ratioFor(int scoreLeft, int scoreRight) {
    final total = scoreLeft + scoreRight;
    if (total <= 0) return 0.5;
    // Keep a readable sliver for the trailing side in a blowout.
    return (scoreLeft / total).clamp(0.08, 0.92);
  }

  static String _fmt(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$value';
  }

  static const TextStyle _scoreStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 12,
    height: 1,
    shadows: [
      Shadow(color: Color(0x73000000), blurRadius: 2, offset: Offset(0, 0.5)),
    ],
  );

  @override
  State<PkBattleBar> createState() => _PkBattleBarState();
}

class _PkBattleBarState extends State<PkBattleBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _ratioAnim;
  late Animation<double> _leftScoreAnim;
  late Animation<double> _rightScoreAnim;

  double _ratio = 0.5;
  double _displayLeft = 0;
  double _displayRight = 0;

  @override
  void initState() {
    super.initState();
    _ratio = PkBattleBar.ratioFor(widget.scoreLeft, widget.scoreRight);
    _displayLeft = widget.scoreLeft.toDouble();
    _displayRight = widget.scoreRight.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _ratioAnim = AlwaysStoppedAnimation(_ratio);
    _leftScoreAnim = AlwaysStoppedAnimation(_displayLeft);
    _rightScoreAnim = AlwaysStoppedAnimation(_displayRight);
    _controller.addListener(() {
      setState(() {
        _ratio = _ratioAnim.value;
        _displayLeft = _leftScoreAnim.value;
        _displayRight = _rightScoreAnim.value;
      });
    });
  }

  @override
  void didUpdateWidget(covariant PkBattleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scoreLeft == widget.scoreLeft &&
        oldWidget.scoreRight == widget.scoreRight) {
      return;
    }
    final nextRatio = PkBattleBar.ratioFor(widget.scoreLeft, widget.scoreRight);
    _ratioAnim = Tween<double>(
      begin: _ratio,
      end: nextRatio,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _leftScoreAnim = Tween<double>(
      begin: _displayLeft,
      end: widget.scoreLeft.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _rightScoreAnim = Tween<double>(
      begin: _displayRight,
      end: widget.scoreRight.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller
      ..stop()
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `seamX` is from the left edge — force LTR so Arabic locale does not
    // mirror the Row while the glow stays unmirrored.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: PkBattleBar._height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final leftW = width * _ratio;
            final seamX = leftW;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Pink (left / host) fills from 0 → seam.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: leftW,
                  child: const DecoratedBox(
                    key: ValueKey('pk-left-score-fill'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF2D55), Color(0xFFFF5C8A)],
                      ),
                    ),
                  ),
                ),
                // Cyan (right / opponent) fills from seam → end.
                Positioned(
                  left: leftW,
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF20E0F0), Color(0xFF25F4EE)],
                      ),
                    ),
                  ),
                ),
                // Soft joint glow at the moving seam.
                Positioned(
                  left: seamX - 10,
                  top: 0,
                  bottom: 0,
                  width: 20,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x88FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      PkBattleBar._fmt(_displayLeft.round()),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: PkBattleBar._scoreStyle,
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      PkBattleBar._fmt(_displayRight.round()),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: PkBattleBar._scoreStyle,
                    ),
                  ),
                ),
                Positioned(
                  left: seamX - 10,
                  top: -5,
                  width: 20,
                  child: Text(
                    widget.seamMarker,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Viewer LIVE bottom chrome:
/// quick reactions (Hello + emojis) above a bordered Comment field + like.
class TikTokLiveBottomBar extends StatelessWidget {
  final VoidCallback onTypeTap;
  final VoidCallback onGiftTap;
  final VoidCallback onShareTap;
  final VoidCallback? onCoinTap;
  final VoidCallback? onTreasureTap;
  final VoidCallback? onRoseTap;
  final VoidCallback? onMultiGuestTap;
  final VoidCallback? onEmojiTap;
  final VoidCallback? onLikeTap;
  final ValueChanged<String>? onQuickReact;
  final int? shareCount;
  final Widget? commentField;

  const TikTokLiveBottomBar({
    super.key,
    required this.onTypeTap,
    required this.onGiftTap,
    required this.onShareTap,
    this.onCoinTap,
    this.onTreasureTap,
    this.onRoseTap,
    this.onMultiGuestTap,
    this.onEmojiTap,
    this.onLikeTap,
    this.onQuickReact,
    this.shareCount,
    this.commentField,
  });

  static const _quickEmojis = ['😂', '😍', '😮', '🔥', '👏', '❤️'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TikTokLiveTokens.bottomInsetH,
          0,
          TikTokLiveTokens.bottomInsetH,
          TikTokLiveTokens.bottomInsetV,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (commentField == null) ...[
                _QuickReactionsBar(
                  emojis: _quickEmojis,
                  onHello: () => onQuickReact?.call('Hello 👋'),
                  onEmoji: (e) => onQuickReact?.call(e),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: commentField == null
                          ? GestureDetector(
                              onTap: onTypeTap,
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: const Color(0xCC1C1C1E),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  'Comment',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                          : Align(
                              alignment: Alignment.bottomCenter,
                              child: commentField,
                            ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onLikeTap ?? onTypeTap,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 40,
                        height: 42,
                        child: Center(
                          child: Icon(
                            Icons.favorite_border_rounded,
                            color: Colors.white,
                            size: 28,
                            shadows: TikTokLiveTokens.glyphShadow,
                          ),
                        ),
                      ),
                    ),
                    if (onMultiGuestTap != null) ...[
                      const SizedBox(width: 4),
                      _BottomAction(
                        onTap: onMultiGuestTap!,
                        scrim: true,
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 24,
                          shadows: TikTokLiveTokens.glyphShadow,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    _BottomAction(
                      onTap: onShareTap,
                      scrim: true,
                      child: const Icon(Icons.reply_rounded, color: Colors.white, size: 26),
                    ),
                    if (onRoseTap != null) ...[
                      const SizedBox(width: 4),
                      _BottomAction(onTap: onRoseTap!, scrim: true,
                        child: const Text('🌹', style: TextStyle(fontSize: 24))),
                    ],
                    const SizedBox(width: 4),
                    _BottomAction(
                      onTap: onGiftTap,
                      scrim: true,
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        color: TikTokLiveTokens.giftPink,
                        size: 26,
                        shadows: TikTokLiveTokens.glyphShadow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickReactionsBar extends StatelessWidget {
  const _QuickReactionsBar({
    required this.emojis,
    required this.onHello,
    required this.onEmoji,
  });

  final List<String> emojis;
  final VoidCallback onHello;
  final ValueChanged<String> onEmoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onHello,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Hello',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.white.withValues(alpha: 0.35),
          ),
          for (final emoji in emojis)
            GestureDetector(
              onTap: () => onEmoji(emoji),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.onTap,
    required this.child,
    this.scrim = false,
  });

  final VoidCallback onTap;
  final Widget child;

  /// TikTok gives the action controls a quiet circular scrim over live video.
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: TikTokLiveTokens.bottomHit,
        height: TikTokLiveTokens.inputH,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (scrim)
              Container(
                width: TikTokLiveTokens.bottomScrimDisc,
                height: TikTokLiveTokens.bottomScrimDisc,
                decoration: BoxDecoration(
                  color: TikTokLiveTokens.frost(0.28),
                  shape: BoxShape.circle,
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
