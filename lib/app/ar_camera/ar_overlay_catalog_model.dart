import 'dart:convert';

/// Models for `GET /camera-studio/ar-overlays` — the full-screen Lottie
/// overlays (Confetti, Snowfall, ...) shown in the camera's effect carousel.
///
/// Shape and field rules are documented for the backend in
/// `ar_overlay_backend_guide.dart`. Parsing here is deliberately forgiving:
/// anything malformed is dropped rather than thrown, so one bad dashboard entry
/// can never take the camera's filter list down with it.

/// Top-level response of `GET /camera-studio/ar-overlays`.
class ArOverlayCatalog {
  const ArOverlayCatalog({required this.version, required this.categories});

  final String version;
  final List<ArOverlayCategoryModel> categories;

  static const empty = ArOverlayCatalog(version: '', categories: []);

  factory ArOverlayCatalog.fromJson(Map<String, dynamic> json) {
    // Same envelope tolerance as ArColorFilterCatalog — the API may or may not
    // wrap the payload in `data`.
    final data = json['data'];
    if (data is Map) {
      return ArOverlayCatalog.fromJson(Map<String, dynamic>.from(data));
    }

    final raw = json['overlayCategories'];
    final categories = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (e) => ArOverlayCategoryModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((c) => c.overlays.isNotEmpty)
              .toList()
        : <ArOverlayCategoryModel>[];
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ArOverlayCatalog(
      version: json['version']?.toString() ?? '',
      categories: categories,
    );
  }

  static ArOverlayCatalog? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ArOverlayCatalog.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  /// Every overlay across all categories, already in display order.
  List<ArOverlayItemModel> get overlays => [
    for (final category in categories) ...category.overlays,
  ];

  ArOverlayItemModel? findOverlay(String id) {
    for (final category in categories) {
      for (final overlay in category.overlays) {
        if (overlay.id == id) return overlay;
      }
    }
    return null;
  }
}

/// One row of overlays. Today the backend only ever sends a single category,
/// but the shape supports more (e.g. a "Seasonal" row) without an app change.
class ArOverlayCategoryModel {
  const ArOverlayCategoryModel({
    required this.id,
    required this.label,
    required this.sortOrder,
    required this.overlays,
  });

  final String id;
  final String label;
  final int sortOrder;
  final List<ArOverlayItemModel> overlays;

  factory ArOverlayCategoryModel.fromJson(Map<String, dynamic> json) {
    final raw = json['overlays'];
    final overlays = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (e) =>
                    ArOverlayItemModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .whereType<ArOverlayItemModel>()
              .toList()
        : <ArOverlayItemModel>[];
    overlays.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ArOverlayCategoryModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sortOrder: _asInt(json['sortOrder']),
      overlays: overlays,
    );
  }
}

/// A single full-screen Lottie animation, e.g. "Confetti".
class ArOverlayItemModel {
  const ArOverlayItemModel({
    required this.id,
    required this.label,
    required this.sortOrder,
    this.lottieUrl,
    this.bundledAsset,
    this.emoji,
    this.thumbnailUrl,
    this.previewColorHex,
    this.loop = true,
  });

  final String id;
  final String label;
  final int sortOrder;

  /// Remote Lottie JSON. Null only for [ArOverlayBundledCatalog] entries, which
  /// carry [bundledAsset] instead.
  final String? lottieUrl;

  /// `android/app/src/main/assets` filename, used by the offline fallback
  /// catalog. Never sent by the backend.
  final String? bundledAsset;

  final String? emoji;
  final String? thumbnailUrl;
  final String? previewColorHex;

  /// Backend may omit it; decorative overlays loop by default.
  final bool loop;

  bool get hasSource =>
      (lottieUrl ?? '').isNotEmpty || (bundledAsset ?? '').isNotEmpty;

  /// Returns null for entries the app can't use, so the caller can drop them:
  /// no id, no playable source, or no icon of any kind (matching the backend
  /// guide's "at least one of emoji / thumbnailUrl" rule).
  static ArOverlayItemModel? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;

    final lottieUrl = json['lottieUrl']?.toString().trim();
    if (lottieUrl == null || lottieUrl.isEmpty) return null;

    final emoji = json['emoji']?.toString().trim();
    final thumbnailUrl = json['thumbnailUrl']?.toString().trim();
    if ((emoji ?? '').isEmpty && (thumbnailUrl ?? '').isEmpty) return null;

    final label = json['label']?.toString().trim();

    return ArOverlayItemModel(
      id: id,
      label: (label ?? '').isEmpty ? id : label!,
      sortOrder: _asInt(json['sortOrder']),
      lottieUrl: lottieUrl,
      emoji: (emoji ?? '').isEmpty ? null : emoji,
      thumbnailUrl: (thumbnailUrl ?? '').isEmpty ? null : thumbnailUrl,
      previewColorHex: json['previewColorHex']?.toString().trim(),
      loop: json['loop'] is bool ? json['loop'] as bool : true,
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
