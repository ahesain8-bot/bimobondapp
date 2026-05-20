import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_item.dart';
import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionStatusBadge extends StatelessWidget {
  const AuctionStatusBadge({
    required this.auction,
    super.key,
  });

  final AuctionItem auction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (auction.isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p10,
          vertical: AppSizes.p6,
        ),
        decoration: BoxDecoration(
          color: AppTheme.successAccent,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSizes.p6),
            CustomText(
              l10n.liveBadge.toUpperCase(),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ],
        ),
      );
    }

    if (auction.countdown != null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p10,
          vertical: AppSizes.p6,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.clock, size: 12, color: Colors.white),
            const SizedBox(width: AppSizes.p4),
            CustomText(
              auction.countdown!,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
