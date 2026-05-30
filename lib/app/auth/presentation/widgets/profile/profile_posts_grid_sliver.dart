import 'package:bimobondapp/app/auth/presentation/widgets/profile/profile_tab_posts_state.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfilePostsGridSliver extends StatelessWidget {
  const ProfilePostsGridSliver({
    required this.tab,
    required this.tabIndex,
    required this.emptyMessage,
    super.key,
  });

  final ProfileTabPostsState tab;
  final int tabIndex;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: ProfileLayoutConstants.gridCrossAxisCount,
      crossAxisSpacing: ProfileLayoutConstants.gridSpacing,
      mainAxisSpacing: ProfileLayoutConstants.gridSpacing,
      childAspectRatio: ProfileLayoutConstants.gridAspectRatio,
    );

    if (tab.isRefreshing || (tab.isInitialLoading && tab.posts.isEmpty)) {
      return SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              const SkeletonWidget(borderRadius: AppSizes.radiusSm),
          childCount: 9,
        ),
      );
    }

    if (tab.posts.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 220,
          child: Center(
            child: CustomText(emptyMessage, variant: TextVariant.secondary),
          ),
        ),
      );
    }

    final itemCount =
        tab.posts.length + (tab.isLoadingMore && !tab.hasReachedMax ? 1 : 0);

    return SliverGrid(
      gridDelegate: gridDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        if (tab.isLoadingMore &&
            !tab.hasReachedMax &&
            index == tab.posts.length) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final post = tab.posts[index];
        return ProfileGridTile(
          post: post,
          tabIndex: tabIndex,
          theme: theme,
          onTap: () => openPost(context, post),
        );
      }, childCount: itemCount),
    );
  }
}

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

  String? _resolveImageUrl() {
    if (post.thumbnailUrl != null && MediaUtils.isImage(post.thumbnailUrl!)) {
      return post.thumbnailUrl;
    }
    if (post.media.isNotEmpty) {
      final first = post.media.first;
      if (MediaUtils.isImage(first.url, mediaType: first.mediaType)) {
        return first.url;
      }
    }
    return null;
  }

  bool _isVideoPost() {
    if (post.type.toUpperCase() == 'VIDEO') return true;
    return post.media.any(
      (m) => MediaUtils.isVideo(m.url, mediaType: m.mediaType),
    );
  }

  bool get _isAuctionPost => post.isAuctionable;

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
    final imageUrl = _resolveImageUrl();
    final isPostsTab = tabIndex == 0;
    final isVideo = isPostsTab && _isVideoPost() && !_isAuctionPost;
    final auctionStatus = _auctionStatus(l10n);
    final isAuction = _isAuctionPost;
    final placeholderColor = theme.dividerColor.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06,
    );
    final itemName = post.auction?.itemName;

    return Material(
      color: isVideo ? Colors.black : placeholderColor,
      borderRadius: BorderRadius.circular(
        ProfileLayoutConstants.gridItemRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              const VideoPostPreviewPlaceholder(
                iconSize: ProfileLayoutConstants.gridPlaceholderIconSize,
              )
            else if (imageUrl != null &&
                imageUrl.isNotEmpty &&
                isValidNetworkImageUrl(imageUrl))
              SafeNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorIcon: isAuction
                    ? Icons.gavel_outlined
                    : Icons.image_outlined,
              )
            else
              _placeholderIcon(false, isAuction),
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
            if (isAuction)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        ProfileLayoutConstants.gridItemRadius,
                      ),
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

  Widget _placeholderIcon(bool isVideo, bool isAuction) {
    final IconData icon;
    final Color color;

    if (tabIndex == 1) {
      icon = LucideIcons.heart;
      color = theme.colorScheme.primary.withValues(alpha: 0.35);
    } else if (tabIndex == 2) {
      icon = LucideIcons.bookmark;
      color = theme.colorScheme.secondary.withValues(alpha: 0.35);
    } else if (isAuction) {
      icon = LucideIcons.gavel;
      color = LiveDetailsLayoutConstants.giftCommentGold.withValues(
        alpha: 0.65,
      );
    } else {
      icon = isVideo ? Icons.play_arrow_rounded : Icons.image_outlined;
      color = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    }

    return Center(
      child: Icon(
        icon,
        size: ProfileLayoutConstants.gridPlaceholderIconSize,
        color: color,
      ),
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
  const ProfileAuctionBadge({
    required this.status,
    super.key,
  });

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
