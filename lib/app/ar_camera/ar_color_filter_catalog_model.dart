import 'dart:convert';

/// Data model for the AR color filters (Portrait / Life / Retro grades).
///
/// This mirrors the shape the backend stores in the database and returns from
/// the API (e.g. `GET /camera-studio/color-filters`). The app fetches it and
/// falls back to [ArColorFilterCatalog.bundled] when offline.
///
/// JSON shape:
/// {
///   "version": "2026-07-18T01",
///   "colorFilterCategories": [
///     {
///       "id": "portrait",
///       "label": "Portrait",
///       "sortOrder": 0,
///       "filters": [
///         {
///           "id": "whitening",
///           "label": "Pure",
///           "thumbnailUrl": "https://cdn.example.com/filters/pure.jpg",
///           "emoji": "🤍",                          // optional offline fallback
///           "previewColorHex": "#F0E0D0",          // optional placeholder color
///           "sortOrder": 0,
///           "adjustments": {                        // optional (dashboard sliders)
///             "brightness": 8, "contrast": 6, "saturation": 4,
///             "warmth": 10, "tint": 0, "exposure": 5, "fade": 0
///           },
///           "colorMatrix": [ /* exactly 20 numbers */ ]
///         }
///       ]
///     }
///   ]
/// }
class ArColorFilterCatalog {
  const ArColorFilterCatalog({
    required this.version,
    required this.categories,
  });

  final String version;
  final List<ArColorFilterCategoryModel> categories;

