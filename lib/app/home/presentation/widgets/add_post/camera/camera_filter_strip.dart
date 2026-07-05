import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

class CameraFilterCategoryTabs extends StatelessWidget {
  const CameraFilterCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedSlug,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<CameraFilterCategoryEntity> categories;
  final String selectedSlug;
  final String Function(CameraFilterCategoryEntity category) labelBuilder;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.slug == selectedSlug;
          return GestureDetector(
            onTap: () => onSelected(category.slug),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  labelBuilder(category),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: isSelected ? 24 : 0,
                  height: 2,
                  color: Colors.redAccent,
                ),
              ],
            ),
          );
        },
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
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final preset = presets[index];
          final isSelected = preset.filter.name == selected.name;
          final previewColor = preset.previewColor ??
              CameraFilterCatalog.previewColor(preset.filter);

          return GestureDetector(
            onTap: () => onSelected(preset),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.redAccent : Colors.transparent,
                      width: 2,
                    ),
                    color: Colors.white12,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: preset.isOriginal || preset.filter == AwesomeFilter.None
                      ? const Icon(Icons.block, color: Colors.white54, size: 18)
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
                Text(
                  labelBuilder(preset),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
