import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/utils/extensions.dart';
import '../../domain/entities/live_entity.dart';
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
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(child: _HostPill(live: live, onFollow: onFollow)),
                const SizedBox(width: 6),
                _ViewerCountPill(
                  avatars: topViewerAvatars,
                  viewerCount: live.viewerCount,
                  onTap: onViewersTap,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, color: Colors.white, size: 22),
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
      height: 36,
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CachedNetworkImage(
                imageUrl: live.hostAvatar ?? '',
                fit: BoxFit.cover,
                placeholder: (_, __) => FallbackAvatar(
                  seed: live.hostId,
                  name: live.hostName,
                  radius: 15,
                ),
                errorWidget: (_, __, ___) => FallbackAvatar(
                  seed: live.hostId,
                  name: live.hostName,
                  radius: 15,
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
                      Icons.favorite,
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
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: live.isFollowing
                    ? Colors.white.withValues(alpha: 0.18)
                    : const Color(0xFFFE2C55),
                borderRadius: BorderRadius.circular(12),
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
        height: 28,
        padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              viewerCount > 999
                  ? viewerCount.formatNumber
                  : '$viewerCount',
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
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFF333333),
                                    child: const Icon(Icons.person,
                                        size: 11, color: Colors.white54),
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
                                      horizontal: 2.5, vertical: 0.5),
                                  decoration: BoxDecoration(
                                    color: i == 0
                                        ? const Color(0xFFFFB020)
                                        : const Color(0xFF3D7EFF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.black, width: 0.8),
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

  const _BadgeRow({
    required this.live,
    this.onHourlyRankTap,
    this.onLeagueTap,
  });

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
                  const Icon(Icons.emoji_events,
                      color: Color(0xFFFFC107), size: 11),
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
        ? const LinearGradient(
            colors: [Color(0xFF7B61FF), Color(0xFFFF6BD6)],
          )
        : const LinearGradient(
            colors: [Color(0xFFFF5A3F), Color(0xFFFFC371)],
          );

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
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

/// PK battle score bar — tip capsule overlays the center of the bar.
class PkBattleBar extends StatelessWidget {
  final int scoreLeft;
  final int scoreRight;

  const PkBattleBar({
    super.key,
    required this.scoreLeft,
    required this.scoreRight,
  });

  @override
  Widget build(BuildContext context) {
    final total = (scoreLeft + scoreRight).clamp(1, 1 << 30);
    final leftRatio = scoreLeft / total;

    return SizedBox(
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: (leftRatio * 1000).round().clamp(50, 950),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF2D55), Color(0xFFFF5C8A)],
                          ),
                        ),
                        child: Text(
                          _fmt(scoreLeft),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: ((1 - leftRatio) * 1000).round().clamp(50, 950),
                      child: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 22),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF20E0F0), Color(0xFF25F4EE)],
                          ),
                        ),
                        child: Text(
                          _fmt(scoreRight),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Positioned(
                  right: 2,
                  top: -3,
                  child: Text('😘', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xE60A2430),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.diamond, color: Color(0xFF7EC8FF), size: 11),
                SizedBox(width: 4),
                Text(
                  'Win to get 2x points ›',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
                begin: 0.85,
                end: 1,
                duration: 900.ms,
              ),
        ],
      ),
    );
  }

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

/// Bottom bar matching screenshots:
/// [treasure?][emoji][Write...][share↓count][gift][rose][multi-guest]
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
    // Raised above home indicator to match reference action-bar position.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: SizedBox(
          height: 42,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (onTreasureTap != null) ...[
                GestureDetector(
                  onTap: onTreasureTap,
                  child: const Icon(Icons.inventory_2_rounded,
                      color: Color(0xFFFFB020), size: 26),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: onEmojiTap ?? onTypeTap,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_emotions_outlined,
                      color: Color(0xD9FFFFFF), size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: commentField ??
                    GestureDetector(
                      onTap: onTypeTap,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Write...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onShareTap,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 34,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Transform.flip(
                        flipX: true,
                        child: const Icon(Icons.reply_rounded,
                            color: Colors.white, size: 26),
                      ),
                      if (shareCount != null && shareCount! > 0)
                        Text(
                          shareCount! > 999 ? '999+' : '$shareCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onGiftTap,
                child: const Icon(Icons.card_giftcard,
                    color: Color(0xFFFF2D55), size: 30),
              ),
              if (onRoseTap != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRoseTap,
                  child: const Text('🌹', style: TextStyle(fontSize: 28)),
                ),
              ],
              if (onMultiGuestTap != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onMultiGuestTap,
                  child: SizedBox(
                    width: 32,
                    height: 30,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned(
                          left: 0,
                          top: 4,
                          child: Icon(Icons.person,
                              color: Color(0xFF25F4EE), size: 20),
                        ),
                        const Positioned(
                          right: 0,
                          top: 4,
                          child: Icon(Icons.person,
                              color: Color(0xFFFF2D55), size: 20),
                        ),
                        Positioned(
                          right: -1,
                          top: 0,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3D7EFF),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
