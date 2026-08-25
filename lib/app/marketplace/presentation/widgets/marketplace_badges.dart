import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:flutter/material.dart';

class ProductStatusBadge extends StatelessWidget {
  const ProductStatusBadge({
    required this.inStock,
    this.label,
    this.compact = false,
    super.key,
  });

  final bool inStock;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final text = label ?? (inStock ? 'In Stock' : 'Out of Stock');
    final color = inStock ? theme.success : theme.mutedText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_rounded, size: compact ? 11 : 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class OwnershipBadge extends StatelessWidget {
  const OwnershipBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusSm),
        border: Border.all(color: theme.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 16, color: theme.success),
          const SizedBox(width: 6),
          Text(
            'OWNED BY YOU',
            style: TextStyle(
              color: theme.success,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class TrustBadge extends StatelessWidget {
  const TrustBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline, size: 14, color: theme.secondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: theme.onSurface.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class DeliveryStatusChip extends StatelessWidget {
  const DeliveryStatusChip({required this.status, super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusXs),
        border: Border.all(color: theme.shop.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: theme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
