import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

/// Shared theme helpers so promotion screens match the rest of the app.
abstract final class PromotionUi {
  PromotionUi._();

  static BoxDecoration sectionDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.55);

    return BoxDecoration(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      border: Border.all(color: borderColor),
      boxShadow: [
        if (!isDark)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
      ],
    );
  }

  static TextStyle stepHeading(BuildContext context) {
    return Theme.of(context).textTheme.headlineSmall!.copyWith(
          fontWeight: FontWeight.w700,
        );
  }

  static TextStyle stepSubtitle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  static TextStyle fieldLabel(BuildContext context, {bool enabled = true}) {
    final theme = Theme.of(context);
    return theme.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w700,
      color: enabled
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurface.withValues(alpha: 0.45),
    );
  }

  static BoxDecoration dropdownDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
    );
  }

  static TextStyle dropdownValue(
    BuildContext context, {
    required bool isPlaceholder,
  }) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyLarge!.copyWith(
      fontWeight: isPlaceholder ? FontWeight.w500 : FontWeight.w600,
      color: isPlaceholder
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurface,
    );
  }
}
