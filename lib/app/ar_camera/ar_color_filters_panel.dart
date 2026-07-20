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
    required this.onApply,
  });

  final String selectedFilterId;
  final String selectedCategoryId;
  final double intensity;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onFilterSelected;
  final ValueChanged<double> onIntensityChanged;
  final VoidCallback onClear;
  /// Closes the sheet and keeps the current filter so the user can shoot.
  final VoidCallback onApply;

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
                        onApply: onApply,
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
    required this.onApply,
  });

  final String selectedCategoryId;
  final String selectedFilterId;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final noneSelected = selectedFilterId == 'none' ||
        !ArFilterCatalog.isColorFilter(selectedFilterId);
    final l10n = AppLocalizations.of(context)!;

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
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white.withValues(alpha: 0.25),
          ),
          GestureDetector(
            onTap: onApply,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.check,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.mediaEditorDone,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the server thumbnail when available, otherwise falls back to the
/// emoji (offline / bundled) over an optional preview color.
class _FilterThumbImage extends StatelessWidget {
  const _FilterThumbImage({required this.item});

  final ArFilterItem item;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = _hexToColor(item.previewColorHex);

    final emojiFallback = ColoredBox(
      color: placeholderColor ?? Colors.transparent,
      child: Center(
        child: Text(item.emoji, style: const TextStyle(fontSize: 26)),
      ),
    );

    if (!item.hasThumbnail) return emojiFallback;

    return Image.network(
      item.thumbnailUrl!,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: placeholderColor ?? Colors.white.withValues(alpha: 0.06),
        );
      },
      errorBuilder: (context, error, stack) => emojiFallback,
    );
  }

  static Color? _hexToColor(String? hex) {
    if (hex == null) return null;
    var value = hex.replaceFirst('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final intValue = int.tryParse(value, radix: 16);
    return intValue == null ? null : Color(intValue);
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
              child: ClipOval(child: _FilterThumbImage(item: item)),
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
