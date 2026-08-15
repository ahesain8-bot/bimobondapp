import 'dart:convert';

/// Models for `GET /camera-studio/ar-overlays` — the full-screen Lottie or MP4
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
    // Envelope tolerance: API may wrap response in `data`
    final data = json['data'];
    if (data is Map) {
      return ArOverlayCatalog.fromJson(Map<String, dynamic>.from(data));
    }

    List<ArOverlayCategoryModel> categories = [];
    final rawCategories = json['overlayCategories'] ??
        json['overlay_categories'] ??
        json['categories'];
    if (rawCategories is List) {
      categories = rawCategories
          .whereType<Map>()
          .map(
            (e) => ArOverlayCategoryModel.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((c) => c.overlays.isNotEmpty)
          .toList();
    } else {
      // Backend sent flat array of overlays under 'overlays', 'items', 'data', or top-level list
      final rawOverlays = json['overlays'] ??
          json['items'] ??
          json['overlays_list'] ??
          (data is List ? data : null);
      if (rawOverlays is List) {
        final category = ArOverlayCategoryModel.fromJson({
          'id': 'default',
          'label': 'Overlays',
          'sortOrder': 0,
          'overlays': rawOverlays,
        });
        if (category.overlays.isNotEmpty) {
          categories = [category];
        }
      }
    }
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ArOverlayCatalog(
      version: json['version']?.toString() ?? '',
      categories: categories,
    );
  }

  static ArOverlayCatalog? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ArOverlayCatalog.fromJson(Map<String, dynamic>.from(decoded));
      }
      if (decoded is List) {
        return ArOverlayCatalog.fromJson({'overlays': decoded});
      }
      return null;
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
    final raw = json['overlays'] ?? json['items'] ?? json['overlays_list'];
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
      sortOrder: _asInt(json['sortOrder'] ?? json['sort_order']),
      overlays: overlays,
    );
  }
}

enum VideoProjection { equirectangular, cubemap, rectilinear }
enum VideoStereoMode { mono, topBottom, sideBySide }

class VideoOverlay {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final double? duration;
  final VideoProjection projection;
  final VideoStereoMode stereoMode;
  final bool is360;

  VideoOverlay({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.duration,
    required this.projection,
    required this.stereoMode,
    required this.is360,
  });

