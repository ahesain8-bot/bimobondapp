import 'dart:ui';

import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
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
    this.showCoinIcon = false,
    required this.popAnimation,
    required this.theme,
    this.margin = LiveDetailsLayoutConstants.screenHorizontalPadding,
  });

  final String topBidLabel;
  final String bidAmountText;
  final int? targetPrice;
  final String? targetPriceLabel;
  final bool isFinished;
  final bool showGiftIcon;
  final bool showCoinIcon;
  final Animation<double> popAnimation;
  final ThemeData theme;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final accentColor = isFinished
        ? LiveDetailsLayoutConstants.auctionFinishedBadgeColor
        : theme.colorScheme.primary;

    final darkAccent = isFinished
        ? LiveDetailsLayoutConstants.auctionFinishedBadgeDark
        : theme.colorScheme.secondary;

    return ScaleTransition(
      scale: popAnimation,
      child: Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main Bid Segment
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p10,
                      vertical: AppSizes.p8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.85),
                          darkAccent.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: darkAccent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
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
                          size: 16,
                        ),
                        const SizedBox(width: AppSizes.p6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              topBidLabel.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            showCoinIcon
                                ? AppCoinAmount(
                                    iconSize: 12,
                                    spacing: 3,
                                    text: bidAmountText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  )
                                : Text(
                                    bidAmountText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Target Price Segment
                  if (targetPriceLabel != null) ...[
                    const SizedBox(width: AppSizes.p4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p8,
                        vertical: AppSizes.p8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TARGET',
                            style: TextStyle(
                              color: isFinished ? accentColor : Colors.white54,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 1),
                          showCoinIcon
                              ? AppCoinAmount(
                                  iconSize: 10,
                                  spacing: 2,
                                  text: targetPriceLabel!,
                                  style: TextStyle(
                                    color: isFinished
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontWeight: isFinished
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                )
                              : Text(
                                  targetPriceLabel!,
                                  style: TextStyle(
                                    color: isFinished
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontWeight: isFinished
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
