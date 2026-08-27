import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/extensions.dart';
import '../../domain/entities/live_entity.dart';
import 'animated_counter.dart';
import 'fallback_media.dart';
import 'tiktok_live_tokens.dart';

/// TikTok LIVE top chrome — matched to attached LIVE screenshots (LTR).
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
                Flexible(
                  child: _HostPill(live: live, onFollow: onFollow),
                ),
                const SizedBox(width: 6),
                _ViewerCountPill(
                  avatars: topViewerAvatars,
                  viewerCount: live.viewerCount,
                  onTap: onViewersTap,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: TikTokLiveTokens.closeIcon,
                    height: TikTokLiveTokens.closeIcon,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
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
    return Container(
      height: TikTokLiveTokens.hostPillH,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(TikTokLiveTokens.hostPillR),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
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
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live.hostName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      live.likeCount.formatNumber,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Screenshots: white heart next to like count
                    Icon(
                      Icons.favorite_rounded,
                      size: 10,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onFollow,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: TikTokLiveTokens.followH,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: live.isFollowing
                    ? Colors.white.withValues(alpha: 0.18)
                    : const Color(0xFFFE2C55),
                borderRadius: BorderRadius.circular(TikTokLiveTokens.followR),
                border: live.isFollowing
                    ? Border.all(color: Colors.white.withValues(alpha: 0.24))
                    : null,
              ),
              child: live.isFollowing
                  ? const Text(
                      'Following',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 13),
                        SizedBox(width: 1),
                        Text(
                          'Follow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
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

  static const _badges = ['+100', '+10', '9'];

  @override
  Widget build(BuildContext context) {
    final shown = avatars.take(3).toList();
    final stackW = shown.isEmpty ? 0.0 : 22.0 + (shown.length - 1) * 14.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedCounter(
              value: viewerCount,
              compact: viewerCount > 999,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            if (shown.isNotEmpty) ...[
              const SizedBox(width: 5),
              SizedBox(
                width: stackW + 8,
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: List.generate(shown.length, (i) {
                    final badge = i < _badges.length ? _badges[i] : null;
                    return Positioned(
                      left: i * 14.0,
                      child: SizedBox(
                        width: 22,
                        height: 24,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  width: 1,
                                ),
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: shown[i],
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Container(
                                    color: const Color(0xFF333333),
                                    child: const Icon(
                                      Icons.person,
                                      size: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (badge != null && i < 2)
                              Positioned(
                                right: -4,
                                bottom: -1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2.5,
                                    vertical: 0.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == 0
                                        ? const Color(0xFFFFB020)
                                        : const Color(0xFF3D7EFF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 7,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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

  @override
  Widget build(BuildContext context) {
    final rank = live.metadata?['hourlyRank'] as int? ?? 12;
    final location = live.metadata?['location'] as String? ?? 'LIVE';
    final goalProgress = live.metadata?['goalProgress'] as String?;
    final isPopular = live.metadata?['isPopular'] == true;
    final popularReason = live.metadata?['popularReason'] as String?;
    final leagueTier = live.metadata?['hostLeagueTier'] as String?;
    final hostHearts = live.metadata?['hostHeartCount'] as int? ?? 0;
    final host = (
      isPopular: isPopular,
      popularReason: popularReason,
      leagueTier: leagueTier,
      hostHearts: hostHearts,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          if (host.isPopular) ...[
            _PopularityBadge(reason: host.popularReason),
            const SizedBox(width: 4),
          ],
          GestureDetector(
            onTap: onHourlyRankTap,
            child: _Pill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(
                    'Hourly ranking',
                    style: TextStyle(
                      color: Colors.amber.shade100,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          _Pill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  goalProgress ?? '1/0',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'Gallery',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onLeagueTap,
            child: _Pill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFC107),
                    size: 11,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'No.$rank · $location',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (host.leagueTier != null) ...[
            const SizedBox(width: 4),
            _LeagueTierBadge(tier: host.leagueTier!),
          ],
        ],
      ),
    );
  }
}

/// Popularity badge — rendered if the backend flagged this host as trending.
/// Uses `popularReason` to pick glyph + tint:
///  - `admin_boost`  → rocket / royal purple (staff promoted).
///  - `hourly_rank`  (or null) → fire / gradient (organic trending).
class _PopularityBadge extends StatelessWidget {
  final String? reason;

  const _PopularityBadge({this.reason});

  @override
  Widget build(BuildContext context) {
    final isBoost = reason == 'admin_boost';
    final icon = isBoost ? '🚀' : '⭐';
    const label = 'Popular';
    final gradient = isBoost
        ? const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFFFF6BD6)])
        : const LinearGradient(colors: [Color(0xFFFF5A3F), Color(0xFFFFC371)]);

    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
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

    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Text(
        t.isEmpty ? 'Tier' : 'League · $t',
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
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
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

/// PK battle score bar — TikTok layout.
///
/// Reference (TikTok LIVE battle): one full-width split bar, each side's score
/// sitting at its own outer edge in white, and the seam marker riding the split
/// rather than parked at an edge. The centre of the bar is left empty on
/// purpose: TikTok puts the round countdown there, and the previous
/// "Win to get 2x points" capsule was occupying that slot and colliding with
/// the timer the room already renders just below.
class PkBattleBar extends StatelessWidget {
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

  static const double _barHeight = 22;

  /// Neither side's colour is ever fully squeezed out, so the bar still reads
  /// as a contest when one room is running away with it (TikTok keeps a sliver).
  static const double _minShare = 0.06;

  static String _fmt(int n) {
    if (n < 1000) return '$n';
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = (scoreLeft + scoreRight).clamp(1, 1 << 30);
    final target = (scoreLeft / total).clamp(_minShare, 1 - _minShare);

    // `seamX` is measured from the left edge, so the two sides must be laid
    // out from the left edge too. Under Arabic the Row mirrored while the
    // seam glow did not, and the bar came apart.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: _barHeight,
        // A score arriving as a socket event should slide the seam, not snap it.
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: target, end: target),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, ratio, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final seamX = constraints.maxWidth * ratio;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: (ratio * 1000).round(),
                          child: _Side(
                            score: scoreLeft,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 10),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF2D55), Color(0xFFFF5C8A)],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: ((1 - ratio) * 1000).round(),
                          child: _Side(
                            score: scoreRight,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 10),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF20E0F0), Color(0xFF25F4EE)],
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Soft joint glow, the way the two colours meet on TikTok.
                    Positioned(
                      left: seamX - 9,
                      top: 0,
                      bottom: 0,
                      width: 18,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x00FFFFFF),
                              Color(0x66FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: seamX - 10,
                      top: -4,
                      width: 20,
                      child: Text(
                        seamMarker,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.score,
    required this.alignment,
    required this.padding,
    required this.gradient,
  });

  final int score;
  final Alignment alignment;
  final EdgeInsets padding;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(gradient: gradient),
      child: Text(
        PkBattleBar._fmt(score),
        maxLines: 1,
        overflow: TextOverflow.clip,
        // Both sides are white on TikTok. The cyan side used to be black87,
        // which read as a disabled score next to the pink one.
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          height: 1,
          shadows: [
            Shadow(
              color: Color(0x66000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// TikTok LIVE viewer bottom bar (LTR):
/// TikTok LIVE viewer bottom bar (LTR):
/// [Write…] [emoji] [multi-guest] [rose] [gift] [share]
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
                child:
                    commentField ??
                    GestureDetector(
                      onTap: onTypeTap,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          'Type...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
              ),
              const SizedBox(width: 6),
              _BottomAction(
                onTap: onEmojiTap ?? onTypeTap,
                child: const Icon(
                  Icons.emoji_emotions_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              if (onMultiGuestTap != null) ...[
                const SizedBox(width: 5),
                _BottomAction(
                  onTap: onMultiGuestTap!,
                  child: const _GuestActionGlyph(),
                ),
              ],
              if (onRoseTap != null) ...[
                const SizedBox(width: 5),
                _BottomAction(
                  onTap: onRoseTap!,
                  child: const Text('🌹', style: TextStyle(fontSize: 23)),
                ),
              ],
              const SizedBox(width: 5),
              _BottomAction(
                onTap: onGiftTap,
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFFFF5B87),
                  size: 23,
                ),
              ),
              const SizedBox(width: 5),
              _BottomAction(
                onTap: onShareTap,
                badge: shareCount != null && shareCount! > 0
                    ? (shareCount! > 999 ? '999+' : '$shareCount')
                    : null,
                child: Transform.flip(
                  flipX: true,
                  child: const Icon(
                    Icons.reply_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.onTap, required this.child, this.badge});

  final VoidCallback onTap;
  final Widget child;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 1,
              top: 1,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.48),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: child,
              ),
            ),
            if (badge != null)
              Positioned(
                right: -2,
                bottom: -1,
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
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
      width: 27,
      height: 24,
      child: Stack(
        children: [
          Positioned(
            left: 1,
            bottom: 1,
            child: Icon(Icons.person, color: Color(0xFF25F4EE), size: 20),
          ),
          Positioned(
            right: 0,
            bottom: 1,
            child: Icon(Icons.person, color: Color(0xFFFF2D55), size: 20),
          ),
        ],
      ),
    );
  }
}