  factory VideoOverlay.fromJson(Map<String, dynamic> json) {
    final projStr = json['projection']?.toString().toUpperCase() ?? 'EQUIRECTANGULAR';
    final stereoStr = json['stereoMode']?.toString().toUpperCase() ?? 'MONO';

    return VideoOverlay(
      id: json['id']?.toString() ?? '',
      url: (json['url'] ?? json['videoUrl'] ?? json['video_url'])?.toString() ?? '',
      thumbnailUrl: (json['thumbnailUrl'] ?? json['thumbnail_url'])?.toString(),
      width: json['width'] is int ? json['width'] : (json['width'] as num?)?.toInt(),
      height: json['height'] is int ? json['height'] : (json['height'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toDouble(),
      projection: VideoProjection.values.firstWhere(
        (e) => e.name.toUpperCase() == projStr,
        orElse: () => VideoProjection.equirectangular,
      ),
      stereoMode: VideoStereoMode.values.firstWhere(
        (e) => e.name.toUpperCase() == stereoStr ||
            (e == VideoStereoMode.topBottom && stereoStr == 'TOP_BOTTOM') ||
            (e == VideoStereoMode.sideBySide && stereoStr == 'SIDE_BY_SIDE'),
        orElse: () => VideoStereoMode.mono,
      ),
      is360: json['is360'] is bool ? json['is360'] : json['is_360'] is bool ? json['is_360'] : false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (duration != null) 'duration': duration,
      'projection': projection.name.toUpperCase(),
      'stereoMode': stereoMode.name.toUpperCase(),
      'is360': is360,
    };
  }
}

/// Whether the overlay plays as Lottie JSON or as a muted looping video.
enum ArOverlayMediaType { lottie, video }

/// A single full-screen overlay animation or 360 VR Video overlay.
class ArOverlayItemModel {
  const ArOverlayItemModel({
    required this.id,
    required this.label,
    required this.sortOrder,
    this.lottieUrl,
    this.videoId,
    this.video,
    this.bundledAsset,
    this.emoji,
    this.thumbnailUrl,
    this.previewColorHex,
    this.loop = true,
    this.isActive = true,
    this.mediaType = ArOverlayMediaType.lottie,
  });

  final String id;
  final String label;
  final int sortOrder;
  final String? lottieUrl;
  final String? videoId;
  final VideoOverlay? video;

  /// `android/app/src/main/assets` filename, used by the offline fallback catalog.
  final String? bundledAsset;

  final String? emoji;
  final String? thumbnailUrl;
  final String? previewColorHex;

  final bool loop;
  final bool isActive;
  final ArOverlayMediaType mediaType;

  bool get isVideo => mediaType == ArOverlayMediaType.video || video != null;
  bool get is360 => video != null && video!.is360;

  /// Playable remote URL when not using a bundled asset.
  String? get animationUrl => video?.url ?? lottieUrl;

  bool get hasSource =>
      (animationUrl ?? '').isNotEmpty || (bundledAsset ?? '').isNotEmpty;

  static ArOverlayItemModel? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'] ?? json['overlay_id'] ?? json['overlayId'])
        ?.toString()
        .trim() ?? '';
    if (id.isEmpty) return null;

    final isActive = json['isActive'] is bool
        ? json['isActive'] as bool
        : json['is_active'] is bool
            ? json['is_active'] as bool
            : json['active'] is bool
                ? json['active'] as bool
                : true;
    if (!isActive) return null;

    VideoOverlay? videoObj;
    if (json['video'] is Map) {
      videoObj = VideoOverlay.fromJson(Map<String, dynamic>.from(json['video']));
    }

    final explicitType = json['mediaType']?.toString().trim().toLowerCase() ??
        json['media_type']?.toString().trim().toLowerCase() ??
        json['type']?.toString().trim().toLowerCase();

    final videoUrl = json['videoUrl']?.toString().trim() ??
        json['video_url']?.toString().trim() ??
        videoObj?.url;

    final lottieUrlRaw = json['lottieUrl']?.toString().trim() ??
        json['lottie_url']?.toString().trim() ??
        json['lottie']?.toString().trim() ??
        json['fileUrl']?.toString().trim() ??
        json['file_url']?.toString().trim() ??
        json['assetUrl']?.toString().trim() ??
        json['asset_url']?.toString().trim();

    final animationUrlRaw = json['animationUrl']?.toString().trim() ??
        json['animation_url']?.toString().trim() ??
        json['url']?.toString().trim();

    final bundledAsset = json['bundledAsset']?.toString().trim() ??
        json['bundled_asset']?.toString().trim() ??
        json['asset']?.toString().trim();

    final String? animationUrl;
    if ((videoUrl ?? '').isNotEmpty &&
        (lottieUrlRaw ?? '').isEmpty &&
        (animationUrlRaw ?? '').isEmpty) {
      animationUrl = videoUrl;
    } else {
      animationUrl = (lottieUrlRaw ?? animationUrlRaw ?? videoUrl)?.trim();
    }
    if ((animationUrl == null || animationUrl.isEmpty) &&
        (bundledAsset == null || bundledAsset.isEmpty)) {
      return null;
    }

    final mediaType = videoObj != null
        ? ArOverlayMediaType.video
        : _resolveMediaType(explicitType, animationUrl ?? bundledAsset ?? '');

    final emoji = json['emoji']?.toString().trim();
    final thumbnailUrl = json['thumbnailUrl']?.toString().trim() ??
        json['thumbnail_url']?.toString().trim() ??
        json['thumbnail']?.toString().trim() ??
        json['previewUrl']?.toString().trim() ??
        json['preview_url']?.toString().trim() ??
        videoObj?.thumbnailUrl;

    // Fallback emoji if thumbnail is absent or empty, so remote item is never dropped
    final effectiveEmoji = (emoji ?? '').isNotEmpty
        ? emoji
        : (thumbnailUrl ?? '').isEmpty
            ? '✨'
            : null;

    final label = json['label']?.toString().trim() ??
        json['name']?.toString().trim() ??
        json['title']?.toString().trim();

    return ArOverlayItemModel(
      id: id,
      label: (label ?? '').isEmpty ? id : label!,
      sortOrder: _asInt(json['sortOrder'] ?? json['sort_order']),
      lottieUrl: lottieUrlRaw ?? animationUrl,
      videoId: (json['videoId'] ?? json['video_id'])?.toString(),
      video: videoObj,
      bundledAsset: (bundledAsset ?? '').isEmpty ? null : bundledAsset,
      emoji: effectiveEmoji,
      thumbnailUrl: (thumbnailUrl ?? '').isEmpty ? null : thumbnailUrl,
      previewColorHex: (json['previewColorHex'] ?? json['preview_color_hex'] ?? json['color'])
          ?.toString()
          .trim(),
      loop: json['loop'] is bool
          ? json['loop'] as bool
          : json['is_loop'] is bool
              ? json['is_loop'] as bool
              : true,
      isActive: isActive,
      mediaType: mediaType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'sortOrder': sortOrder,
      if (lottieUrl != null) 'lottieUrl': lottieUrl,
      if (videoId != null) 'videoId': videoId,
      if (video != null) 'video': video!.toJson(),
      if (bundledAsset != null) 'bundledAsset': bundledAsset,
      if (emoji != null) 'emoji': emoji,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (previewColorHex != null) 'previewColorHex': previewColorHex,
      'loop': loop,
      'isActive': isActive,
      'mediaType': mediaType.name,
    };
  }
}

ArOverlayMediaType _resolveMediaType(String? explicit, String url) {
  switch (explicit) {
    case 'video':
    case 'mp4':
    case 'webm':
    case 'mov':
      return ArOverlayMediaType.video;
    case 'lottie':
    case 'json':
    case 'dotlottie':
    case 'lottie_json':
      return ArOverlayMediaType.lottie;
  }
  if (_looksLikeLottieUrl(url)) {
    return ArOverlayMediaType.lottie;
  }
  return _looksLikeVideoUrl(url)
      ? ArOverlayMediaType.video
      : ArOverlayMediaType.lottie;
}

bool _looksLikeLottieUrl(String url) {
  final lower = url.toLowerCase().split('?').first;
  return lower.endsWith('.lottie') ||
      lower.endsWith('.json') ||
      lower.endsWith('.dotlottie');
}

bool _looksLikeVideoUrl(String url) {
  final lower = url.toLowerCase().split('?').first;
  return lower.endsWith('.mp4') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v');
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
