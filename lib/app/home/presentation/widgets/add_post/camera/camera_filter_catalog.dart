import 'package:bimobondapp/app/camera_studio/data/models/camera_studio_catalog_model.dart';
import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/camera_studio/presentation/utils/camera_studio_l10n.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

enum CameraFilterCategory { trending, newFilters, portrait, vibe, landscape }

/// Camera filter catalog loaded from `GET /camera-studio/catalog`.
class CameraFilterCatalog {
  CameraFilterCatalog._();

  static CameraStudioCatalogEntity _catalog = CameraStudioCatalogModel.empty;

  static CameraStudioCatalogEntity get bundledCatalog =>
      CameraStudioCatalogModel.bundled();

  static CameraStudioCatalogEntity get activeCatalog => _catalog;

  static bool isBackendCatalog(CameraStudioCatalogEntity catalog) {
    return catalog.filterCategories.isNotEmpty &&
        catalog.version.isNotEmpty &&
        catalog.version != 'bundled';
  }

  static bool get hasBackendCatalog => isBackendCatalog(_catalog);

  static void apply(CameraStudioCatalogEntity catalog) {
    if (!isBackendCatalog(catalog)) return;
    _catalog = catalog;
  }

  /// Active filter tabs from `GET /camera-studio/catalog`.
  static List<CameraFilterCategoryEntity> get filterCategories {
    if (!hasBackendCatalog) return const [];
    return _sortedFilterCategories;
  }

  static List<CameraFilterCategoryEntity> get _sortedFilterCategories {
    final categories = List<CameraFilterCategoryEntity>.from(
      _catalog.filterCategories,
    )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  static List<CameraFilterCategory> get availableCategories {
    if (!hasBackendCatalog) return const [];
    return _sortedFilterCategories
        .map((category) => _categoryFromSlug(category.slug))
        .whereType<CameraFilterCategory>()
        .toList(growable: false);
  }

  /// CamerAwesome presets enabled on the camera — backend catalog only.
  static List<AwesomeFilter> get gpuFiltersForCamera {
    if (!hasBackendCatalog) return [AwesomeFilter.None];
    final filters = <AwesomeFilter>{AwesomeFilter.None};
    for (final category in _sortedFilterCategories) {
      for (final entity in category.filters) {
        filters.add(
          filterFromEngineKey(entity.engineKey, isOriginal: entity.isOriginal),
        );
      }
    }
    return filters.toList(growable: false);
  }

  static CameraFilterCategory? categoryFromSlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    return _categoryFromSlug(slug);
  }

  static String categorySlug(CameraFilterCategory category) => category.name;

  static String categoryLabelKey(CameraFilterCategory category) {
    final match = _sortedFilterCategories.where(
      (entry) => entry.slug == category.name,
    );
    if (match.isNotEmpty) return match.first.labelKey;
    return switch (category) {
      CameraFilterCategory.trending => 'cameraCategoryTrending',
      CameraFilterCategory.newFilters => 'cameraCategoryNew',
      CameraFilterCategory.portrait => 'cameraCategoryPortrait',
      CameraFilterCategory.vibe => 'cameraCategoryVibe',
      CameraFilterCategory.landscape => 'cameraCategoryLandscape',
    };
  }

  static String localizedCategoryLabel(
    AppLocalizations l10n,
    CameraFilterCategory category,
  ) {
    return cameraStudioLabelFromKey(l10n, categoryLabelKey(category));
  }

  static CameraFilterCategoryEntity? _categoryEntity(
    CameraFilterCategory category,
  ) {
    for (final entry in _sortedFilterCategories) {
      if (entry.slug == category.name) return entry;
    }
    return null;
  }

  static CameraFilterCategory? _categoryFromSlug(String slug) {
    return CameraFilterCategory.values.asNameMap()[slug];
  }

  static CameraFilterPreset get original {
    for (final category in _sortedFilterCategories) {
      for (final filter in category.filters) {
        if (filter.isOriginal) return presetFromEntity(filter);
      }
    }
    return presetFromEngineKey('Original', isOriginal: true);
  }

  static CameraFilterPreset get beautyFilter {
    for (final category in _sortedFilterCategories) {
      for (final filter in category.filters) {
        if (filter.isBeautyDefault) return presetFromEntity(filter);
      }
    }
    return presetFromEngineKey('Aden', customLabel: 'Glow');
  }

  static AwesomeFilter filterByName(String name) {
    if (name == 'Original') return AwesomeFilter.None;
    final preset = presetForName(name);
    if (preset != null) return preset.filter;
    return AwesomeFilter.None;
  }

