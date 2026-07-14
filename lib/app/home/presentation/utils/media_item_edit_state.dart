import 'dart:io';

import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_compositor.dart';
import 'package:camerawesome/camerawesome_plugin.dart';

/// Per-item filter/effect choices in the media studio editor.
class MediaItemEditState {
  MediaItemEditState({
    required this.item,
    AwesomeFilter? filter,
    this.effectSlug,
    this.beautyEnabled = false,
    this.filterCategory = CameraFilterCategory.trending,
    this.arFilterId = 'none',
    this.arColorCategoryId = 'portrait',
    this.arFilterIntensity = 1.0,
    this.alreadyBaked = false,
    this.bakedArFilterId = 'none',
  }) : filter = filter ?? AwesomeFilter.None;

  final GalleryMediaItem item;
  final AwesomeFilter filter;
  final String? effectSlug;
  final bool beautyEnabled;
  final CameraFilterCategory filterCategory;

  /// Live AR camera catalog id (`none`, `glasses`, `whitening`, …).
  final String arFilterId;
  final String arColorCategoryId;
  final double arFilterIntensity;

  /// True when native capture already baked AR look into pixels.
  final bool alreadyBaked;

  /// Original AR id baked into the file (immutable for this source).
  final String bakedArFilterId;

  File get sourceFile => item.file;
  bool get isVideo => item.isVideo;

  bool get hasArEffect =>
      arFilterId != 'none' &&
      arFilterId.isNotEmpty &&
      !ArFilterCatalog.isColorFilter(arFilterId);

  bool get hasArColorFilter => ArFilterCatalog.isColorFilter(arFilterId);

  AwesomeFilter get effectiveFilter {
    if (filter.name != AwesomeFilter.None.name) return filter;
    if (beautyEnabled) return CameraFilterCatalog.beautyFilter.filter;
    return AwesomeFilter.None;
  }

  MediaItemEditState copyWith({
    AwesomeFilter? filter,
    String? effectSlug,
    bool? beautyEnabled,
    CameraFilterCategory? filterCategory,
    String? arFilterId,
    String? arColorCategoryId,
    double? arFilterIntensity,
    bool? alreadyBaked,
    String? bakedArFilterId,
  }) {
    return MediaItemEditState(
      item: item,
      filter: filter ?? this.filter,
      effectSlug: effectSlug,
      beautyEnabled: beautyEnabled ?? this.beautyEnabled,
      filterCategory: filterCategory ?? this.filterCategory,
      arFilterId: arFilterId ?? this.arFilterId,
      arColorCategoryId: arColorCategoryId ?? this.arColorCategoryId,
      arFilterIntensity: arFilterIntensity ?? this.arFilterIntensity,
      alreadyBaked: alreadyBaked ?? this.alreadyBaked,
      bakedArFilterId: bakedArFilterId ?? this.bakedArFilterId,
    );
  }

  factory MediaItemEditState.fromItem(GalleryMediaItem item) {
    return MediaItemEditState(item: item);
  }

  factory MediaItemEditState.fromItemWithSeed(
    GalleryMediaItem item,
    MediaEditorSeed seed,
  ) {
    final arId = seed.arFilterId ?? 'none';
    return MediaItemEditState(
      item: item,
      filter: seed.filterName != null
          ? CameraFilterCatalog.filterByName(seed.filterName!)
          : null,
      effectSlug: seed.effectSlug,
      beautyEnabled: seed.beautyEnabled || arId == 'whitening',
      filterCategory: seed.filterCategory,
      arFilterId: arId,
      arColorCategoryId: seed.arColorCategoryId ?? 'portrait',
      arFilterIntensity: seed.arFilterIntensity,
      alreadyBaked: seed.alreadyBaked,
      bakedArFilterId: seed.alreadyBaked ? arId : 'none',
    );
  }
}

