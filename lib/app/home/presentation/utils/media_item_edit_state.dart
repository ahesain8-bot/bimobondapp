import 'dart:io';

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';

/// Per-item filter/effect choices in the media studio editor.
class MediaItemEditState {
  MediaItemEditState({
    required this.item,
    AwesomeFilter? filter,
    this.effect,
    this.beautyEnabled = false,
    this.filterCategory = CameraFilterCategory.trending,
  }) : filter = filter ?? AwesomeFilter.None;

  final GalleryMediaItem item;
  final AwesomeFilter filter;
  final CameraEffectId? effect;
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
    CameraEffectId? effect,
    bool? beautyEnabled,
    CameraFilterCategory? filterCategory,
  }) {
    return MediaItemEditState(
      item: item,
      filter: filter ?? this.filter,
      effect: effect,
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
      effect: seed.effect,
      beautyEnabled: seed.beautyEnabled,
      filterCategory: seed.filterCategory,
    );
  }
}

/// Initial filter/effect choices when opening the editor from the camera.
class MediaEditorSeed {
  const MediaEditorSeed({
    this.filterName,
    this.effect,
    this.beautyEnabled = false,
    this.filterCategory = CameraFilterCategory.trending,
  });

  final String? filterName;
  final CameraEffectId? effect;
  final bool beautyEnabled;
  final CameraFilterCategory filterCategory;

  Map<String, dynamic> toExtra() => {
    if (filterName != null) 'filterName': filterName,
    if (effect != null) 'effect': effect!.name,
    'beautyEnabled': beautyEnabled,
    'filterCategory': filterCategory.name,
  };

  static MediaEditorSeed? fromExtra(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final effectName = raw['effect'] as String?;
    return MediaEditorSeed(
      filterName: raw['filterName'] as String?,
      effect: effectName == null
          ? null
          : CameraEffectId.values.asNameMap()[effectName],
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
