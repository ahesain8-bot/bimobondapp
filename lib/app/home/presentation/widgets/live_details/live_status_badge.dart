import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LiveStatusBadge extends StatelessWidget {
  const LiveStatusBadge({
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
        horizontal: AppSizes.p10,
        vertical: AppSizes.p4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(AppSizes.p8),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: LiveDetailsLayoutConstants.liveBadgeLetterSpacing,
        ),
      ),
    );

    if (isAuctionActive || isAuctionFinished) return badge;

    return FadeTransition(opacity: pulseAnimation, child: badge);
  }
}
