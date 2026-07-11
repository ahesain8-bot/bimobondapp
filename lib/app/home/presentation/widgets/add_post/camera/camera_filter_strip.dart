import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_tool_icons.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum CameraFilterTabStyle { pill, underline }

class CameraFilterCategoryTabs extends StatelessWidget {
  const CameraFilterCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedSlug,
    required this.labelBuilder,
    required this.onSelected,
    this.onClear,
    this.style = CameraFilterTabStyle.pill,
  });

  final List<CameraFilterCategoryEntity> categories;
  final String selectedSlug;
  final String Function(CameraFilterCategoryEntity category) labelBuilder;
  final ValueChanged<String> onSelected;
  final VoidCallback? onClear;
  final CameraFilterTabStyle style;

  @override
  Widget build(BuildContext context) {
    final isUnderline = style == CameraFilterTabStyle.underline;

    return SizedBox(
      height: isUnderline ? 40 : 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + (onClear != null ? 1 : 0),
        separatorBuilder: (context, index) =>
            SizedBox(width: isUnderline ? 18 : 10),
        itemBuilder: (context, index) {
          if (onClear != null && index == categories.length) {
            return GestureDetector(
              onTap: onClear,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  LucideIcons.ban,
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 22,
                ),
              ),
            );
          }

          final category = categories[index];
          final isSelected = category.slug == selectedSlug;

          if (isUnderline) {
            return _UnderlineCategoryTab(
              label: labelBuilder(category),
              isSelected: isSelected,
              onTap: () => onSelected(category.slug),
            );
          }

          return GestureDetector(
            onTap: () => onSelected(category.slug),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                labelBuilder(category),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                  shadows: isSelected
                      ? const [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UnderlineCategoryTab extends StatelessWidget {
  const _UnderlineCategoryTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isSelected ? 28 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class CameraFilterStrip extends StatelessWidget {
  const CameraFilterStrip({
    super.key,
    required this.presets,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<CameraFilterPreset> presets;
  final AwesomeFilter selected;
  final String Function(CameraFilterPreset preset) labelBuilder;
  final ValueChanged<CameraFilterPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final preset = presets[index];
          final isSelected = preset.filter.name == selected.name;
          final previewColor = preset.previewColor ??
              CameraFilterCatalog.previewColor(preset.filter);

          return GestureDetector(
            onTap: () => onSelected(preset),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isSelected ? 60 : 54,
                  height: isSelected ? 60 : 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.2),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: preset.isOriginal || preset.filter == AwesomeFilter.None
                      ? ColoredBox(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Icon(
                            Icons.block,
                            color: Colors.white54,
                            size: 20,
                          ),
                        )
                      : preset.hasThumbnail
                      ? Image.network(
                          MediaUtils.resolveAbsoluteUrl(preset.thumbnailUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return ColoredBox(color: previewColor);
                          },
                        )
                      : ColoredBox(color: previewColor),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 64,
                  child: Text(
                    labelBuilder(preset),
                    style: CameraToolIcons.labelStyle.copyWith(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
