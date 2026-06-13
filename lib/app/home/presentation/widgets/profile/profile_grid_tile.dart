import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/post_cover_card.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfileGridTile extends StatelessWidget {
  const ProfileGridTile({
    required this.post,
    required this.tabIndex,
    required this.theme,
    required this.onTap,
    super.key,
  });

  final PostEntity post;
  final int tabIndex;
  final ThemeData theme;
  final VoidCallback onTap;

  bool get _isAuctionPost => post.isAuctionable;

  bool get _isVideoPost {
    if (post.type.toUpperCase() == 'VIDEO') return true;
    return post.media.any(
      (m) => MediaUtils.isVideo(m.url, mediaType: m.mediaType),
    );
  }

  ProfileAuctionStatus _auctionStatus(AppLocalizations l10n) {
    if (!_isAuctionPost) return ProfileAuctionStatus.none;

    final auction = post.auction;
    if (auction == null) {
      return ProfileAuctionStatus(
        label: l10n.profilePostAuction,
        borderColor: LiveDetailsLayoutConstants.giftCommentGold,
        badgeBackground: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
        badgeForeground: Colors.white,
      );
    }

    final now = DateTime.now().toUtc();
    final start = auction.startedAt.toUtc();
    final end = auction.endedAt.toUtc();

    if (now.isAfter(end)) {
      return ProfileAuctionStatus(
        label: l10n.auctionFinishedBadge,
        borderColor: LiveDetailsLayoutConstants.auctionFinishedBadgeColor,
        badgeBackground: LiveDetailsLayoutConstants.auctionFinishedBadgeDark,
        badgeForeground: Colors.white,
      );
    }

    if (now.isBefore(start)) {
      return ProfileAuctionStatus(
        label: l10n.auctionStartsIn,
        borderColor: LiveDetailsLayoutConstants.giftCommentGold,
        badgeBackground: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
        badgeForeground: Colors.white,
      );
    }

    return ProfileAuctionStatus(
      label: l10n.auctionActiveBadge,
      borderColor: LiveDetailsLayoutConstants.auctionActiveBadgeColor,
      badgeBackground: LiveDetailsLayoutConstants.auctionActiveBadgeDark,
      badgeForeground: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auctionStatus = _auctionStatus(l10n);
    final isAuction = _isAuctionPost;
    final itemName = post.auction?.itemName;
    final radius = ProfileLayoutConstants.gridItemRadius;
    final borderRadius = BorderRadius.circular(radius);
    final showViewCount = _isVideoPost && !isAuction;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PostCoverCard(
              post: post,
              tabIndex: tabIndex,
              theme: theme,
              showCenterPlayIcon: false,
            ),
            if (showViewCount)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x99000000)],
                    ),
                  ),
                ),
              ),
            if (isAuction)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
            if (isAuction)
              Positioned(
                top: AppSizes.p6,
                left: AppSizes.p6,
                child: ProfileAuctionBadge(status: auctionStatus),
              ),
            if (isAuction && itemName != null && itemName.isNotEmpty)
              Positioned(
                left: AppSizes.p6,
                right: AppSizes.p6,
                bottom: AppSizes.p6,
                child: Text(
                  itemName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            if (showViewCount)
              Positioned(
                left: AppSizes.p6,
                bottom: AppSizes.p6,
                child: ProfileGridViewCount(count: post.viewCount),
              ),
            if (isAuction)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      border: Border.all(
                        color: auctionStatus.borderColor.withValues(alpha: 0.9),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProfileGridViewCount extends StatelessWidget {
  const ProfileGridViewCount({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.play,
          size: ProfileLayoutConstants.gridViewCountIconSize,
          color: Colors.white,
        ),
        const SizedBox(width: 3),
        Text(
          formatCompactCount(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: ProfileLayoutConstants.gridViewCountFontSize,
            fontWeight: FontWeight.w600,
            height: 1,
            shadows: [
              Shadow(color: Color(0x80000000), blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileAuctionStatus {
  const ProfileAuctionStatus({
    required this.label,
    required this.borderColor,
    required this.badgeBackground,
    required this.badgeForeground,
  });

  static const none = ProfileAuctionStatus(
    label: '',
    borderColor: Colors.transparent,
    badgeBackground: Colors.transparent,
    badgeForeground: Colors.transparent,
  );

  final String label;
  final Color borderColor;
  final Color badgeBackground;
  final Color badgeForeground;
}

class ProfileAuctionBadge extends StatelessWidget {
  const ProfileAuctionBadge({required this.status, super.key});

  final ProfileAuctionStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p6,
        vertical: AppSizes.p4,
      ),
      decoration: BoxDecoration(
        color: status.badgeBackground.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSizes.p8),
        border: Border.all(color: status.borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.gavel, size: 12, color: status.badgeForeground),
          const SizedBox(width: AppSizes.p4),
          Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: status.badgeForeground,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
