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
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF2A2A2D) : const Color(0xFFF1F1F2);
    final onSurface = theme.colorScheme.onSurface;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: onSurface.withValues(alpha: 0.85)),
              const SizedBox(width: 6),
              CustomText(
                label,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
