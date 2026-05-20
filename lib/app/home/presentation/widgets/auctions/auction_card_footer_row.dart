import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_post_category_badge.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class AuctionCardFooterRow extends StatelessWidget {
  const AuctionCardFooterRow({
    required this.username,
    required this.avatarUrl,
    this.categoryLabel,
    this.categorySlug,
    super.key,
  });

  final String username;
  final String? avatarUrl;
  final String? categoryLabel;
  final String? categorySlug;

  bool get _hasCategory =>
      categoryLabel != null && categoryLabel!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SafeNetworkAvatar(
          imageUrl: avatarUrl,
          radius: 14,
          fallbackText: username,
        ),
        const SizedBox(width: AppSizes.p8),
        Expanded(
          child: Text(
            l10n.auctionAddedBy('@$username'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              fontSize: 13,
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
