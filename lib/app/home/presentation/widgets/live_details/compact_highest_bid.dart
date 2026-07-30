import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/post_auction_display_utils.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CompactHighestBid extends StatelessWidget {
  const CompactHighestBid({
    required this.topBidLabel,
    required this.bidAmountText,
    this.bidAmountCoins,
    this.targetPrice,
    this.targetPriceLabel,
    this.targetPriceHeader,
    this.isFinished = false,
    this.showGiftIcon = false,
    this.showCoinIcon = false,
    required this.popAnimation,
    required this.theme,
    this.margin = LiveDetailsLayoutConstants.screenHorizontalPadding,
  });

  final String topBidLabel;
  final String bidAmountText;
  final int? bidAmountCoins;
  final int? targetPrice;
  final String? targetPriceLabel;
  final String? targetPriceHeader;
  final bool isFinished;
  final bool showGiftIcon;
  final bool showCoinIcon;
  final Animation<double> popAnimation;
  final ThemeData theme;
  final EdgeInsetsGeometry margin;

  int? _resolvedTargetCoins() {
    if (targetPrice != null && targetPrice! > 0) return targetPrice;
    return null;
  }

  String? _targetAmountText(BuildContext context) {
    final coins = _resolvedTargetCoins();
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;

    if (coins != null && coins > 0) {
      if (showCoinIcon) {
        return formatAuctionPricingCoins(coins, locale);
      }
      return formatAuctionLiveCoinsLabel(l10n, locale, coins);
    }
    if (targetPriceLabel != null && targetPriceLabel!.trim().isNotEmpty) {
      return targetPriceLabel;
    }
    return null;
  }

  String _highestAmountText(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (showCoinIcon && bidAmountCoins != null) {
      return formatAuctionPricingCoins(bidAmountCoins!, locale);
    }
    return bidAmountText;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = isFinished
        ? LiveDetailsLayoutConstants.auctionFinishedBadgeColor
        : theme.colorScheme.primary;

    final darkAccent = isFinished
        ? LiveDetailsLayoutConstants.auctionFinishedBadgeDark
        : theme.colorScheme.secondary;

    final targetAmountText = _targetAmountText(context);
    final highestAmountText = _highestAmountText(context);

    return ScaleTransition(
      scale: popAnimation,
      child: Container(
        margin: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
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
                      horizontal: 12,
                      vertical: 10,
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
                      borderRadius: BorderRadius.circular(11),
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
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              topBidLabel.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            showCoinIcon
                                ? AppCoinAmount(
                                    iconSize: 13,
                                    spacing: 3,
                                    text: highestAmountText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  )
                                : Text(
                                    highestAmountText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (targetAmountText != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (targetPriceHeader ?? 'TARGET').toUpperCase(),
                            style: TextStyle(
                              color: isFinished ? accentColor : Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          showCoinIcon
                              ? AppCoinAmount(
                                  iconSize: 11,
                                  spacing: 2,
                                  text: targetAmountText,
                                  style: TextStyle(
                                    color: isFinished
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    fontWeight: isFinished
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                )
                              : Text(
                                  targetAmountText,
                                  style: TextStyle(
                                    color: isFinished
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
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
