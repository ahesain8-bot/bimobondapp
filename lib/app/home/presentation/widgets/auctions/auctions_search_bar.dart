import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuctionsSearchBar extends StatelessWidget {
  const AuctionsSearchBar({
    required this.controller,
    required this.fillColor,
    required this.onSubmitted,
    required this.onClear,
    this.hintText,
    this.onFilterTap,
    this.activeFilterCount = 0,
    super.key,
  });

  final TextEditingController controller;
  final Color fillColor;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;
  final String? hintText;
  final VoidCallback? onFilterTap;
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              hintText: hintText ?? l10n.auctionsSearchHint,
              hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
              prefixIcon: Icon(
                LucideIcons.search,
                size: 20,
                color: theme.hintColor,
              ),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(LucideIcons.x, size: 18, color: theme.hintColor),
                      onPressed: onClear,
                    )
                  : null,
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSizes.p12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
              ),
            ),
          ),
        ),
        if (onFilterTap != null) ...[
          const SizedBox(width: AppSizes.p8),
          _FilterButton(
            onTap: onFilterTap!,
            activeFilterCount: activeFilterCount,
            fillColor: fillColor,
          ),
        ],
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.onTap,
    required this.activeFilterCount,
    required this.fillColor,
  });

  final VoidCallback onTap;
  final int activeFilterCount;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveFilters = activeFilterCount > 0;

    return Material(
      color: hasActiveFilters
          ? theme.primaryColor.withValues(alpha: 0.12)
          : fillColor,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(
              color: hasActiveFilters
                  ? theme.primaryColor
                  : theme.dividerColor.withValues(alpha: 0.2),
              width: hasActiveFilters ? 1.5 : 1,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                LucideIcons.slidersHorizontal,
                size: 20,
                color: hasActiveFilters ? theme.primaryColor : theme.hintColor,
              ),
              if (hasActiveFilters)
                Positioned(
                  top: -6,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      activeFilterCount > 9 ? '9+' : '$activeFilterCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
