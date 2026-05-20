import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CompactHighestBid extends StatelessWidget {
  const CompactHighestBid({
    required this.topBidLabel,
    required this.bidAmountText,
    this.targetPrice,
    this.targetPriceLabel,
    this.isFinished = false,
    this.showGiftIcon = false,
    required this.popAnimation,
    required this.theme,
  });

  final String topBidLabel;
  final String bidAmountText;
  final int? targetPrice;
  final String? targetPriceLabel;
  final bool isFinished;
  final bool showGiftIcon;
  final Animation<double> popAnimation;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: popAnimation,
      child: Container(
        margin: LiveDetailsLayoutConstants.screenHorizontalPadding,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            LiveDetailsLayoutConstants.topBidRadius,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p16,
                vertical: AppSizes.p8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isFinished
                      ? [
                          LiveDetailsLayoutConstants.auctionFinishedBadgeColor
                              .withValues(alpha: 0.9),
                          LiveDetailsLayoutConstants.auctionFinishedBadgeDark
                              .withValues(alpha: 0.9),
                        ]
                      : [
                          theme.colorScheme.primary.withValues(alpha: 0.85),
                          theme.colorScheme.secondary.withValues(alpha: 0.85),
                        ],
                ),
                borderRadius: BorderRadius.circular(
                  LiveDetailsLayoutConstants.topBidRadius,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isFinished
                            ? LiveDetailsLayoutConstants
                                .auctionFinishedBadgeDark
                            : theme.colorScheme.primary)
                        .withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFinished
                        ? LucideIcons.badgeCheck
                        : showGiftIcon
                            ? LucideIcons.gift
                            : LucideIcons.gavel,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: AppSizes.p8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        topBidLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        bidAmountText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (targetPriceLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          targetPriceLabel!,
                          style: TextStyle(
                            color: isFinished
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                            fontWeight: isFinished
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
