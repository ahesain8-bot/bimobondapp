import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

enum InterestChipPreference { none, interested, notInterested }

class InterestCategoryChip extends StatelessWidget {
  const InterestCategoryChip({
    required this.label,
    required this.icon,
    required this.preference,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final InterestChipPreference preference;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final error = theme.colorScheme.error;

    late final Color background;
    late final Color foreground;
    late final FontWeight weight;

    switch (preference) {
      case InterestChipPreference.interested:
        background = primary;
        foreground = Colors.white;
        weight = FontWeight.w600;
      case InterestChipPreference.notInterested:
        background = isDark
            ? error.withValues(alpha: 0.28)
            : error.withValues(alpha: 0.12);
        foreground = error;
        weight = FontWeight.w600;
      case InterestChipPreference.none:
        background = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F1F2);
        foreground = isDark ? Colors.white : const Color(0xFF161823);
        weight = FontWeight.w500;
    }

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
            color: background,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            border: preference == InterestChipPreference.notInterested
                ? Border.all(color: error.withValues(alpha: 0.45))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: AppSizes.p8),
              CustomText(
                label,
                fontSize: 15,
                fontWeight: weight,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
