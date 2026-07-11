import 'dart:io';

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_compositor.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';

/// Per-item filter/effect choices in the media studio editor.
class MediaItemEditState {
  MediaItemEditState({
    required this.item,
    AwesomeFilter? filter,
    this.effectSlug,
    this.beautyEnabled = false,
    this.filterCategory = CameraFilterCategory.trending,
  }) : filter = filter ?? AwesomeFilter.None;

  final GalleryMediaItem item;
  final AwesomeFilter filter;
  final String? effectSlug;
  final bool beautyEnabled;
  final CameraFilterCategory filterCategory;

  File get sourceFile => item.file;
  bool get isVideo => item.isVideo;

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
  }) {
    return MediaItemEditState(
      item: item,
      filter: filter ?? this.filter,
      effectSlug: effectSlug,
      beautyEnabled: beautyEnabled ?? this.beautyEnabled,
      filterCategory: filterCategory ?? this.filterCategory,
    );
  }

  factory MediaItemEditState.fromItem(GalleryMediaItem item) {
    return MediaItemEditState(item: item);
  }

  factory MediaItemEditState.fromItemWithSeed(
    GalleryMediaItem item,
    MediaEditorSeed seed,
  ) {
    return MediaItemEditState(
      item: item,
      filter: seed.filterName != null
          ? CameraFilterCatalog.filterByName(seed.filterName!)
          : null,
      effectSlug: seed.effectSlug,
      beautyEnabled: seed.beautyEnabled,
      filterCategory: seed.filterCategory,
    );
  }
}

String? primaryFilterNameFromStates(List<MediaItemEditState> states) {
  for (final state in states) {
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
    final slug = state.effectSlug;
    if (slug != null && slug.isNotEmpty && slug != 'none') return slug;
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
  });

  final List<File> files;
  final String? filterName;
  final CameraFilterCategory filterCategory;
  final String? effectSlug;
  final bool beautyEnabled;
}

/// Initial filter/effect choices when opening the editor from the camera.
class MediaEditorSeed {
  const MediaEditorSeed({
    this.filterName,
    this.effectSlug,
    this.beautyEnabled = false,
    this.filterCategory = CameraFilterCategory.trending,
  });

  final String? filterName;
  final String? effectSlug;
  final bool beautyEnabled;
  final CameraFilterCategory filterCategory;

  Map<String, dynamic> toExtra() => {
    if (filterName != null) 'filterName': filterName,
    if (effectSlug != null) 'effectSlug': effectSlug,
    'beautyEnabled': beautyEnabled,
    'filterCategory': filterCategory.name,
  };

  static MediaEditorSeed? fromExtra(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final legacyEffect = raw['effect'] as String?;
    final effectSlug = raw['effectSlug'] as String? ?? legacyEffect;
    return MediaEditorSeed(
      filterName: raw['filterName'] as String?,
      effectSlug: effectSlug,
      beautyEnabled: raw['beautyEnabled'] as bool? ?? false,
      filterCategory:
          CameraFilterCategory.values.asNameMap()[raw['filterCategory']
              as String?] ??
          CameraFilterCategory.trending,
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
