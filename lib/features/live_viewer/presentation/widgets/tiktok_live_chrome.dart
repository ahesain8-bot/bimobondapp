import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/extensions.dart';
import '../../domain/entities/live_entity.dart';
import 'animated_counter.dart';
import 'fallback_media.dart';
import 'tiktok_live_tokens.dart';

/// TikTok LIVE top chrome — matched to the supplied LIVE screenshots.
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
            Row(
              textDirection: TextDirection.ltr,
              children: [
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: TikTokLiveTokens.closeIcon,
                    height: TikTokLiveTokens.closeIcon,
                    child: const Center(
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                        shadows: TikTokLiveTokens.glyphShadow,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _ViewerCountPill(
                  avatars: topViewerAvatars,
                  viewerCount: live.viewerCount,
                  onTap: onViewersTap,
                ),
                const SizedBox(width: 8),
                // Expanded, not Spacer + Flexible: a Spacer claims an equal
                // share of the free width, which leaves the pill less than its
                // avatar and follow button need and collapses the host name to
                // a single glyph.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _HostPill(live: live, onFollow: onFollow),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _BadgeRow(
              live: live,
              onHourlyRankTap: onHourlyRankTap,
              onLeagueTap: onLeagueTap,
            ),
            // Spacer reserved so chrome doesn't paint into the media gap;
            // actual gap height is applied via headerBottom in LiveRoomPage.
            const SizedBox(height: TikTokLiveTokens.badgeGapBelow),
          ],
        ),
      ),
    );
  }
}

class _HostPill extends StatelessWidget {
  final LiveEntity live;
  final VoidCallback onFollow;

  const _HostPill({required this.live, required this.onFollow});

  @override
  Widget build(BuildContext context) {
    final hostName = live.hostName.trim();
    return Container(
      height: TikTokLiveTokens.hostPillH,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: TikTokLiveTokens.frost(0.34),
        borderRadius: BorderRadius.circular(TikTokLiveTokens.hostPillR),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(width: TikTokLiveTokens.hostAvatarGap),
          // No fixed cap here: the name takes the width the row actually has
          // and only ellipsizes once it runs out.
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hostName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TikTokLiveTokens.hostName,
                ),
                const SizedBox(height: 1),
                // Screenshots put a white heart right after the like count.
                // Inlined as one run so a long host name or a large text
                // scale clips it instead of overflowing the capsule.
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: live.likeCount.formatNumber),
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(start: 3),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 9.5,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TikTokLiveTokens.likeCount,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onFollow,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              height: TikTokLiveTokens.followH,
              padding: EdgeInsets.symmetric(
                horizontal: live.isFollowing ? 10 : 9,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: live.isFollowing
                    ? Colors.white.withValues(alpha: 0.16)
                    : TikTokLiveTokens.followRed,
                borderRadius: BorderRadius.circular(TikTokLiveTokens.followR),
              ),
              child: live.isFollowing
                  ? const Text('Following', style: TikTokLiveTokens.follow)
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 2),
                        Text('Follow', style: TikTokLiveTokens.follow),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Viewer count + overlapping avatars inside one frosted pill (screenshot match).
class _ViewerCountPill extends StatelessWidget {
  final List<String> avatars;
  final int viewerCount;
  final VoidCallback? onTap;

  const _ViewerCountPill({
    required this.avatars,
    required this.viewerCount,
    this.onTap,
  });

  /// Centre-to-centre spacing of the overlapping avatar stack.
  static const double _pitch =
      TikTokLiveTokens.viewerAvatar - TikTokLiveTokens.viewerOverlap;

