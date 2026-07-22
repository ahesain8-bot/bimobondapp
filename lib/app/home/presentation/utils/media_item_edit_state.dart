import 'dart:io';

import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_compositor.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/core/utils/video_trim_segment.dart';
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
    this.faceSaturation = 0,
    this.faceBrightness = 0,
    this.faceContrast = 0,
    this.faceExposure = 0,
    this.faceWhiteBalance = 0,
    this.faceHighlights = 0,
    this.faceShadows = 0,
    this.faceNose = 0,
    this.alreadyBaked = false,
    this.bakedArFilterId = 'none',
    this.textOverlays = const [],
    this.trimSegments = const [],
    File? croppedFile,
  })  : filter = filter ?? AwesomeFilter.None,
        _croppedFile = croppedFile;

  final GalleryMediaItem item;
  final AwesomeFilter filter;
  final String? effectSlug;
  final bool beautyEnabled;
  final CameraFilterCategory filterCategory;

  /// Live AR camera catalog id (`none`, `glasses`, `whitening`, …).
  final String arFilterId;
  final String arColorCategoryId;
  final double arFilterIntensity;

  /// Face → Saturation (-1…1). 0 = original, + = more color, − = B&W.
  final double faceSaturation;

  /// Tone/color adjustments (-1…1, 0 = original). Native OpenCV.
  final double faceBrightness;
  final double faceContrast;
  final double faceExposure;
  final double faceWhiteBalance;
  final double faceHighlights;
  final double faceShadows;

  /// Face → Nose width (-1…1). 0 = original, + = wider, − = slimmer.
  final double faceNose;

  /// True when native capture already baked AR look into pixels.
  final bool alreadyBaked;

  /// Original AR id baked into the file (immutable for this source).
  final String bakedArFilterId;

  /// Text stickers placed on this item (baked into the export for images).
  final List<MediaTextOverlay> textOverlays;

  /// Kept ranges of a video's timeline (trim / split / delete). Empty = full
  /// clip. Only meaningful for video items.
  final List<VideoTrimSegment> trimSegments;

  /// When the user crops the item, the cropped result replaces the source
  /// pixels for preview + export while the original [item] reference stays.
  final File? _croppedFile;

  File? get croppedFile => _croppedFile;

  /// The pixels to display/export: the cropped file if present, else original.
  File get sourceFile => _croppedFile ?? item.file;
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
    double? faceSaturation,
    double? faceBrightness,
    double? faceContrast,
    double? faceExposure,
    double? faceWhiteBalance,
    double? faceHighlights,
    double? faceShadows,
    double? faceNose,
    bool? alreadyBaked,
    String? bakedArFilterId,
    List<MediaTextOverlay>? textOverlays,
    List<VideoTrimSegment>? trimSegments,
    File? croppedFile,
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
      faceSaturation: faceSaturation ?? this.faceSaturation,
      faceBrightness: faceBrightness ?? this.faceBrightness,
      faceContrast: faceContrast ?? this.faceContrast,
      faceExposure: faceExposure ?? this.faceExposure,
      faceWhiteBalance: faceWhiteBalance ?? this.faceWhiteBalance,
      faceHighlights: faceHighlights ?? this.faceHighlights,
      faceShadows: faceShadows ?? this.faceShadows,
      faceNose: faceNose ?? this.faceNose,
      alreadyBaked: alreadyBaked ?? this.alreadyBaked,
      bakedArFilterId: bakedArFilterId ?? this.bakedArFilterId,
      textOverlays: textOverlays ?? this.textOverlays,
      trimSegments: trimSegments ?? this.trimSegments,
      croppedFile: croppedFile ?? _croppedFile,
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
      faceSaturation: seed.faceSaturation,
      faceBrightness: seed.faceBrightness,
      faceContrast: seed.faceContrast,
      faceExposure: seed.faceExposure,
      faceWhiteBalance: seed.faceWhiteBalance,
      faceHighlights: seed.faceHighlights,
      faceShadows: seed.faceShadows,
      faceNose: seed.faceNose,
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
    this.sound,
  });

  final List<File> files;
  final String? filterName;
  final CameraFilterCategory filterCategory;
  final String? effectSlug;
  final bool beautyEnabled;
  final String? arFilterId;
  /// Sound chosen in the studio (may differ from the caller's initial sound).
  final SoundEntity? sound;
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
    this.faceSaturation = 0,
    this.faceBrightness = 0,
    this.faceContrast = 0,
    this.faceExposure = 0,
    this.faceWhiteBalance = 0,
    this.faceHighlights = 0,
    this.faceShadows = 0,
    this.faceNose = 0,
  });

  final String? filterName;
  final String? effectSlug;
  final bool beautyEnabled;
  final CameraFilterCategory filterCategory;
  final String? arFilterId;
  final String? arColorCategoryId;
  final double arFilterIntensity;
  final bool alreadyBaked;
  final double faceSaturation;
  final double faceBrightness;
  final double faceContrast;
  final double faceExposure;
  final double faceWhiteBalance;
  final double faceHighlights;
  final double faceShadows;
  final double faceNose;

  Map<String, dynamic> toExtra() => {
        if (filterName != null) 'filterName': filterName,
        if (effectSlug != null) 'effectSlug': effectSlug,
        'beautyEnabled': beautyEnabled,
        'filterCategory': filterCategory.name,
        if (arFilterId != null) 'arFilterId': arFilterId,
        if (arColorCategoryId != null) 'arColorCategoryId': arColorCategoryId,
        'arFilterIntensity': arFilterIntensity,
        'alreadyBaked': alreadyBaked,
        'faceSaturation': faceSaturation,
        'faceBrightness': faceBrightness,
        'faceContrast': faceContrast,
        'faceExposure': faceExposure,
        'faceWhiteBalance': faceWhiteBalance,
        'faceHighlights': faceHighlights,
        'faceShadows': faceShadows,
        'faceNose': faceNose,
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
      faceSaturation: (map['faceSaturation'] as num?)?.toDouble() ?? 0,
      faceBrightness: (map['faceBrightness'] as num?)?.toDouble() ?? 0,
      faceContrast: (map['faceContrast'] as num?)?.toDouble() ?? 0,
      faceExposure: (map['faceExposure'] as num?)?.toDouble() ?? 0,
      faceWhiteBalance: (map['faceWhiteBalance'] as num?)?.toDouble() ?? 0,
      faceHighlights: (map['faceHighlights'] as num?)?.toDouble() ?? 0,
      faceShadows: (map['faceShadows'] as num?)?.toDouble() ?? 0,
      faceNose: (map['faceNose'] as num?)?.toDouble() ?? 0,
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
