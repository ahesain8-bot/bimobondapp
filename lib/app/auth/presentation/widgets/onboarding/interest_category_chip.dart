import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class InterestCategoryChip extends StatelessWidget {
  const InterestCategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBackground =
        isDark ? Colors.white : const Color(0xFF161823);
    final selectedForeground =
        isDark ? const Color(0xFF161823) : Colors.white;
    final unselectedBackground =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F1F2);
    final unselectedForeground =
        isDark ? Colors.white : const Color(0xFF161823);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: AppSizes.p12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? selectedBackground : unselectedBackground,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: CustomText(
            label,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? selectedForeground : unselectedForeground,
          ),
        ),
      ),
    );
  }
}
