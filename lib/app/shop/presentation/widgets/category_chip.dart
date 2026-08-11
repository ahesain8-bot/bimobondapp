import 'package:bimobondapp/app/shop/presentation/theme/shop_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconUrl,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? iconUrl;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShopTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.p12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? theme.primary : theme.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipOval(
                  child: iconUrl != null && iconUrl!.isNotEmpty
                      ? SafeNetworkImage(
                          imageUrl: iconUrl,
                          fit: BoxFit.cover,
                          width: 56,
                          height: 56,
                          borderRadius: BorderRadius.zero,
                        )
                      : Center(
                          child: Icon(
                            icon ?? LucideIcons.layoutGrid,
                            size: 22,
                            color: selected ? theme.primary : theme.mutedText,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSizes.p6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? theme.primary : theme.mutedText,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
