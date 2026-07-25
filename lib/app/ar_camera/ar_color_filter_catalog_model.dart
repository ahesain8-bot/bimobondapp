import 'dart:convert';

/// Used when a backend filter ships with neither `thumbnailUrl` nor `emoji`
/// set — see [ArColorFilterItemModel.fromJson]. Without a fallback, such a
/// filter fails [ArColorFilterItemModel.hasValidBeauty] and is silently
/// dropped from the list entirely.
const String _fallbackEmoji = '🎨';

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
// Real backend response shape (see ar_color_filter_backend_guide.dart /
// the camera-studio API docs): filter values are nested one level under a
// "filterSettings" object, as 0-100 integers (one-direction fields: 0=off,
// 100=max; balanced fields brightness/contrast/saturation/warmth: 50=neutral,
// 0/100=max in either direction). "filterSettings" is omitted entirely for a
// no-effect filter (e.g. "Normal"). This file converts those 0-100 ints to
// the 0..1 / -1..1 decimals the native shader pipeline expects.
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
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
  });

  final double smooth;
  final double whiten;
  final double brighten;
  final double blush;
  final String lipTint;
  final double lipStrength;

  /// Color grade (-1..1, 0 = neutral) — same engine as the Face retouch
  /// sliders (ArCameraBridge.setRetouchAdjustments), already proven stable.
  /// Lets a filter be a pure color look (e.g. "Fade") with no beauty effect.
  final double brightness;
  final double contrast;
  final double saturation;
  final double warmth;

  bool get hasColorGrade =>
      brightness != 0 || contrast != 0 || saturation != 0 || warmth != 0;

  static const ArBeautyFilterParams defaults = ArBeautyFilterParams(
    smooth: 0.55,
    whiten: 0.55,
    brighten: 0.40,
    blush: 0.20,
    lipTint: '#E8527A',
    lipStrength: 0.40,
  );

  /// Parses the backend's 0-100 `filterSettings` object into this class's
  /// 0..1 / -1..1 decimals. [json] is the `filterSettings` map itself (NOT
  /// the whole filter object) — see [ArColorFilterItemModel.fromJson].
  factory ArBeautyFilterParams.fromJson(Map<String, dynamic> json) {
    return ArBeautyFilterParams(
      smooth: _readUnipolar100(json['smooth'], fallbackPercent: 55),
      whiten: _readUnipolar100(json['whiten'], fallbackPercent: 0),
      brighten: _readUnipolar100(json['brighten'], fallbackPercent: 0),
      blush: _readUnipolar100(json['blush'], fallbackPercent: 0),
      lipTint: _readLipTint(json['lipTint']),
      lipStrength: _readUnipolar100(json['lipStrength'], fallbackPercent: 0),
      brightness: _readBalanced100(json['brightness'], fallbackPercent: 50),
      contrast: _readBalanced100(json['contrast'], fallbackPercent: 50),
      saturation: _readBalanced100(json['saturation'], fallbackPercent: 50),
      warmth: _readBalanced100(json['warmth'], fallbackPercent: 50),
    );
  }

  Map<String, dynamic> toJson() => {
        'smooth': smooth,
        'whiten': whiten,
        'brighten': brighten,
        'blush': blush,
        'lipTint': lipTint,
        'lipStrength': lipStrength,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'warmth': warmth,
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
    // Real backend shape: values live under "filterSettings" (0-100 ints).
    // "params" (flat, 0..1) is also accepted so bundled/offline JSON in the
    // old shape (if any) keeps working. No filterSettings/params at all (the
    // documented "Normal"/off filter case) means no beauty effect — leave
    // params null rather than guessing at ArBeautyFilterParams.defaults,
    // which would apply a strong look nobody authored.
    final settingsRaw = json['filterSettings'] ?? json['params'];
    final settings = settingsRaw is Map
        ? Map<String, dynamic>.from(settingsRaw)
        : null;

    final thumbnailUrl = json['thumbnailUrl']?.toString();
    final rawEmoji = json['emoji']?.toString();
    final hasThumbnail = (thumbnailUrl ?? '').trim().isNotEmpty;
    final hasEmoji = (rawEmoji ?? '').trim().isNotEmpty;
    // The app (and the guide handed to the backend) requires at least one of
    // thumbnailUrl/emoji, or hasValidBeauty silently drops the filter from
    // the list entirely. Backend responses have shipped without either on
    // real filters more than once — fall back to a generic emoji rather than
    // losing the filter outright; a thumbnail, once added backend-side,
    // still takes priority over this fallback.
    final emoji = hasEmoji
        ? rawEmoji
        : (hasThumbnail ? null : _fallbackEmoji);

    return ArColorFilterItemModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: ArColorFilterRenderType.beauty,
      thumbnailUrl: thumbnailUrl,
      emoji: emoji,
      previewColorHex: json['previewColorHex']?.toString(),
      defaultIntensity: settings != null
          ? _readUnipolar100(settings['defaultIntensity'], fallbackPercent: 70)
          : 0.7,
      params: settings != null ? ArBeautyFilterParams.fromJson(settings) : null,
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

double _readPercent(dynamic value, {required double fallbackPercent}) {
  double parsed;
  if (value is num) {
    parsed = value.toDouble();
  } else if (value is String) {
    parsed = double.tryParse(value) ?? fallbackPercent;
  } else {
    return fallbackPercent;
  }
  if (parsed < 0) return 0;
  if (parsed > 100) return 100;
  return parsed;
}

/// One-direction backend field (0-100, 0=off/100=max) -> internal 0..1.
double _readUnipolar100(dynamic value, {required double fallbackPercent}) {
  return _readPercent(value, fallbackPercent: fallbackPercent) / 100.0;
}

/// Balanced backend field (0-100, 50=neutral) -> internal -1..1.
double _readBalanced100(dynamic value, {required double fallbackPercent}) {
  return (_readPercent(value, fallbackPercent: fallbackPercent) - 50) / 50.0;
}

String _readLipTint(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return ArBeautyFilterParams.defaults.lipTint;
  final hex = raw.startsWith('#') ? raw : '#$raw';
  if (hex.length == 7) return hex.toUpperCase();
  return ArBeautyFilterParams.defaults.lipTint;
}
