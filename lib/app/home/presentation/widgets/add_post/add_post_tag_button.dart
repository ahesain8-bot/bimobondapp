import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class AddPostTagButton extends StatelessWidget {
  const AddPostTagButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? const Color(0xFF2A2A2D)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.p8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: colorScheme.primary),
              const SizedBox(width: AppSizes.p6),
              CustomText(
                label,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
