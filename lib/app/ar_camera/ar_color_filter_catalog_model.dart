import 'dart:convert';

// ---------------------------------------------------------------------------
// COLOR FILTERS CATALOG — Backend API Contract + App Model
// ---------------------------------------------------------------------------
//
// Full spec: docs/backend-ar-camera-api.md
//
// ENDPOINT
//   GET /camera-studio/color-filters
//   Optional wrapper: { "data": { …catalog… } }
//   Offline fallback in app: ar_color_filter_bundled_catalog.dart
//
// WHAT THIS POWERS
//   Filters panel in AR camera (Portrait, Life, Retro, Film tabs).
//   Every filter is a 3D LUT applied on the GPU (PNG texture) — NOT colorMatrix.
//
// ── BACKEND: HOW TO ADD / UPDATE A FILTER (dashboard) ─────────────────────
//
//   1. Pick category: portrait | life | retro | film  (or create a new one)
//   2. Set unique `id` (snake_case) — do NOT rename after release (native maps by id)
//   3. Set label, sortOrder, emoji, previewColorHex, thumbnailUrl (carousel icon)
//   4. Upload a .cube file from Lightroom / Photoshop (designer source)
//   5. Backend converts .cube → 512×512 PNG and stores on CDN
//   6. Return lutUrl in JSON (required for online dynamic filters)
//   7. Optional lutAsset = bundled filename for offline app builds
//   8. Bump top-level `version` whenever the catalog changes
//
// ── DASHBOARD UPLOADS ───────────────────────────────────────────────────────
//
//   Designer uploads:  .cube file  (stored on server only — never sent to app)
//   Backend produces: 512×512 PNG on CDN → lutUrl
//   Optional:          thumbnail JPG/PNG → thumbnailUrl
//   API JSON fields:   id, label, category, sortOrder, emoji, previewColorHex,
//                      renderType: "lut", lutUrl, lutAsset
//
// ── .cube → PNG PIPELINE (backend job, not mobile) ────────────────────────
//
//   .cube upload → convert to 512×512 PNG (GPUImage layout: 8×8 tiles of 64×64)
//   → upload PNG to CDN → set lutUrl in API response
//   Dev conversion tool in repo:
//     dart run tool/cube_to_lut_png.dart "input.cube" assets/luts/output.png
//
// ── EXAMPLE: dynamic Film filter (replaces static bundled list) ───────────
//
// {
//   "id": "going_for_a_walk",
//   "label": "Going for a Walk",
//   "renderType": "lut",
//   "sortOrder": 0,
//   "emoji": "🚶",
//   "previewColorHex": "#A8B89A",
//   "thumbnailUrl": "https://cdn.example.com/thumbs/going_for_a_walk.jpg",
//   "lutUrl": "https://cdn.example.com/luts/going_for_a_walk.png",
//   "lutAsset": "going_for_a_walk.png"
// }
//
// App behaviour:
//   • Online: downloads/applies PNG from lutUrl
//   • Offline / bundled: uses assets/luts/{lutAsset} if present
//   • Film category filters are loaded from this API — not hardcoded in app
//
// ── LUT PNG RULES ─────────────────────────────────────────────────────────
//
//   Size:     512 × 512 px, 8-bit RGB PNG
//   Layout:   GPUImage 64³ cube (must match tool/cube_to_lut_png.dart output)
//   Filename: lowercase_snake_case.png
//   Mobile app NEVER parses .cube at runtime.

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

/// All color filters use 3D LUT PNGs. [ArColorFilterRenderType.lut] only.
enum ArColorFilterRenderType {
  lut;

  static ArColorFilterRenderType fromJson(dynamic raw) {
    final s = raw?.toString().toLowerCase();
    if (s == 'lut') return ArColorFilterRenderType.lut;
    // Legacy API may omit renderType when lutUrl/lutAsset is present.
    return ArColorFilterRenderType.lut;
  }

  String toJson() => 'lut';
}

class ArColorFilterItemModel {
  const ArColorFilterItemModel({
    required this.id,
    required this.label,
    this.renderType = ArColorFilterRenderType.lut,
    this.lutUrl,
    this.lutAsset,
    this.thumbnailUrl,
    this.emoji,
    this.previewColorHex,
    this.sortOrder = 0,
  });

  final String id;
  final String label;

  /// Always [ArColorFilterRenderType.lut] for color filters.
  final ArColorFilterRenderType renderType;

  /// HTTPS URL to 512×512 LUT PNG on CDN. Required for server-driven filters.
  final String? lutUrl;

  /// Bundled filename under assets/luts/ for offline fallback, e.g. warm.png
  final String? lutAsset;

  /// Small image for filter carousel (optional — emoji used if missing).
  final String? thumbnailUrl;

  final String? emoji;
  final String? previewColorHex;
  final int sortOrder;

  factory ArColorFilterItemModel.fromJson(Map<String, dynamic> json) {
    final lutUrl = json['lutUrl']?.toString();
    final lutAsset = json['lutAsset']?.toString();
    return ArColorFilterItemModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      renderType: json.containsKey('renderType')
          ? ArColorFilterRenderType.fromJson(json['renderType'])
          : (lutUrl != null || lutAsset != null)
              ? ArColorFilterRenderType.lut
              : ArColorFilterRenderType.lut,
      lutUrl: lutUrl,
      lutAsset: lutAsset,
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      emoji: json['emoji']?.toString(),
      previewColorHex: json['previewColorHex']?.toString(),
      sortOrder: _readInt(json['sortOrder']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'renderType': renderType.toJson(),
        if (lutUrl != null) 'lutUrl': lutUrl,
        if (lutAsset != null) 'lutAsset': lutAsset,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (emoji != null) 'emoji': emoji,
        if (previewColorHex != null) 'previewColorHex': previewColorHex,
        'sortOrder': sortOrder,
      };

  /// Server filter is valid when at least one LUT source is provided.
  bool get hasValidLut =>
      (lutUrl != null && lutUrl!.isNotEmpty) ||
      (lutAsset != null && lutAsset!.isNotEmpty);

  /// Bundled asset path used by native Kotlin when lutUrl is unavailable.
  String? get bundledLutPath =>
      lutAsset != null && lutAsset!.isNotEmpty ? 'assets/luts/$lutAsset' : null;
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
