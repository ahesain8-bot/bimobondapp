import 'dart:convert';

// =============================================================================
// COLOR / BEAUTY FILTERS CATALOG — Backend API Contract + App Model
// =============================================================================
//
// DASHBOARD / DYNAMIC (beauty — new approach):
//   Filters are TikTok-style beauty presets. Dashboard sends numbers + thumbnail
//   — NO .cube, NO lutUrl, NO LUT PNG for API filters.
//
// APP STATIC (offline):
//   Bundled LUT filters still live in ar_color_filter_bundled_catalog.dart for
//   local testing. Soft Glow is the beauty test entry (type: "beauty").
//
// ENDPOINT
//   GET /camera-studio/color-filters
//   Optional wrapper: { "data": { …catalog… } }
//
// ── DASHBOARD — REQUIRED FIELDS ONLY (beauty) ───────────────────────────────
//
// Filter — FLAT object, 7 beauty values required:
//   • id, label, type ("beauty"), thumbnailUrl
//   • smooth, whiten, brighten, blush, lipTint, lipStrength, defaultIntensity
//
// {
//   "id": "soft_glow",
//   "label": "Soft Glow",
//   "type": "beauty",
//   "thumbnailUrl": "https://cdn.example.com/thumbs/soft_glow.jpg",
//   "smooth": 0.65,
//   "whiten": 0.55,
//   "brighten": 0.40,
//   "blush": 0.25,
//   "lipTint": "#E8527A",
//   "lipStrength": 0.45,
//   "defaultIntensity": 0.7
// }
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
  beauty,
  lut;

  static ArColorFilterRenderType fromJson(dynamic raw) {
    final s = raw?.toString().toLowerCase();
    if (s == 'beauty') return ArColorFilterRenderType.beauty;
    if (s == 'lut') return ArColorFilterRenderType.lut;
    return ArColorFilterRenderType.lut;
  }

  String toJson() => name;
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
    this.type = ArColorFilterRenderType.lut,
    this.lutUrl,
    this.lutAsset,
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

  /// Bundled / CDN LUT (static offline filters only).
  final String? lutUrl;
  final String? lutAsset;

  final String? thumbnailUrl;
  final String? emoji;
  final String? previewColorHex;

  /// Beauty: first intensity when picked (0…1).
  final double defaultIntensity;

  /// Beauty shader params (required when [type] is beauty).
  final ArBeautyFilterParams? params;
  final int sortOrder;

  bool get isBeauty => type == ArColorFilterRenderType.beauty;
  bool get isLut => type == ArColorFilterRenderType.lut;

  /// Prefer [type]; kept for older call sites that still read renderType.
  ArColorFilterRenderType get renderType => type;

  factory ArColorFilterItemModel.fromJson(Map<String, dynamic> json) {
    final lutUrl = json['lutUrl']?.toString();
    final lutAsset = json['lutAsset']?.toString();
    final typeRaw = json['type'] ?? json['renderType'];
    final hasBeautyKeys = json.containsKey('smooth') ||
        json.containsKey('whiten') ||
        json.containsKey('defaultIntensity') ||
        json['params'] is Map;

    final type = typeRaw != null
        ? ArColorFilterRenderType.fromJson(typeRaw)
        : (hasBeautyKeys
            ? ArColorFilterRenderType.beauty
            : ArColorFilterRenderType.lut);

    ArBeautyFilterParams? params;
    if (type == ArColorFilterRenderType.beauty) {
      final paramsRaw = json['params'];
      final source = paramsRaw is Map
          ? Map<String, dynamic>.from(paramsRaw)
          : json;
      params = ArBeautyFilterParams.fromJson(source);
    }

    return ArColorFilterItemModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: type,
      lutUrl: lutUrl,
      lutAsset: lutAsset,
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      emoji: json['emoji']?.toString(),
      previewColorHex: json['previewColorHex']?.toString(),
      defaultIntensity:
          _readDouble01(json['defaultIntensity'], fallback: 0.7),
      params: params,
      sortOrder: _readInt(json['sortOrder']),
    );
  }

  Map<String, dynamic> toJson() {
    if (type == ArColorFilterRenderType.beauty) {
      final p = params ?? ArBeautyFilterParams.defaults;
      return {
        'id': id,
        'label': label,
        'type': 'beauty',
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
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
    return {
      'id': id,
      'label': label,
      'type': 'lut',
      if (lutUrl != null) 'lutUrl': lutUrl,
      if (lutAsset != null) 'lutAsset': lutAsset,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (emoji != null) 'emoji': emoji,
      if (previewColorHex != null) 'previewColorHex': previewColorHex,
      'sortOrder': sortOrder,
    };
  }

  bool get hasValidBeauty =>
      isBeauty &&
      id.trim().isNotEmpty &&
      label.trim().isNotEmpty &&
      ((thumbnailUrl ?? '').trim().isNotEmpty ||
          (emoji ?? '').trim().isNotEmpty);

  bool get hasValidLut =>
      (lutUrl != null && lutUrl!.isNotEmpty) ||
      (lutAsset != null && lutAsset!.isNotEmpty);

  String? get bundledLutPath =>
      lutAsset != null && lutAsset!.isNotEmpty ? 'assets/luts/$lutAsset' : null;
}

extension ArColorFilterCatalogBeautySanitize on ArColorFilterCatalog {
  /// Keeps dashboard beauty filters that have required fields.
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
