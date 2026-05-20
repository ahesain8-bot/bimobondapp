import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class AuctionCategoryChip extends StatelessWidget {
  const AuctionCategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.inactiveBackground,
    required this.inactiveBorder,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final Color inactiveBackground;
  final Color inactiveBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = isSelected ? Colors.white : theme.colorScheme.onSurface;

    return Material(
      color: isSelected ? selectedColor : inactiveBackground,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.p8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: isSelected ? selectedColor : inactiveBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: AppSizes.p6),
              CustomText(
                label,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
