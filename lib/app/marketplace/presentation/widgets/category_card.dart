import 'package:bimobondapp/app/marketplace/domain/utils/marketplace_category_config.dart';
import 'package:bimobondapp/app/marketplace/presentation/theme/marketplace_theme.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    required this.config,
    required this.onTap,
    this.label,
    this.iconUrl,
    super.key,
  });

  final MarketplaceCategoryConfig config;
  final VoidCallback onTap;
  final String? label;
  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    final theme = MarketplaceTheme.of(context);
    final display = label ?? config.fallbackName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
                border: Border.all(
                  color: theme.shop.border.withValues(alpha: 0.35),
                ),
                boxShadow: MarketplaceTheme.softShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: _CategoryIcon(
                iconUrl: iconUrl,
                config: config,
                iconColor: theme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({
    required this.iconUrl,
    required this.config,
    required this.iconColor,
  });

  final String? iconUrl;
  final MarketplaceCategoryConfig config;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    if (iconUrl != null && iconUrl!.trim().isNotEmpty) {
      return SafeNetworkImage(
        imageUrl: iconUrl,
        fit: BoxFit.cover,
        width: 56,
        height: 56,
        borderRadius: BorderRadius.circular(MarketplaceTheme.radiusMd),
        errorIcon: config.icon,
        blankOnError: false,
      );
    }

    return Center(
      child: config.emoji != null
          ? Text(config.emoji!, style: const TextStyle(fontSize: 24))
          : Icon(config.icon, color: iconColor, size: 24),
    );
  }
}
