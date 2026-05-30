import 'dart:ui';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_bid_stat_column.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_card_countdown_stat.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_card_footer_row.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_post_category_badge.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/auctions/auction_status_badge.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionCard extends StatelessWidget {
  const AuctionCard({
    required this.auction,
    required this.surfaceColor,
    required this.onOpen,
    this.showBidButton = true,
    super.key,
  });

  final AuctionItem auction;
  final Color surfaceColor;
  final VoidCallback onOpen;
  final bool showBidButton;

  String _formatGiftTotal(AppLocalizations l10n, Locale locale) {
    final total = auction.giftTotalUsd;
    final text = total == total.roundToDouble()
        ? total.round().toString()
        : total.toStringAsFixed(2);
    final amount = LocaleFormatUtils.localizeDigits(text, locale);
    return l10n.liveHighestBidAmount(amount, l10n.currencyUsd);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBorderColor = isDark
        ? Colors.white10
        : theme.dividerColor.withValues(alpha: 0.1);

    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(color: cardBorderColor, width: 1.0),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      auction.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          LucideIcons.image,
                          color: theme.disabledColor,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  // Sleek bottom gradient overlay on image for readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          stops: const [0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Live/Status badge at top-left
                  Positioned(
                    top: AppSizes.p12,
                    left: AppSizes.p12,
                    child: AuctionStatusBadge(auction: auction),
                  ),
                  // Glassmorphic Countdown overlay at bottom-left
                  if (auction.post?.auction != null)
                    Positioned(
                      bottom: AppSizes.p12,
                      left: AppSizes.p12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.p8,
                              vertical: AppSizes.p4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusSm,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.clock,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: AppSizes.p4),
                                AuctionCardCountdownStat(
                                  startedAt: auction.post!.auction!.startedAt,
                                  endedAt: auction.post!.auction!.endedAt,
                                  isMinimal: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.p16,
                  AppSizes.p12,
                  AppSizes.p16,
                  AppSizes.p16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CustomText(
                          auction.title,
                          textAlign: TextAlign.end,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        if (auction.subtitle.isNotEmpty) ...[
                          const SizedBox(height: AppSizes.p4),
                          CustomText(
                            auction.subtitle,
                            textAlign: TextAlign.end,
                            fontSize: 13,
                            variant: TextVariant.secondary,
                            // maxLines: 1,
                            // overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.p12),
                    // High-end segmented container for prices
                    if (auction.post?.auction != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.p12,
                          vertical: AppSizes.p10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.035),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                          border: Border.all(
                            color: theme.primaryColor.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Target price
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomText(
                                    l10n.auctionTargetPrice(
                                      LocaleFormatUtils.localizeDigits(
                                        auction.post!.auction!.targetPriceUsd
                                            .toStringAsFixed(0),
                                        locale,
                                      ),
                                      l10n.currencyUsd,
                                    ),
                                    fontSize: 11,
                                    variant: TextVariant.secondary,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.target,
                                        size: 13,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.65),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        LocaleFormatUtils.localizeDigits(
                                          '\$${auction.post!.auction!.targetPriceUsd.toStringAsFixed(0)}',
                                          locale,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Divider line
                            Container(
                              height: 28,
                              width: 1.0,
                              color: theme.primaryColor.withValues(alpha: 0.08),
                            ),
                            const SizedBox(width: AppSizes.p12),
                            // Highest Bid
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  CustomText(
                                    l10n.liveTopBid,
                                    fontSize: 11,
                                    variant: TextVariant.secondary,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        LucideIcons.gift,
                                        size: 13,
                                        color: theme.primaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatGiftTotal(l10n, locale),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (showBidButton) ...[
                      const SizedBox(height: AppSizes.p16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: onOpen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: theme.primaryColor.withValues(
                              alpha: 0.25,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.gavel,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: AppSizes.p8),
                              CustomText(
                                l10n.bidNow,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (auction.ownerUsername != null &&
                        auction.ownerUsername!.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.p12),
                      AuctionCardFooterRow(
                        username: auction.ownerUsername!,
                        avatarUrl: auction.ownerAvatarUrl,
                        categoryLabel: auction.categoryLabel,
                        categorySlug: auction.categorySlug,
                      ),
                    ] else if (auction.categoryLabel != null &&
                        auction.categoryLabel!.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.p12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AuctionPostCategoryBadge(
                          label: auction.categoryLabel!,
                          categorySlug: auction.categorySlug ?? '',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
