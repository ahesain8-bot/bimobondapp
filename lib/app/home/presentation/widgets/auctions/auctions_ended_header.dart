import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionsEndedHeader extends StatelessWidget {
  const AuctionsEndedHeader({
    super.key,
    this.onTap,
    this.showViewAll = false,
  });

  final VoidCallback? onTap;
  final bool showViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final content = Row(
      children: [
        CustomText(
          l10n.endedAuctionsNow,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p10,
            vertical: AppSizes.p4,
          ),
          decoration: BoxDecoration(
            color: LiveDetailsLayoutConstants.auctionFinishedBadgeDark
                .withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.circleCheck,
                size: 12,
                color: LiveDetailsLayoutConstants.auctionFinishedBadgeColor,
              ),
              const SizedBox(width: AppSizes.p6),
              CustomText(
                l10n.auctionFinishedBadge,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: LiveDetailsLayoutConstants.auctionFinishedBadgeColor,
              ),
            ],
          ),
        ),
        if (showViewAll) ...[
          const SizedBox(width: AppSizes.p8),
          CustomText(
            l10n.viewAll,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? LucideIcons.chevronLeft
                : LucideIcons.chevronRight,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ],
      ],
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.p4),
          child: content,
        ),
      ),
    );
  }
}
