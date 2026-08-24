import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:flutter/material.dart';

class BuyNowButton extends StatelessWidget {
  const BuyNowButton({
    required this.onPressed,
    this.label = 'Buy Now',
    this.expanded = true,
    this.compact = false,
    this.dense = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool expanded;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final child = Material(
      color: theme.primary,
      borderRadius: BorderRadius.circular(
        compact ? MarketplaceTheme.radiusXs : MarketplaceTheme.radiusSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : (compact ? 10 : 16),
            vertical: dense ? 6 : (compact ? 8 : 12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.shop.onAccent,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 10 : (compact ? 12 : 14),
            ),
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class AuctionButton extends StatelessWidget {
  const AuctionButton({
    required this.onPressed,
    this.label = 'View Auction',
    this.expanded = true,
    this.compact = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final child = Material(
      color: theme.auctionAccent,
      borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 7 : 12,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 14,
            ),
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}
