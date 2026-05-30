import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/pulsing_dot.dart';

class LiveStatusBadge extends StatelessWidget {
  const LiveStatusBadge({
    super.key,
    required this.label,
    required this.isAuctionActive,
    this.isAuctionFinished = false,
    required this.pulseAnimation,
  });

  final String label;
  final bool isAuctionActive;
  final bool isAuctionFinished;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    final gradientColors = isAuctionFinished
        ? const [
            LiveDetailsLayoutConstants.auctionFinishedBadgeColor,
            LiveDetailsLayoutConstants.auctionFinishedBadgeDark,
          ]
        : isAuctionActive
        ? const [
            LiveDetailsLayoutConstants.auctionActiveBadgeColor,
            LiveDetailsLayoutConstants.auctionActiveBadgeDark,
          ]
        : const [
            LiveDetailsLayoutConstants.liveBadgeColor,
            LiveDetailsLayoutConstants.liveBadgeDark,
          ];

    final shadowColor = isAuctionFinished
        ? LiveDetailsLayoutConstants.auctionFinishedBadgeDark
        : isAuctionActive
        ? LiveDetailsLayoutConstants.auctionActiveBadgeColor
        : LiveDetailsLayoutConstants.liveBadgeColor;

    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p12,
        vertical: AppSizes.p6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isAuctionFinished) ...[
            const PulsingDot(color: Colors.white, size: 6),
            const SizedBox(width: AppSizes.p6),
          ],
          if (isAuctionFinished) ...[
            const Icon(Icons.check_circle, size: 12, color: Colors.white),
            const SizedBox(width: AppSizes.p4),
          ],
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );

    // If it's active or finished auction, we don't fade the whole badge since PulsingDot handles the pulsing.
    // If it's a regular live stream, we can still use the fading animation for the whole badge or just rely on PulsingDot.
    // Since we added PulsingDot, let's remove the FadeTransition to keep it consistent and cleaner.
    return badge;
  }
}
