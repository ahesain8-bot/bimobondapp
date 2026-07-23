import 'dart:convert';

// =============================================================================
// BEAUTY FILTERS CATALOG — Backend API Contract + App Model
// =============================================================================
//
// Filters are TikTok-style beauty presets. Dashboard sends numbers + thumbnail.
// NO .cube, NO lutUrl, NO LUT PNG.
//
// ENDPOINT: GET /camera-studio/color-filters
// Offline: ar_color_filter_bundled_catalog.dart
//
 // Required filter fields (flat):
//   id, label, type ("beauty"), thumbnailUrl (or emoji offline),
//   smooth, whiten, brighten, blush, lipTint, lipStrength, defaultIntensity
//
// =============================================================================

class ArColorFilterCatalog {
  const ArColorFilterCatalog({
    required this.version,
    required this.categories,
  });

  final String version;
  final List<ArColorFilterCategoryModel> categories;

  factory ArColorFilterCatalog.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return ArColorFilterCatalog.fromJson(data);
    }

    final raw = json['colorFilterCategories'];
    final categories = raw is List
        ? raw
            .whereType<Map>()
            .map(
              (e) => ArColorFilterCategoryModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false)
        : const <ArColorFilterCategoryModel>[];

    return ArColorFilterCatalog(
      version: json['version']?.toString() ?? 'bundled',
      categories: categories,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'colorFilterCategories':
            categories.map((c) => c.toJson()).toList(growable: false),
      };

  String encode() => jsonEncode(toJson());

  static ArColorFilterCatalog decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return ArColorFilterCatalog.fromJson(Map<String, dynamic>.from(decoded));
    }
    throw const FormatException('Invalid color filter catalog');
  }

  ArColorFilterItemModel? findFilter(String id) {
    for (final category in categories) {
      for (final filter in category.filters) {
        if (filter.id == id) return filter;
      }
    }
    return null;
  }
}

class ArColorFilterCategoryModel {
  const ArColorFilterCategoryModel({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.filters,
  });

  final String id;
  final String label;
  final int sortOrder;
  final List<ArColorFilterItemModel> filters;

  factory ArColorFilterCategoryModel.fromJson(Map<String, dynamic> json) {
    final raw = json['filters'];
    final filters = raw is List
        ? raw
            .whereType<Map>()
            .map(
              (e) => ArColorFilterItemModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false)
        : const <ArColorFilterItemModel>[];

    return ArColorFilterCategoryModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sortOrder: _readInt(json['sortOrder']),
      filters: filters,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'sortOrder': sortOrder,
        'filters': filters.map((f) => f.toJson()).toList(growable: false),
      };
}

enum ArColorFilterRenderType {
  beauty;

  static ArColorFilterRenderType fromJson(dynamic raw) {
    return ArColorFilterRenderType.beauty;
  }

  String toJson() => 'beauty';
}

class ArBeautyFilterParams {
  const ArBeautyFilterParams({
    required this.smooth,
    required this.whiten,
    required this.brighten,
    required this.blush,
    required this.lipTint,
    required this.lipStrength,
  });

  final double smooth;
  final double whiten;
  final double brighten;
  final double blush;
  final String lipTint;
  final double lipStrength;

  static const ArBeautyFilterParams defaults = ArBeautyFilterParams(
    smooth: 0.55,
    whiten: 0.55,
    brighten: 0.40,
    blush: 0.20,
    lipTint: '#E8527A',
    lipStrength: 0.40,
  );

  factory ArBeautyFilterParams.fromJson(Map<String, dynamic> json) {
    return ArBeautyFilterParams(
      smooth: _readDouble01(json['smooth'], fallback: defaults.smooth),
      whiten: _readDouble01(json['whiten'], fallback: defaults.whiten),
      brighten: _readDouble01(json['brighten'], fallback: defaults.brighten),
      blush: _readDouble01(json['blush'], fallback: defaults.blush),
      lipTint: _readLipTint(json['lipTint']),
      lipStrength:
          _readDouble01(json['lipStrength'], fallback: defaults.lipStrength),
    );
  }

  Map<String, dynamic> toJson() => {
        'smooth': smooth,
        'whiten': whiten,
        'brighten': brighten,
        'blush': blush,
        'lipTint': lipTint,
        'lipStrength': lipStrength,
      };
}

class ArColorFilterItemModel {
  const ArColorFilterItemModel({
    required this.id,
    required this.label,
    this.type = ArColorFilterRenderType.beauty,
    this.thumbnailUrl,
    this.emoji,
    this.previewColorHex,
    this.defaultIntensity = 0.7,
    this.params,
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final ArColorFilterRenderType type;
  final String? thumbnailUrl;
  final String? emoji;
  final String? previewColorHex;
  final double defaultIntensity;
  final ArBeautyFilterParams? params;
  final int sortOrder;

  bool get isBeauty => true;

  ArColorFilterRenderType get renderType => type;

  factory ArColorFilterItemModel.fromJson(Map<String, dynamic> json) {
    final paramsRaw = json['params'];
    final source = paramsRaw is Map
        ? Map<String, dynamic>.from(paramsRaw)
        : json;

    return ArColorFilterItemModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: ArColorFilterRenderType.beauty,
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      emoji: json['emoji']?.toString(),
      previewColorHex: json['previewColorHex']?.toString(),
      defaultIntensity:
          _readDouble01(json['defaultIntensity'], fallback: 0.7),
      params: ArBeautyFilterParams.fromJson(source),
      sortOrder: _readInt(json['sortOrder']),
    );
  }

  Map<String, dynamic> toJson() {
    final p = params ?? ArBeautyFilterParams.defaults;
    return {
      'id': id,
      'label': label,
      'type': 'beauty',
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (emoji != null) 'emoji': emoji,
      if (previewColorHex != null) 'previewColorHex': previewColorHex,
      'smooth': p.smooth,
      'whiten': p.whiten,
      'brighten': p.brighten,
      'blush': p.blush,
      'lipTint': p.lipTint,
      'lipStrength': p.lipStrength,
      'defaultIntensity': defaultIntensity,
      if (sortOrder != 0) 'sortOrder': sortOrder,
    };
  }

  bool get hasValidBeauty =>
      id.trim().isNotEmpty &&
      label.trim().isNotEmpty &&
      ((thumbnailUrl ?? '').trim().isNotEmpty ||
          (emoji ?? '').trim().isNotEmpty);
}

extension ArColorFilterCatalogBeautySanitize on ArColorFilterCatalog {
  ArColorFilterCatalog withValidBeautyOnly() {
    return ArColorFilterCatalog(
      version: version,
      categories: [
        for (final category in categories)
          ArColorFilterCategoryModel(
            id: category.id,
            label: category.label,
            sortOrder: category.sortOrder,
            filters: [
              for (final filter in category.filters)
                if (filter.hasValidBeauty) filter,
            ],
          ),
      ],
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _readDouble01(dynamic value, {required double fallback}) {
  double parsed;
  if (value is num) {
    parsed = value.toDouble();
  } else if (value is String) {
    parsed = double.tryParse(value) ?? fallback;
  } else {
    return fallback;
  }
  if (parsed < 0) return 0;
  if (parsed > 1) return 1;
  return parsed;
}

String _readLipTint(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return ArBeautyFilterParams.defaults.lipTint;
  final hex = raw.startsWith('#') ? raw : '#$raw';
  if (hex.length == 7) return hex.toUpperCase();
  return ArBeautyFilterParams.defaults.lipTint;
}
