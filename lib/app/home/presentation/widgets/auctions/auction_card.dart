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

    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.12),
            ),
            boxShadow: [
              if (theme.brightness == Brightness.light)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
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
                  Positioned(
                    top: AppSizes.p12,
                    left: AppSizes.p12,
                    child: AuctionStatusBadge(auction: auction),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.p12,
                  AppSizes.p8,
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
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSizes.p16),
                    Row(
                      children: [
                        if (auction.post?.auction != null)
                          Expanded(
                            child: AuctionCardCountdownStat(
                              startedAt: auction.post!.auction!.startedAt,
                              endedAt: auction.post!.auction!.endedAt,
                            ),
                          )
                        else
                          const Spacer(),
                        Expanded(
                          child: AuctionBidStatColumn(
                            label: l10n.liveTopBid,
                            value: _formatGiftTotal(l10n, locale),
                            alignEnd: true,
                            valueColor: theme.primaryColor,
                            leadingIcon: LucideIcons.gift,
                          ),
                        ),
                      ],
                    ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                            ),
                          ),
                          child: CustomText(
                            l10n.bidNow,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
