import 'dart:ui';

import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_l10n.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style Filters bottom sheet — color / portrait grades only.
class ArColorFiltersPanel extends StatelessWidget {
  const ArColorFiltersPanel({
    super.key,
    required this.selectedFilterId,
    required this.selectedCategoryId,
    required this.intensity,
    required this.onCategorySelected,
    required this.onFilterSelected,
    required this.onIntensityChanged,
    required this.onClear,
  });

  final String selectedFilterId;
  final String selectedCategoryId;
  final double intensity;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onFilterSelected;
  final ValueChanged<double> onIntensityChanged;
  final VoidCallback onClear;

  bool get _showIntensity =>
      selectedFilterId != 'none' &&
      ArFilterCatalog.isColorFilter(selectedFilterId);

  @override
  Widget build(BuildContext context) {
    final filters = ArFilterCatalog.colorItemsForCategory(selectedCategoryId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showIntensity) ...[
          _IntensitySlider(
            value: intensity,
            onChanged: onIntensityChanged,
          ),
          const SizedBox(height: 10),
        ],
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withValues(alpha: 0.92),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CategoryRow(
                        selectedCategoryId: selectedCategoryId,
                        selectedFilterId: selectedFilterId,
                        onCategorySelected: onCategorySelected,
                        onClear: onClear,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filters.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final item = filters[index];
                            final selected = item.id == selectedFilterId;
                            return _FilterThumb(
                              item: item,
                              selected: selected,
                              onTap: () => onFilterSelected(item.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IntensitySlider extends StatelessWidget {
  const _IntensitySlider({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2.5,
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
          thumbColor: Colors.white,
          overlayColor: Colors.white.withValues(alpha: 0.12),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        ),
        child: Slider(
          value: value.clamp(0.0, 1.0),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.selectedCategoryId,
    required this.selectedFilterId,
    required this.onCategorySelected,
    required this.onClear,
  });

  final String selectedCategoryId;
  final String selectedFilterId;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final noneSelected = selectedFilterId == 'none' ||
        !ArFilterCatalog.isColorFilter(selectedFilterId);

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onClear,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                LucideIcons.ban,
                size: 22,
                color: noneSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withValues(alpha: 0.25),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ArFilterCatalog.colorCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                final category = ArFilterCatalog.colorCategories[index];
                final selected = category.id == selectedCategoryId;
                final l10n = AppLocalizations.of(context)!;
                return GestureDetector(
                  onTap: () => onCategorySelected(category.id),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        arFilterCategoryLabel(l10n, category),
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.45),
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: selected ? 28 : 0,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterThumb extends StatelessWidget {
  const _FilterThumb({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ArFilterItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: selected ? 0.18 : 0.08),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.22),
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: Center(
                child: Text(item.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              arFilterLabel(l10n, item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
