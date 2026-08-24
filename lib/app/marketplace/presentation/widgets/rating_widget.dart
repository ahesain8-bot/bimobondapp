import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class RatingWidget extends StatelessWidget {
  const RatingWidget({
    required this.rating,
    this.reviewCount,
    this.size = 14,
    super.key,
  });

  final double rating;
  final int? reviewCount;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final fullStars = rating.floor().clamp(0, 5);
    final hasHalf = (rating - fullStars) >= 0.25;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          IconData icon;
          if (index < fullStars) {
            icon = LucideIcons.star;
          } else if (index == fullStars && hasHalf) {
            icon = LucideIcons.starHalf;
          } else {
            icon = LucideIcons.star;
          }
          final filled = index < fullStars || (index == fullStars && hasHalf);
          return Icon(
            icon,
            size: size,
            color: filled
                ? const Color(0xFFF59E0B)
                : theme.mutedText.withValues(alpha: 0.35),
            fill: filled ? 1.0 : 0.0,
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: theme.onSurface,
            fontSize: size - 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: TextStyle(color: theme.mutedText, fontSize: size - 2),
          ),
        ],
      ],
    );
  }
}