  @override
  Widget build(BuildContext context) {
    const avatar = TikTokLiveTokens.viewerAvatar;
    final shown = avatars.take(3).toList();
    final stackW = shown.isEmpty ? 0.0 : avatar + (shown.length - 1) * _pitch;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 30,
        padding: EdgeInsets.symmetric(horizontal: shown.isEmpty ? 10 : 7),
        decoration: BoxDecoration(
          color: TikTokLiveTokens.frost(0.34),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          textDirection: TextDirection.ltr,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedCounter(
              value: viewerCount,
              compact: viewerCount > 999,
              style: TikTokLiveTokens.viewerCount,
            ),
            if (shown.isNotEmpty) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: stackW,
                height: avatar,
                child: Stack(
                  children: List.generate(shown.length, (i) {
                    return Positioned(
                      left: i * _pitch,
                      child: Container(
                        width: avatar,
                        height: avatar,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2A2A2E),
                          border: Border.all(
                            color: const Color(0xFF161823),
                            width: TikTokLiveTokens.viewerBorder,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: shown[i],
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const Icon(
                              Icons.person,
                              size: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
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

/// PK battle score bar — full-bleed split with the reference's diagonal seam
/// and each side's score pinned to its own outer edge.
class PkBattleBar extends StatelessWidget {
  final int scoreLeft;
  final int scoreRight;

  const PkBattleBar({
    super.key,
    required this.scoreLeft,
    required this.scoreRight,
  });

  static const double _height = 18;

  @override
  Widget build(BuildContext context) {
    final total = (scoreLeft + scoreRight).clamp(1, 1 << 30);
    // Each side keeps a sliver even in a blowout so both scores stay readable.
    final ratio = (scoreLeft / total).clamp(0.08, 0.92);

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: ratio),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _PkSplitPainter(ratio: value)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Row(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(scoreLeft), style: _scoreStyle),
                    Text(_fmt(scoreRight), style: _scoreStyle),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
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

  static String _fmt(int n) {
    if (n >= 1000) {
      return n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return '$n';
  }
}

class _PkSplitPainter extends CustomPainter {
  const _PkSplitPainter({required this.ratio});

  final double ratio;

  static const List<Color> _left = [Color(0xFFFF2D55), Color(0xFFFF6E9C)];
  static const List<Color> _right = [Color(0xFF2BE7F2), Color(0xFF11B4D2)];

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final split = size.width * ratio;
    final slant = size.height * 0.6;

    canvas.save();
    canvas.clipRect(bounds);

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(colors: _right).createShader(bounds),
    );

    final leftEdge = Path()
      ..moveTo(0, 0)
      ..lineTo(split + slant / 2, 0)
      ..lineTo(split - slant / 2, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      leftEdge,
      Paint()
        ..shader = const LinearGradient(colors: _left).createShader(bounds),
    );

    canvas.drawLine(
      Offset(split + slant / 2, 0),
      Offset(split - slant / 2, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PkSplitPainter oldDelegate) => oldDelegate.ratio != ratio;
}

/// TikTok LIVE viewer bottom bar.
///
/// The composer owns the emoji affordance. Keeping it in the input gives the
/// text field the same width as the reference while the supported actions stay
/// in their fixed physical order: share, gift, rose, guest.
class TikTokLiveBottomBar extends StatelessWidget {
  final VoidCallback onTypeTap;
  final VoidCallback onGiftTap;
  final VoidCallback onShareTap;
  final VoidCallback? onCoinTap;
  final VoidCallback? onTreasureTap;
  final VoidCallback? onRoseTap;
  final VoidCallback? onMultiGuestTap;
  final VoidCallback? onEmojiTap;
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
    this.shareCount,
    this.commentField,
  });

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
        child: SizedBox(
          height: 42,
          child: Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: commentField == null
                    ? GestureDetector(
                        onTap: onTypeTap,
                        child: Container(
                          height: TikTokLiveTokens.inputH,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: TikTokLiveTokens.frost(0.36),
                            borderRadius: BorderRadius.circular(
                              TikTokLiveTokens.inputR,
                            ),
                          ),
                          child: Row(
                            textDirection: TextDirection.ltr,
                            children: [
                              GestureDetector(
                                onTap: onEmojiTap ?? onTypeTap,
                                behavior: HitTestBehavior.opaque,
                                child: const SizedBox(
                                  width: 24,
                                  height: TikTokLiveTokens.inputH,
                                  child: Center(
                                    child: Icon(
                                      Icons.emoji_emotions_rounded,
                                      color: Colors.white,
                                      size: 22,
                                      shadows: TikTokLiveTokens.glyphShadow,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Type...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign:
                                      Directionality.of(context) ==
                                          TextDirection.rtl
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  textDirection: Directionality.of(context),
                                  style: TikTokLiveTokens.inputHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: commentField,
                      ),
              ),
              const SizedBox(width: 4),
              _BottomAction(
                onTap: onShareTap,
                badge: shareCount != null && shareCount! > 0
                    ? (shareCount! > 999 ? '999+' : '$shareCount')
                    : null,
                scrim: true,
                child: Transform.flip(
                  flipX: true,
                  child: const Icon(
                    Icons.reply_rounded,
                    color: Colors.white,
                    size: TikTokLiveTokens.bottomGlyph,
                    shadows: TikTokLiveTokens.glyphShadow,
                  ),
                ),
              ),
              const SizedBox(width: TikTokLiveTokens.bottomIconGap),
              _BottomAction(
                onTap: onGiftTap,
                scrim: true,
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: TikTokLiveTokens.giftPink,
                  size: TikTokLiveTokens.giftIcon,
                  shadows: TikTokLiveTokens.glyphShadow,
                ),
              ),
              if (onRoseTap != null) ...[
                const SizedBox(width: TikTokLiveTokens.bottomIconGap),
                _BottomAction(
                  onTap: onRoseTap!,
                  scrim: true,
                  child: const Text(
                    '🌹',
                    style: TextStyle(
                      fontSize: 24,
                      shadows: TikTokLiveTokens.glyphShadow,
                    ),
                  ),
                ),
              ],
              if (onMultiGuestTap != null) ...[
                const SizedBox(width: TikTokLiveTokens.bottomIconGap),
                _BottomAction(
                  onTap: onMultiGuestTap!,
                  scrim: true,
                  child: const _GuestActionGlyph(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.onTap,
    required this.child,
    this.badge,
    this.scrim = false,
  });

  final VoidCallback onTap;
  final Widget child;
  final String? badge;

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
                  color: TikTokLiveTokens.frost(0.36),
                  shape: BoxShape.circle,
                ),
              ),
            child,
            if (badge != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    shadows: TikTokLiveTokens.glyphShadow,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuestActionGlyph extends StatelessWidget {
  const _GuestActionGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 24,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 1,
            child: Icon(
              Icons.person,
              color: TikTokLiveTokens.liveCyan,
              size: 21,
              shadows: TikTokLiveTokens.glyphShadow,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 1,
            child: Icon(
              Icons.person,
              color: TikTokLiveTokens.giftPink,
              size: 21,
              shadows: TikTokLiveTokens.glyphShadow,
            ),
          ),
        ],
      ),
    );
  }
}
