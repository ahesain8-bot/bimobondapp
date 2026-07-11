import 'dart:ui';

import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_strip.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

/// TikTok-style filter picker with solid bottom sheet background.
class CameraFiltersPanel extends StatelessWidget {
  const CameraFiltersPanel({
    super.key,
    required this.categories,
    required this.selectedCategorySlug,
    required this.categoryLabelBuilder,
    required this.onCategorySelected,
    required this.presets,
    required this.selectedFilter,
    required this.filterLabelBuilder,
    required this.onFilterSelected,
    required this.onClearFilter,
  });

  final List<CameraFilterCategoryEntity> categories;
  final String selectedCategorySlug;
  final String Function(CameraFilterCategoryEntity category) categoryLabelBuilder;
  final ValueChanged<String> onCategorySelected;
  final List<CameraFilterPreset> presets;
  final AwesomeFilter selectedFilter;
  final String Function(CameraFilterPreset preset) filterLabelBuilder;
  final ValueChanged<CameraFilterPreset> onFilterSelected;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  CameraFilterCategoryTabs(
                    categories: categories,
                    selectedSlug: selectedCategorySlug,
                    labelBuilder: categoryLabelBuilder,
                    onSelected: onCategorySelected,
                    onClear: onClearFilter,
                    style: CameraFilterTabStyle.underline,
                  ),
                  const SizedBox(height: 16),
                  CameraFilterStrip(
                    presets: presets,
                    selected: selectedFilter,
                    labelBuilder: filterLabelBuilder,
                    onSelected: onFilterSelected,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dimmed scrim behind the filter sheet so labels stay readable on camera preview.
class CameraFiltersScrim extends StatelessWidget {
  const CameraFiltersScrim({
    super.key,
    required this.onDismiss,
  });

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.52),
      ),
    );
  }
}