  factory ArColorFilterCatalog.fromJson(Map<String, dynamic> json) {
    // Allow the payload to be wrapped in { "data": { ... } }.
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

  /// Offline fallback = the values the app used to hardcode.
  static ArColorFilterCatalog bundled() {
    return const ArColorFilterCatalog(
      version: 'bundled',
      categories: [
        ArColorFilterCategoryModel(
          id: 'portrait',
          label: 'Portrait',
          sortOrder: 0,
          filters: [
            ArColorFilterItemModel(
              id: 'whitening',
              label: 'Pure',
              emoji: '🤍',
              sortOrder: 0,
              previewColorHex: '#F0E0D0',
              colorMatrix: [
                1.12, 0.02, 0.02, 0, 12, //
                0.02, 1.10, 0.02, 0, 10, //
                0.02, 0.02, 1.08, 0, 8, //
                0, 0, 0, 1, 0, //
              ],
            ),
            ArColorFilterItemModel(
              id: 'clarendon',
              label: 'Bright',
              emoji: '☀️',
              sortOrder: 1,
              previewColorHex: '#FFF3D6',
              colorMatrix: [
                1.15, -0.04, 0.04, 0, 8, //
                -0.02, 1.12, 0.02, 0, 4, //
                0.02, -0.06, 1.20, 0, 6, //
                0, 0, 0, 1, 0, //
              ],
            ),
            ArColorFilterItemModel(
              id: 'ludwig',
              label: 'Clean',
              emoji: '✨',
              sortOrder: 2,
              previewColorHex: '#EAF2F5',
              colorMatrix: [
                1.05, 0.02, 0.00, 0, 6, //
                0.00, 1.08, 0.02, 0, 4, //
                0.00, 0.00, 1.12, 0, 8, //
                0, 0, 0, 1, 0, //
              ],
            ),
            ArColorFilterItemModel(
              id: 'rosy',
              label: 'Soft',
              emoji: '🌸',
              sortOrder: 3,
              previewColorHex: '#F9DCE0',
              colorMatrix: [
                1.14, 0.04, 0.04, 0, 10, //
                0.02, 0.98, 0.02, 0, 4, //
                0.06, 0.02, 1.02, 0, 8, //
                0, 0, 0, 1, 0, //
              ],
            ),
            ArColorFilterItemModel(
              id: 'valencia',
              label: 'Sunset',
              emoji: '🌇',
              sortOrder: 4,
              previewColorHex: '#F7C9A3',
              colorMatrix: [
                1.18, 0.06, -0.02, 0, 14, //
                0.04, 1.06, -0.02, 0, 8, //
                -0.04, 0.00, 0.96, 0, 2, //
                0, 0, 0, 1, 0, //
              ],
            ),
          ],
        ),
        ArColorFilterCategoryModel(
          id: 'life',
          label: 'Life',
          sortOrder: 1,
          filters: [
            ArColorFilterItemModel(
              id: 'warm',
              label: 'Warm',
              emoji: '🍑',
              sortOrder: 0,
              previewColorHex: '#F6C6A0',
              colorMatrix: [
                1.16, 0.08, 0.00, 0, 12, //
                0.04, 1.06, 0.00, 0, 6, //
                -0.04, -0.02, 0.94, 0, 0, //
                0, 0, 0, 1, 0, //
              ],
            ),
            ArColorFilterItemModel(
              id: 'cool',
              label: 'Cool',
              emoji: '❄️',
              sortOrder: 1,
              previewColorHex: '#BFE0F2',
              colorMatrix: [
                0.94, 0.00, 0.06, 0, 0, //
                0.00, 1.02, 0.06, 0, 4, //
                0.04, 0.04, 1.18, 0, 10, //
                0, 0, 0, 1, 0, //
              ],
            ),
          ],
        ),
        ArColorFilterCategoryModel(
          id: 'retro',
          label: 'Retro',
          sortOrder: 2,
          filters: [
            ArColorFilterItemModel(
              id: 'vintage',
              label: 'Retro',
              emoji: '🎞️',
              sortOrder: 0,
              previewColorHex: '#D8C39A',
              colorMatrix: [
                0.95, 0.10, 0.05, 0, 8, //
                0.05, 0.90, 0.05, 0, 4, //
                0.05, 0.10, 0.78, 0, 0, //
                0, 0, 0, 1, 0, //
              ],
            ),
            ArColorFilterItemModel(
              id: 'mono',
              label: 'B & W',
              emoji: '🖤',
              sortOrder: 1,
              previewColorHex: '#B0B0B0',
              colorMatrix: [
                0.33, 0.59, 0.08, 0, 0, //
                0.33, 0.59, 0.08, 0, 0, //
                0.33, 0.59, 0.08, 0, 0, //
                0, 0, 0, 1, 0, //
              ],
            ),
          ],
        ),
      ],
    );
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

class ArColorFilterItemModel {
  const ArColorFilterItemModel({
    required this.id,
    required this.label,
    required this.colorMatrix,
    this.thumbnailUrl,
    this.emoji,
    this.previewColorHex,
    this.adjustments,
    this.sortOrder = 0,
  });

  final String id;
  final String label;

  /// Image URL shown as the filter thumbnail in the carousel (server-provided).
  final String? thumbnailUrl;

  /// Optional emoji fallback used offline / when [thumbnailUrl] is null.
  final String? emoji;

  /// Optional solid color placeholder (while the thumbnail loads / offline).
  final String? previewColorHex;

  /// Human-friendly slider values the dashboard used to build [colorMatrix].
  /// Optional — the app only needs [colorMatrix]; this is for re-editing.
  final ArColorFilterAdjustments? adjustments;

  final int sortOrder;

  /// Exactly 20 numbers (4 rows x 5 columns Android/Flutter ColorMatrix).
  final List<double> colorMatrix;

  factory ArColorFilterItemModel.fromJson(Map<String, dynamic> json) {
    final adj = json['adjustments'];
    return ArColorFilterItemModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      emoji: json['emoji']?.toString(),
      previewColorHex: json['previewColorHex']?.toString(),
      adjustments: adj is Map
          ? ArColorFilterAdjustments.fromJson(Map<String, dynamic>.from(adj))
          : null,
      sortOrder: _readInt(json['sortOrder']),
      colorMatrix: _readColorMatrix(json['colorMatrix']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (emoji != null) 'emoji': emoji,
        if (previewColorHex != null) 'previewColorHex': previewColorHex,
        if (adjustments != null) 'adjustments': adjustments!.toJson(),
        'sortOrder': sortOrder,
        'colorMatrix': colorMatrix,
      };

  /// A ColorMatrix is only valid with exactly 20 values.
  bool get hasValidMatrix => colorMatrix.length == 20;
}

/// The dashboard-facing slider values (all -100..100, 0 = no change).
/// The backend converts these into [ArColorFilterItemModel.colorMatrix].
///
/// - brightness: lighter / darker (additive offset)
/// - contrast:   flatter / punchier tones
/// - saturation: richer colors / -100 = black & white
/// - warmth:     + warm (yellow/red), - cool (blue)
/// - tint:       + magenta, - green
/// - exposure:   overall gain (like brightness, but multiplicative)
/// - fade:       + faded/matte look (lifted blacks), - deeper blacks
class ArColorFilterAdjustments {
  const ArColorFilterAdjustments({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.tint = 0,
    this.exposure = 0,
    this.fade = 0,
  });

  final int brightness;
  final int contrast;
  final int saturation;
  final int warmth;
  final int tint;
  final int exposure;
  final int fade;

  factory ArColorFilterAdjustments.fromJson(Map<String, dynamic> json) {
    return ArColorFilterAdjustments(
      brightness: _readInt(json['brightness']),
      contrast: _readInt(json['contrast']),
      saturation: _readInt(json['saturation']),
      warmth: _readInt(json['warmth']),
      tint: _readInt(json['tint']),
      exposure: _readInt(json['exposure']),
      fade: _readInt(json['fade']),
    );
  }

  Map<String, dynamic> toJson() => {
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'warmth': warmth,
        'tint': tint,
        'exposure': exposure,
        'fade': fade,
      };
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<double> _readColorMatrix(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<num>().map((v) => v.toDouble()).toList(growable: false);
}
