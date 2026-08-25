import 'package:bimobondapp/app/marketplace/domain/utils/marketplace_spec_builder.dart';
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/app/marketplace/presentation/widgets/marketplace_badges.dart';
import 'package:bimobondapp/app/shop/domain/entities/product_entity.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ProductSpecificationSection extends StatelessWidget {
  const ProductSpecificationSection({required this.product, super.key});

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final specs = MarketplaceSpecBuilder.detailSpecs(product);
    if (specs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.marketplaceSpecifications,
          style: TextStyle(
            color: theme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...specs.map(
          (line) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    line.label,
                    style: TextStyle(color: theme.mutedText, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    line.value,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MarketplaceTrustSection extends StatelessWidget {
  const MarketplaceTrustSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        TrustBadge(label: l10n.marketplaceVerifiedProduct),
        TrustBadge(label: l10n.marketplaceSecurePayment),
        TrustBadge(label: l10n.marketplaceBuyerProtection),
        TrustBadge(label: l10n.marketplaceDeliveryTracking),
      ],
    );
  }
}

class SellerCard extends StatelessWidget {
  const SellerCard({required this.seller, super.key});

  final ProductSellerEntity seller;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    return DecoratedBox(
      decoration: theme.cardDecoration(radius: MarketplaceTheme.radiusSm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.surface,
          backgroundImage:
              seller.avatarUrl != null ? NetworkImage(seller.avatarUrl!) : null,
          child: seller.avatarUrl == null
              ? Text(seller.username.characters.first.toUpperCase())
              : null,
        ),
        title: Text(
          seller.username,
          style: TextStyle(
            color: theme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: seller.verificationBadge != null
            ? Text(seller.verificationBadge!)
            : null,
      ),
    );
  }
}
