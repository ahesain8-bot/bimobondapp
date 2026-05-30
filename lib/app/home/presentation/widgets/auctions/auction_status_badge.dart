import 'dart:ui';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/pulsing_dot.dart';
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.p10,
              vertical: AppSizes.p6,
            ),
            decoration: BoxDecoration(
              color: AppTheme.successAccent.withOpacity(0.85),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PulsingDot(color: Colors.white, size: 6),
                const SizedBox(width: AppSizes.p6),
                CustomText(
                  l10n.liveBadge.toUpperCase(),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (auction.countdown != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.p10,
              vertical: AppSizes.p6,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 0.5,
              ),
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
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

