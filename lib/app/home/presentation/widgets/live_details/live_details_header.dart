import 'dart:ui';

import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_status_badge.dart';

class LiveDetailsHeader extends StatelessWidget {
  const LiveDetailsHeader({
    required this.hostName,
    this.subtitle,
    required this.viewersLabel,
    this.avatarUrl,
    required this.isFollowing,
    required this.followLabel,
    required this.followingLabel,
    required this.liveBadgeLabel,
    this.isAuctionActiveBadge = false,
    this.isAuctionFinishedBadge = false,
    required this.pulseAnimation,
    this.showCloseButton = true,
    this.showAuctionGifts = false,
    this.onAuctionGifts,
    this.showOwnerMenu = false,
    this.onOwnerMenu,
    this.countdownBelowProfile,
    required this.onClose,
    required this.onFollowTap,
  });

  final String hostName;
  final String? subtitle;
  final String viewersLabel;
  final String? avatarUrl;
  final bool isFollowing;
  final String followLabel;
  final String followingLabel;
  final String liveBadgeLabel;
  final bool isAuctionActiveBadge;
  final bool isAuctionFinishedBadge;
  final Animation<double> pulseAnimation;
  final bool showCloseButton;
  final bool showAuctionGifts;
  final VoidCallback? onAuctionGifts;
  final bool showOwnerMenu;
  final VoidCallback? onOwnerMenu;
  final Widget? countdownBelowProfile;
  final VoidCallback onClose;
  final VoidCallback onFollowTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final profileCard = ClipRRect(
      borderRadius: BorderRadius.circular(
        LiveDetailsLayoutConstants.headerGlassRadius,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          decoration: BoxDecoration(
            color: LiveDetailsLayoutConstants.glassFill,
            borderRadius: BorderRadius.circular(
              LiveDetailsLayoutConstants.headerGlassRadius,
            ),
            border: Border.all(color: LiveDetailsLayoutConstants.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProfileAvatar(avatarUrl: avatarUrl),
              const SizedBox(width: AppSizes.p8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hostName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle != null && subtitle!.isNotEmpty
                          ? subtitle!
                          : viewersLabel,
                      style: TextStyle(
                        color: subtitle != null && subtitle!.isNotEmpty
                            ? Colors.amberAccent
                            : Colors.white70,
                        fontSize: 10,
                        fontWeight: subtitle != null && subtitle!.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.p8),
              GestureDetector(
                onTap: onFollowTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p10,
                    vertical: AppSizes.p6,
                  ),
                  decoration: BoxDecoration(
                    color: isFollowing
                        ? Colors.white.withValues(alpha: 0.2)
                        : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isFollowing ? followingLabel : followLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                profileCard,
                if (countdownBelowProfile != null) ...[
                  const SizedBox(height: AppSizes.p6),
                  countdownBelowProfile!,
                ],
              ],
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showAuctionGifts && onAuctionGifts != null)
                    IconButton(
                      onPressed: onAuctionGifts,
                      icon: const Icon(
                        LucideIcons.gift,
                        color: LiveDetailsLayoutConstants.giftCommentGold,
                        size: LiveDetailsLayoutConstants.closeIconSize,
                      ),
                    ),
                  if (showOwnerMenu && onOwnerMenu != null)
                    IconButton(
                      onPressed: onOwnerMenu,
                      icon: const Icon(
                        LucideIcons.ellipsis,
                        color: Colors.white,
                        size: LiveDetailsLayoutConstants.closeIconSize,
                      ),
                    ),
                  if (showCloseButton)
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(
                        LucideIcons.x,
                        color: Colors.white,
                        size: LiveDetailsLayoutConstants.closeIconSize,
                      ),
                    ),
                ],
              ),
              LiveStatusBadge(
                label: liveBadgeLabel,
                isAuctionActive: isAuctionActiveBadge,
                isAuctionFinished: isAuctionFinishedBadge,
                pulseAnimation: pulseAnimation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final radius = LiveDetailsLayoutConstants.headerAvatarRadius;
    final url = avatarUrl?.trim();
    final hasImage =
        url != null && url.isNotEmpty && MediaUtils.isImage(url);

    if (!hasImage) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        child: Icon(
          LucideIcons.user,
          size: radius,
          color: Colors.white70,
        ),
      );
    }

    final size = radius * 2;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          MediaUtils.resolveAbsoluteUrl(url),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(
            color: Colors.white.withValues(alpha: 0.12),
            child: Icon(
              LucideIcons.user,
              size: radius,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
