import 'dart:ui';

import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/live_status_badge.dart';

class LiveDetailsHeader extends StatelessWidget {
  const LiveDetailsHeader({
    required this.hostName,
    this.subtitle,
    required this.viewersLabel,
    this.avatarUrl,
    this.hostUserId,
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
    this.showFollowButton = true,
    this.onProfileTap,
    this.countdownBelowProfile,
    required this.onClose,
    required this.onFollowTap,
  });

  final String hostName;
  final String? subtitle;
  final String viewersLabel;
  final String? avatarUrl;
  final String? hostUserId;
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
  final bool showFollowButton;
  final VoidCallback? onProfileTap;
  final Widget? countdownBelowProfile;
  final VoidCallback onClose;
  final VoidCallback onFollowTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final profileCard = ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onProfileTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      StoryProfileAvatar(
                        userId: hostUserId,
                        imageUrl: avatarUrl,
                        radius: 16,
                        fallbackText: hostName,
                        username: hostName,
                        onTap: onProfileTap,
                      ),
                      const SizedBox(width: AppSizes.p10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hostName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.3,
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
                                    : Colors.white.withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight:
                                    subtitle != null && subtitle!.isNotEmpty
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showFollowButton) ...[
                const SizedBox(width: AppSizes.p8),
                _AnimatedFollowButton(
                  isFollowing: isFollowing,
                  followLabel: followLabel,
                  followingLabel: followingLabel,
                  onTap: onFollowTap,
                ),
              ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: AppSizes.p8),
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

class _AnimatedFollowButton extends StatefulWidget {
  const _AnimatedFollowButton({
    required this.isFollowing,
    required this.followLabel,
    required this.followingLabel,
    required this.onTap,
  });

  final bool isFollowing;
  final String followLabel;
  final String followingLabel;
  final VoidCallback onTap;

  @override
  State<_AnimatedFollowButton> createState() => _AnimatedFollowButtonState();
}

class _AnimatedFollowButtonState extends State<_AnimatedFollowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.p6,
          ),
          decoration: BoxDecoration(
            gradient: widget.isFollowing
                ? LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isFollowing
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
            boxShadow: widget.isFollowing
                ? []
                : [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              widget.isFollowing ? widget.followingLabel : widget.followLabel,
              key: ValueKey(widget.isFollowing),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