  static AwesomeFilter filterFromEngineKey(
    String engineKey, {
    bool isOriginal = false,
  }) {
    if (isOriginal || engineKey == 'Original') return AwesomeFilter.None;
    for (final filter in awesomePresetFiltersList) {
      if (filter.name == engineKey) return filter;
    }
    return AwesomeFilter.None;
  }

  static CameraFilterPreset? presetForName(String name) {
    for (final category in _sortedFilterCategories) {
      for (final filter in category.filters) {
        if (filter.engineKey == name ||
            (name == 'Original' && filter.isOriginal)) {
          return presetFromEntity(filter);
        }
      }
    }
    return null;
  }

  static CameraFilterCategory categoryForFilter(AwesomeFilter filter) {
    for (final category in availableCategories) {
      final presets = forCategory(category);
      if (presets.any((preset) => preset.filter.name == filter.name)) {
        return category;
      }
    }
    return availableCategories.isNotEmpty
        ? availableCategories.first
        : CameraFilterCategory.trending;
  }

  static String localizedFilterLabel(AppLocalizations l10n, String filterName) {
    final preset = presetForName(filterName);
    if (preset == null) return filterName;
    return preset.label(l10n: l10n);
  }

  static bool isUsableFilterName(String? filterName) {
    if (filterName == null || filterName.isEmpty) return false;
    if (filterName == 'Original') return false;
    return presetForName(filterName) != null;
  }

  static List<CameraFilterPreset> forCategorySlug(String slug) {
    if (!hasBackendCatalog) return const [];
    for (final category in _sortedFilterCategories) {
      if (category.slug == slug) {
        return category.filters.map(presetFromEntity).toList(growable: false);
      }
    }
    return const [];
  }

  static List<CameraFilterPreset> forCategory(CameraFilterCategory category) {
    return forCategorySlug(category.name);
  }

  static String labelForCategory(
    AppLocalizations l10n,
    CameraFilterCategoryEntity category,
  ) {
    return cameraStudioLabelFromKey(l10n, category.labelKey);
  }

  static CameraFilterPreset presetFromEntity(CameraFilterEntity entity) {
    return CameraFilterPreset(
      filter: filterFromEngineKey(
        entity.engineKey,
        isOriginal: entity.isOriginal,
      ),
      customLabel: entity.customLabel,
      labelKey: entity.labelKey,
      thumbnailUrl: entity.thumbnailUrl,
      previewColor: parsePreviewColorHex(entity.previewColorHex),
      slug: entity.slug,
      isOriginal: entity.isOriginal,
    );
  }

  static CameraFilterPreset presetFromEngineKey(
    String engineKey, {
    String? customLabel,
    bool isOriginal = false,
  }) {
    final filter = filterFromEngineKey(engineKey, isOriginal: isOriginal);
    return CameraFilterPreset(
      filter: filter,
      customLabel: customLabel,
      isOriginal: isOriginal,
      previewColor: previewColor(filter),
    );
  }

  static Color previewColor(AwesomeFilter filter) {
    for (final category in _sortedFilterCategories) {
      for (final entry in category.filters) {
        final mapped = filterFromEngineKey(
          entry.engineKey,
          isOriginal: entry.isOriginal,
        );
        if (mapped.name == filter.name) {
          return parsePreviewColorHex(entry.previewColorHex) ??
              _fallbackPreviewColor(filter);
        }
      }
    }
    return _fallbackPreviewColor(filter);
  }

  static Color _fallbackPreviewColor(AwesomeFilter filter) {
    return switch (filter.name) {
      'Original' => const Color(0xFFE8D5C4),
      'Addictive Red' => const Color(0xFFE07A7A),
      'Addictive Blue' => const Color(0xFF7EB8DA),
      'Amaro' => const Color(0xFFE8A87C),
      'Aden' => const Color(0xFFF4A6C7),
      'Inkwell' => const Color(0xFF9E9E9E),
      'Moon' => const Color(0xFF6B705C),
      'Brooklyn' => const Color(0xFFC9A66B),
      'Juno' => const Color(0xFFFFD166),
      'Lark' => const Color(0xFF90CAF9),
      'Reyes' => const Color(0xFFD4A574),
      'Clarendon' => const Color(0xFF5C9EAD),
      'Hefe' => const Color(0xFFCD853F),
      'Hudson' => const Color(0xFF4682B4),
      'LoFi' => const Color(0xFF8B7355),
      'Sutro' => const Color(0xFF4A5568),
      'Walden' => const Color(0xFF2E8B57),
      'XProII' => const Color(0xFFBC8F8F),
      _ => const Color(0xFF7A7A7A),
    };
  }
}