String? primaryFilterNameFromStates(List<MediaItemEditState> states) {
  for (final state in states) {
    if (state.hasArColorFilter) return state.arFilterId;
    final filter = state.effectiveFilter;
    if (CameraFilterCompositor.isActiveFilter(filter)) {
      return filter.name;
    }
  }
  return null;
}

CameraFilterCategory primaryFilterCategoryFromStates(
  List<MediaItemEditState> states,
) {
  for (final state in states) {
    final filter = state.effectiveFilter;
    if (CameraFilterCompositor.isActiveFilter(filter)) {
      return state.filterCategory;
    }
  }
  return CameraFilterCategory.trending;
}

String? primaryEffectSlugFromStates(List<MediaItemEditState> states) {
  for (final state in states) {
    if (state.hasArEffect) return state.arFilterId;
    final slug = state.effectSlug;
    if (slug != null && slug.isNotEmpty && slug != 'none') return slug;
  }
  return null;
}

String? primaryArFilterIdFromStates(List<MediaItemEditState> states) {
  for (final state in states) {
    if (state.arFilterId != 'none' && state.arFilterId.isNotEmpty) {
      return state.arFilterId;
    }
  }
  return null;
}

/// Export result from the media studio editor.
class MediaStudioExportResult {
  const MediaStudioExportResult({
    required this.files,
    this.filterName,
    this.filterCategory = CameraFilterCategory.trending,
    this.effectSlug,
    this.beautyEnabled = false,
    this.arFilterId,
  });

  final List<File> files;
  final String? filterName;
  final CameraFilterCategory filterCategory;
  final String? effectSlug;
  final bool beautyEnabled;
  final String? arFilterId;
}

/// Initial filter/effect choices when opening the editor from the camera.
class MediaEditorSeed {
  const MediaEditorSeed({
    this.filterName,
    this.effectSlug,
    this.beautyEnabled = false,
    this.filterCategory = CameraFilterCategory.trending,
    this.arFilterId,
    this.arColorCategoryId,
    this.arFilterIntensity = 1.0,
    this.alreadyBaked = false,
  });

  final String? filterName;
  final String? effectSlug;
  final bool beautyEnabled;
  final CameraFilterCategory filterCategory;
  final String? arFilterId;
  final String? arColorCategoryId;
  final double arFilterIntensity;
  final bool alreadyBaked;

  Map<String, dynamic> toExtra() => {
        if (filterName != null) 'filterName': filterName,
        if (effectSlug != null) 'effectSlug': effectSlug,
        'beautyEnabled': beautyEnabled,
        'filterCategory': filterCategory.name,
        if (arFilterId != null) 'arFilterId': arFilterId,
        if (arColorCategoryId != null) 'arColorCategoryId': arColorCategoryId,
        'arFilterIntensity': arFilterIntensity,
        'alreadyBaked': alreadyBaked,
      };

  static MediaEditorSeed? fromExtra(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final legacyEffect = map['effect'] as String?;
    final effectSlug = map['effectSlug'] as String? ?? legacyEffect;
    return MediaEditorSeed(
      filterName: map['filterName'] as String?,
      effectSlug: effectSlug,
      beautyEnabled: map['beautyEnabled'] as bool? ?? false,
      filterCategory:
          CameraFilterCategory.values.asNameMap()[map['filterCategory']
              as String?] ??
          CameraFilterCategory.trending,
      arFilterId: map['arFilterId'] as String?,
      arColorCategoryId: map['arColorCategoryId'] as String?,
      arFilterIntensity: (map['arFilterIntensity'] as num?)?.toDouble() ?? 1.0,
      alreadyBaked: map['alreadyBaked'] as bool? ?? false,
    );
  }
}

List<GalleryMediaItem> galleryItemsFromExtra(List<dynamic> raw) {
  return raw
      .map((entry) {
        final map = entry as Map<String, dynamic>;
        return GalleryMediaItem(
          file: File(map['path'] as String),
          type:
              map['type'] as String? ??
              MediaGalleryPicker.typeForPath(map['path'] as String),
        );
      })
      .toList(growable: false);
}
