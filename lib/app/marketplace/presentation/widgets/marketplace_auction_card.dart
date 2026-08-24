import 'package:bimobondapp/app/auctions/domain/entities/auction_details_entity.dart';
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/auction_countdown.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_buttons.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_product_card.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/price_display.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum MarketplaceAuctionCardLayout { horizontal, grid }

class MarketplaceAuctionCard extends StatelessWidget {
  const MarketplaceAuctionCard({
    required this.auction,
    required this.onTap,
    this.layout = MarketplaceAuctionCardLayout.horizontal,
    super.key,
  });

  final AuctionDetailsEntity auction;
  final VoidCallback onTap;
  final MarketplaceAuctionCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final width = MarketplaceProductCardMetrics.horizontalCardWidth(context);
    final bidCount = auction.giftCount;

    return SizedBox(
      width: layout == MarketplaceAuctionCardLayout.horizontal ? width : null,
      child: Material(
        color: theme.card,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: theme.cardDecoration(radius: MarketplaceTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.all(MarketplaceProductCardMetrics.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(MarketplaceTheme.radiusXs),
                          child: SafeNetworkImage(
                            imageUrl: auction.itemImageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (auction.isActive)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.marketplaceLiveAuction,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: AuctionCountdown(
                              endsAt: auction.endedAt,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.auctionAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.marketplaceAuctionLabel,
                      style: TextStyle(
                        color: theme.auctionAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auction.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.marketplaceCurrentBid,
                    style: TextStyle(color: theme.mutedText, fontSize: 10),
                  ),
                  PriceDisplay(
                    priceCoins: auction.displayHighestPriceCoins,
                    size: PriceDisplaySize.compact,
                    color: theme.auctionAccent,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.marketplaceBidCount(bidCount),
                    style: TextStyle(color: theme.mutedText, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  AuctionButton(
                    label: l10n.marketplaceViewAuction,
                    onPressed: onTap,
                    expanded: true,
                    compact: true,
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
