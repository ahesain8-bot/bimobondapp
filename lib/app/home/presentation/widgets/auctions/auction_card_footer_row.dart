import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_post_category_badge.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class AuctionCardFooterRow extends StatelessWidget {
  const AuctionCardFooterRow({
    required this.userId,
    required this.username,
    this.fullName,
    required this.avatarUrl,
    this.categoryLabel,
    this.categorySlug,
    super.key,
  });

  final String userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final String? categoryLabel;
  final String? categorySlug;

  bool get _hasCategory =>
      categoryLabel != null && categoryLabel!.trim().isNotEmpty;

  void _openProfile(BuildContext context) {
    if (userId.isEmpty) return;
    openUserStoryOrProfile(
      context,
      userId: userId,
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displayName = fullName?.trim().isNotEmpty == true
        ? fullName!.trim()
        : '@$username';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StoryProfileAvatar(
          userId: userId,
          imageUrl: avatarUrl,
          radius: 14,
          fallbackText: displayName,
          username: username,
          fullName: fullName,
          onTap: () => _openProfile(context),
        ),
        const SizedBox(width: AppSizes.p8),
        Expanded(
          child: InkWell(
            onTap: () => _openProfile(context),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.p4),
              child: Text(
                l10n.auctionAddedBy(displayName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        if (_hasCategory) ...[
          const SizedBox(width: AppSizes.p8),
          AuctionPostCategoryBadge(
            label: categoryLabel!.trim(),
            categorySlug: categorySlug ?? '',
          ),
        ],
      ],
    );
  }
}
