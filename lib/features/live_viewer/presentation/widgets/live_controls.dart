import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'animated_counter.dart';
import 'fallback_media.dart';

/// TikTok LIVE right-rail actions: profile, like, gift, share.
class LiveControls extends StatelessWidget {
  final String hostAvatar;
  final String hostId;
  final String hostName;
  final int likeCount;
  final VoidCallback onLikeTap;
  final VoidCallback onGiftTap;
  final VoidCallback onShareTap;
  final VoidCallback onProfileTap;
  final AnimationController likeController;

  const LiveControls({
    super.key,
    required this.hostAvatar,
    required this.hostId,
    required this.hostName,
    required this.likeCount,
    required this.onLikeTap,
    required this.onGiftTap,
    required this.onShareTap,
    required this.onProfileTap,
    required this.likeController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onProfileTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: hostAvatar,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    FallbackAvatar(seed: hostId, name: hostName, radius: 24),
                errorWidget: (_, __, ___) =>
                    FallbackAvatar(seed: hostId, name: hostName, radius: 24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _ControlButton(
          icon: Icons.favorite,
          color: AppColors.secondary,
          onTap: onLikeTap,
          animationController: likeController,
          badgeWidget: AnimatedCounter(
            value: likeCount,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 16),
        _ControlButton(
          icon: Icons.card_giftcard_rounded,
          color: AppColors.coinGold,
          onTap: onGiftTap,
          badge: 'Gift',
        ),
        const SizedBox(height: 16),
        _ControlButton(
          icon: Icons.share_rounded,
          color: Colors.white,
          onTap: onShareTap,
          badge: 'Share',
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final AnimationController? animationController;
  final String? badge;
  final Widget? badgeWidget;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.animationController,
    this.badge,
    this.badgeWidget,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          badgeWidget ??
              Text(
                badge ?? '',
                style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
              ),
        ],
      ),
    );

    if (animationController != null) {
      button = AnimatedBuilder(
        animation: animationController!,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (animationController!.value * 0.22),
            child: child,
          );
        },
        child: button,
      );
    }

    return button;
  }
}
