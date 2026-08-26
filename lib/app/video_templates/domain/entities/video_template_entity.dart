import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/template_schema_enums.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/template_supporting_entities.dart';
import 'package:equatable/equatable.dart';

export 'package:bimobondapp/app/video_templates/domain/entities/template_schema_enums.dart';
export 'package:bimobondapp/app/video_templates/domain/entities/template_supporting_entities.dart';

/// Mirrors Prisma `templateKind` string enums.
abstract final class VideoTemplateKinds {
  static const video = 'VIDEO';
  static const photoCarousel = 'PHOTO_CAROUSEL';

  static const Set<String> known = {video, photoCarousel};

  /// Unknown values are kept (never throws).
  static String normalize(String? raw, {String fallback = video}) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return fallback;
    final u = s.toUpperCase();
    if (u == 'PHOTO') return photoCarousel;
    return known.contains(u) ? u : s;
  }

  static bool isKnown(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    final u = raw.trim().toUpperCase();
    return known.contains(u) || u == 'PHOTO';
  }
}

/// Prisma `TemplateSlotMediaType` (+ mobile `acceptedTypes[]`).
abstract final class TemplateSlotMediaTypes {
  static const video = 'VIDEO';
  static const image = 'IMAGE';

  static const Set<String> known = {video, image};

  static String normalize(String? raw, {String fallback = image}) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return fallback;
    final u = s.toUpperCase();
    if (u == 'PHOTO') return image;
    return known.contains(u) ? u : s;
  }

  static bool isKnown(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    final u = raw.trim().toUpperCase();
    return known.contains(u) || u == 'PHOTO';
  }

  /// Parses `acceptedTypes: ["IMAGE","VIDEO"]`. Unknown values kept.
  /// Empty / missing → `[fallbackType]` for backward compatibility with `type`.
  static List<String> parseAcceptedTypes(
    dynamic raw, {
    required String fallbackType,
  }) {
    final out = <String>[];
    if (raw is List) {
      for (final item in raw) {
        final n = normalize(item?.toString(), fallback: '');
        if (n.isEmpty) continue;
        if (!out.contains(n)) out.add(n);
      }
    }
    if (out.isEmpty) {
      out.add(normalize(fallbackType));
    }
    return List<String>.unmodifiable(out);
  }
}

/// MediaSource kind tokens for composition (Phase 4). Domain-only for now.
abstract final class MediaSourceKinds {
  static const image = 'IMAGE';
  static const video = 'VIDEO';

  static const Set<String> known = {image, video};

  static String normalize(String? raw, {String fallback = image}) {
    return TemplateSlotMediaTypes.normalize(raw, fallback: fallback);
  }

  static bool isImage(String? kind) =>
      normalize(kind) == image || normalize(kind) == 'PHOTO';

  static bool isVideo(String? kind) => normalize(kind) == video;
}

/// Distinguishes client draft ids (`local_…`) from server `UserTemplateProject.id`.
abstract final class VideoTemplateProjectIds {
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isLocalClientId(String? id) {
    final s = id?.trim() ?? '';
    return s.startsWith('local_');
  }

  /// True for a real DB project id — never a `local_*` draft key.
  static bool isServerId(String? id) {
    final s = id?.trim() ?? '';
    if (s.isEmpty || isLocalClientId(s)) return false;
    return _uuid.hasMatch(s);
  }

  static String? normalizeServerId(String? id) =>
      isServerId(id) ? id!.trim() : null;
}

/// Prisma `UserTemplateProjectStatus`.
abstract final class UserTemplateProjectStatuses {
  static const editing = 'EDITING';
  static const rendering = 'RENDERING';
  static const completed = 'COMPLETED';
  static const failed = 'FAILED';

  static const Set<String> known = {editing, rendering, completed, failed};

  static String normalize(String? raw, {String fallback = editing}) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return fallback;
    final u = s.toUpperCase();
    return known.contains(u) ? u : s;
  }

  static bool isKnown(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    return known.contains(raw.trim().toUpperCase());
  }
}

/// Prisma `TemplateExportStatus`.
abstract final class TemplateExportStatuses {
  static const queued = 'QUEUED';
  static const processing = 'PROCESSING';
  static const completed = 'COMPLETED';
  static const failed = 'FAILED';

  static const Set<String> known = {queued, processing, completed, failed};

  static String normalize(String? raw, {String fallback = queued}) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return fallback;
    final u = s.toUpperCase();
    return known.contains(u) ? u : s;
  }

  static bool isKnown(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    return known.contains(raw.trim().toUpperCase());
  }
}

/// Sound / template beat payload: `{ bpm, beats[], downbeats[], source }`.
class TemplateBeatMapEntity extends Equatable {
  const TemplateBeatMapEntity({
    this.bpm,
    this.beats = const [],
    this.downbeats = const [],
    this.source,
  });

  final double? bpm;
  final List<double> beats;
  final List<double> downbeats;
  final String? source;

  bool get isEmpty => beats.isEmpty && downbeats.isEmpty && bpm == null;

  factory TemplateBeatMapEntity.fromJson(dynamic raw) {
    if (raw == null) return const TemplateBeatMapEntity();
    if (raw is List) {
      return TemplateBeatMapEntity(
        beats: raw.map(_asDouble).where((e) => e >= 0).toList(growable: false),
      );
    }
    if (raw is! Map) return const TemplateBeatMapEntity();
    final map = Map<String, dynamic>.from(raw);
    return TemplateBeatMapEntity(
      bpm: _asDoubleOrNull(map['bpm']),
      beats: _parseDoubleList(map['beats']),
      downbeats: _parseDoubleList(map['downbeats']),
      source: map['source']?.toString(),
    );
  }

  @override
  List<Object?> get props => [bpm, beats, downbeats, source];
}

/// List-card projection shared by shelves / photo / search (`VideoTemplate`).
class VideoTemplateCardEntity extends Equatable {
  const VideoTemplateCardEntity({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.previewVideoUrl,
    this.templateKind = VideoTemplateKinds.video,
    this.slotCount = 0,
    this.duration,
    this.width,
    this.height,
    this.fps,
    this.useCount = 0,
    this.useCount7d = 0,
    this.browseCount = 0,
    this.downloadsCount = 0,
    this.likesCount = 0,
    this.isFeatured = false,
    this.featuredSortOrder,
    this.version = 1,
    this.status = VideoTemplateStatuses.published,
    this.categoryId,
    this.category,
    this.musicId,
    this.music,
    this.soundId,
    this.sound,
    this.soundSegmentId,
    this.createdById,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String? previewVideoUrl;
  /// `VIDEO` | `PHOTO_CAROUSEL` (unknown values preserved)
  final String templateKind;
  final int slotCount;
  final double? duration;
  final int? width;
  final int? height;
  final double? fps;
  final int useCount;
  final int useCount7d;
  final int browseCount;
  final int downloadsCount;
  final int likesCount;
  final bool isFeatured;
  final int? featuredSortOrder;
  final int version;
  /// `VideoTemplateStatus` string — unknown preserved.
  final String status;
  final String? categoryId;
  final TemplateCategoryEntity? category;
  final String? musicId;
  final TemplateMusicEntity? music;
  final String? soundId;
  final SoundEntity? sound;
  final String? soundSegmentId;
  final String? createdById;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPhotoCarousel =>
      templateKind.toUpperCase() == VideoTemplateKinds.photoCarousel ||
      templateKind.toUpperCase() == 'PHOTO';

  bool get isPublished =>
      status.toUpperCase() == VideoTemplateStatuses.published;

  factory VideoTemplateCardEntity.fromJson(Map<String, dynamic> json) {
    final categoryRaw = json['category'];
    TemplateCategoryEntity? category;
    if (categoryRaw is Map) {
      category = TemplateCategoryEntity.fromJson(
        Map<String, dynamic>.from(categoryRaw),
      );
    }

    return VideoTemplateCardEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      coverUrl: (json['coverUrl'] ?? json['thumbnailUrl'])?.toString(),
      previewVideoUrl: json['previewVideoUrl']?.toString(),
      templateKind: VideoTemplateKinds.normalize(
        json['templateKind']?.toString(),
      ),
      slotCount: _asInt(json['slotCount']),
      duration: _asDoubleOrNull(json['duration']),
      width: _asIntOrNull(json['width']),
      height: _asIntOrNull(json['height']),
      fps: _asDoubleOrNull(json['fps']),
      useCount: _asInt(json['useCount']),
      useCount7d: _asInt(json['useCount7d']),
      browseCount: _asInt(json['browseCount']),
      downloadsCount: _asInt(json['downloadsCount']),
      likesCount: _asInt(json['likesCount']),
      isFeatured: json['isFeatured'] == true,
      featuredSortOrder: _asIntOrNull(json['featuredSortOrder']),
      version: _asInt(json['version'], fallback: 1),
      status: VideoTemplateStatuses.normalize(json['status']?.toString()),
      categoryId: json['categoryId']?.toString() ?? category?.id,
      category: category,
      musicId: json['musicId']?.toString(),
      music: _parseMusic(json['templateMusic'] ?? json['music']),
      soundId: json['soundId']?.toString(),
      sound: _parseSound(json['sound'] ?? json['music']),
      soundSegmentId: _parseSegmentId(json),
      createdById: json['createdById']?.toString(),
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        coverUrl,
        previewVideoUrl,
        templateKind,
        slotCount,
        duration,
        width,
        height,
        fps,
        useCount,
        useCount7d,
        browseCount,
        downloadsCount,
        likesCount,
        isFeatured,
        featuredSortOrder,
        version,
        status,
        categoryId,
        category,
        musicId,
        music,
        soundId,
        sound,
        soundSegmentId,
        createdById,
        createdAt,
        updatedAt,
      ];
}

/// Prisma `TemplateSlot` — user-fillable media holes.
///
/// Backward compatible:
/// - Legacy: `"type": "VIDEO"` | `"IMAGE"`
/// - New: `"acceptedTypes": ["IMAGE", "VIDEO"]` (mixed slots)
class VideoTemplateSlotEntity extends Equatable {
  const VideoTemplateSlotEntity({
    required this.id,
    this.slotIndex = 0,
    this.type = TemplateSlotMediaTypes.image,
    this.acceptedTypes = const [],
    this.minDuration,
    this.maxDuration,
    this.durationSeconds,
    this.beatIndex,
    this.syncToBeat = false,
    this.transitionType,
    this.transitionDurationSeconds,
    this.placeholderUrl,
    this.required = true,
    this.aspectRatio,
    this.defaultTransition,
    this.effects = const [],
    this.filters = const [],
  });

  final String id;
  final int slotIndex;
  /// Primary / legacy `TemplateSlotMediaType` (`VIDEO` | `IMAGE`).
  final String type;
  /// Allowed user media kinds. Empty → derived from [type] (legacy APIs).
  final List<String> acceptedTypes;
  final double? minDuration;
  final double? maxDuration;
  /// Fixed TikTok slot length (seconds).
  final double? durationSeconds;
  final int? beatIndex;
  final bool syncToBeat;
  final String? transitionType;
  final double? transitionDurationSeconds;
  final String? placeholderUrl;
  final bool required;
  final String? aspectRatio;
  final String? defaultTransition;
  final List<TemplateEffectEntity> effects;
  final List<TemplateFilterEntity> filters;

  /// Alias used by older call sites.
  int get index => slotIndex;

  /// Alias for mediaType parsers.
  String get mediaType => type;

  /// Resolved accept list (never empty).
  List<String> get effectiveAcceptedTypes => acceptedTypes.isNotEmpty
      ? acceptedTypes
      : [TemplateSlotMediaTypes.normalize(type)];

  /// Legacy: primary [type] is image (ignores mixed [acceptedTypes]).
  bool get isImage =>
      type.toUpperCase() == TemplateSlotMediaTypes.image ||
      type.toUpperCase() == 'PHOTO';

  /// Legacy: primary [type] is video.
  bool get isVideo => type.toUpperCase() == TemplateSlotMediaTypes.video;

  bool get acceptsImage => effectiveAcceptedTypes.any(
        (t) =>
            t.toUpperCase() == TemplateSlotMediaTypes.image ||
            t.toUpperCase() == 'PHOTO',
      );

  bool get acceptsVideo => effectiveAcceptedTypes.any(
        (t) => t.toUpperCase() == TemplateSlotMediaTypes.video,
      );

  /// Slot accepts both stills and clips (composition uses MediaSource).
  bool get acceptsMixed => acceptsImage && acceptsVideo;

  bool get isImageOnly => acceptsImage && !acceptsVideo;

  bool get isVideoOnly => acceptsVideo && !acceptsImage;

  /// Whether a concrete media kind may fill this slot.
  bool acceptsMediaKind(String? kind) {
    final k = MediaSourceKinds.normalize(kind, fallback: '');
    if (k.isEmpty) return false;
    if (MediaSourceKinds.isImage(k)) return acceptsImage;
    if (MediaSourceKinds.isVideo(k)) return acceptsVideo;
    /// Unknown kind: allow if listed verbatim in [effectiveAcceptedTypes].
    return effectiveAcceptedTypes.any(
      (t) => t.toUpperCase() == k.toUpperCase(),
    );
  }

  /// Preferred MediaSource kind when auto-picking (mixed → video).
  String get preferredMediaSourceKind {
    if (isVideoOnly || (acceptsVideo && !acceptsImage)) {
      return MediaSourceKinds.video;
    }
    if (acceptsMixed) return MediaSourceKinds.video;
    return MediaSourceKinds.image;
  }

  /// UI label for the slot action button.
  String get pickerActionLabel {
    if (acceptsMixed) return 'Add Photo / Video';
    if (acceptsVideo) return 'Add Video';
    return 'Add Photo';
  }

  double get resolvedDurationSeconds => durationSeconds ?? maxDuration ?? 0;

  /// Hold duration for an image treated as a video clip (seconds).
  double get imageHoldDurationSeconds {
    final d = resolvedDurationSeconds;
    if (d > 0) return d;
    if (minDuration != null && minDuration! > 0) return minDuration!;
    return 5;
  }

  factory VideoTemplateSlotEntity.fromJson(Map<String, dynamic> json) {
    final type = TemplateSlotMediaTypes.normalize(
      (json['type'] ?? json['mediaType'] ?? json['slotType'])?.toString(),
    );
    final accepted = TemplateSlotMediaTypes.parseAcceptedTypes(
      json['acceptedTypes'] ?? json['allowedTypes'] ?? json['mediaTypes'],
      fallbackType: type,
    );
    return VideoTemplateSlotEntity(
      id: json['id']?.toString() ?? json['slotId']?.toString() ?? '',
      slotIndex: _asInt(json['slotIndex'] ?? json['index']),
      type: type,
      acceptedTypes: accepted,
      minDuration: _asDoubleOrNull(json['minDuration']),
      maxDuration: _asDoubleOrNull(json['maxDuration']),
      durationSeconds: _asDoubleOrNull(
        json['durationSeconds'] ?? json['duration'],
      ),
      beatIndex: _asIntOrNull(json['beatIndex']),
      syncToBeat: json['syncToBeat'] == true,
      transitionType: json['transitionType']?.toString(),
      transitionDurationSeconds: _asDoubleOrNull(
        json['transitionDurationSeconds'],
      ),
      placeholderUrl: json['placeholderUrl']?.toString(),
      required: json['required'] != false,
      aspectRatio: json['aspectRatio']?.toString(),
      defaultTransition: json['defaultTransition']?.toString(),
      effects: _parseList(json['effects'], TemplateEffectEntity.fromJson),
      filters: _parseList(json['filters'], TemplateFilterEntity.fromJson),
    );
  }

  @override
  List<Object?> get props => [
        id,
        slotIndex,
        type,
        acceptedTypes,
        minDuration,
        maxDuration,
        durationSeconds,
        beatIndex,
        syncToBeat,
        transitionType,
        transitionDurationSeconds,
        placeholderUrl,
        required,
        aspectRatio,
        defaultTransition,
        effects,
        filters,
      ];
}

/// Per-slot / per-clip motion FX (`TemplateEffect`).
class TemplateEffectEntity extends Equatable {
  const TemplateEffectEntity({
    required this.effectType,
    this.id,
    this.clipId,
    this.startTime = 0,
    this.endTime,
    this.parameters = const {},
  });

  final String? id;
  final String? clipId;
  final String effectType;
  final double startTime;
  final double? endTime;
  final Map<String, dynamic> parameters;

  factory TemplateEffectEntity.fromJson(Map<String, dynamic> json) {
    return TemplateEffectEntity(
      id: json['id']?.toString(),
      clipId: json['clipId']?.toString(),
      effectType: (json['effectType'] ?? json['type'] ?? '').toString(),
      startTime: _asDouble(json['startTime']),
      endTime: _asDoubleOrNull(json['endTime']),
      parameters: json['parameters'] is Map
          ? Map<String, dynamic>.from(json['parameters'] as Map)
          : const {},
    );
  }

  @override
  List<Object?> get props =>
      [id, clipId, effectType, startTime, endTime, parameters];
}

/// Per-slot / per-clip color grade (`TemplateFilter`).
class TemplateFilterEntity extends Equatable {
  const TemplateFilterEntity({
    required this.filterName,
    this.id,
    this.clipId,
    this.intensity = 1,
    this.lutAssetId,
    this.lutAsset,
  });

  final String? id;
  final String? clipId;
  final String filterName;
  final double intensity;
  final String? lutAssetId;
  final TemplateAssetEntity? lutAsset;

  factory TemplateFilterEntity.fromJson(Map<String, dynamic> json) {
    TemplateAssetEntity? lut;
    final lutRaw = json['lutAsset'] ?? json['lut'];
    if (lutRaw is Map) {
      lut = TemplateAssetEntity.fromJson(Map<String, dynamic>.from(lutRaw));
    }
    return TemplateFilterEntity(
      id: json['id']?.toString(),
      clipId: json['clipId']?.toString(),
      filterName: (json['filterName'] ?? json['name'] ?? 'none').toString(),
      intensity: _asDouble(json['intensity'], fallback: 1).clamp(0, 1),
      lutAssetId: json['lutAssetId']?.toString() ?? lut?.id,
      lutAsset: lut,
    );
  }

  @override
  List<Object?> get props =>
      [id, clipId, filterName, intensity, lutAssetId, lutAsset];
}

/// Clip-to-clip transition (`TemplateTransition`) or flattened recipe form.
class VideoTemplateTransitionEntity extends Equatable {
  const VideoTemplateTransitionEntity({
    this.id,
    this.fromClipId,
    this.toClipId,
    this.afterSlotIndex,
    this.type = 'cut',
    this.durationSeconds = 0.3,
    this.parameters,
  });

  final String? id;
  final String? fromClipId;
  final String? toClipId;
  /// Flattened recipe form when API emits slot-indexed transitions.
  final int? afterSlotIndex;
  final String type;
  final double durationSeconds;
  final Map<String, dynamic>? parameters;

  factory VideoTemplateTransitionEntity.fromJson(Map<String, dynamic> json) {
    return VideoTemplateTransitionEntity(
      id: json['id']?.toString(),
      fromClipId: json['fromClipId']?.toString(),
      toClipId: json['toClipId']?.toString(),
      afterSlotIndex: _asIntOrNull(
        json['afterSlotIndex'] ?? json['slotIndex'],
      ),
      type: (json['transitionType'] ?? json['type'] ?? 'cut').toString(),
      durationSeconds: _asDouble(
        json['duration'] ?? json['durationSeconds'],
        fallback: 0.3,
      ),
      parameters: json['parameters'] is Map
          ? Map<String, dynamic>.from(json['parameters'] as Map)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fromClipId,
        toClipId,
        afterSlotIndex,
        type,
        durationSeconds,
        parameters,
      ];
}

/// Lightweight track / clip / overlay models for `includeOverlays=1` recipes.
class TemplateTrackEntity extends Equatable {
  const TemplateTrackEntity({
    required this.id,
    this.trackType = TemplateTrackTypes.video,
    this.sortOrder = 0,
  });

  final String id;
  /// `TemplateTrackType` — unknown values preserved.
  final String trackType;
  final int sortOrder;

  factory TemplateTrackEntity.fromJson(Map<String, dynamic> json) {
    return TemplateTrackEntity(
      id: json['id']?.toString() ?? '',
      trackType: TemplateTrackTypes.normalize(json['trackType']?.toString()),
      sortOrder: _asInt(json['sortOrder']),
    );
  }

  @override
  List<Object?> get props => [id, trackType, sortOrder];
}

class TemplateClipEntity extends Equatable {
  const TemplateClipEntity({
    required this.id,
    this.trackId,
    this.slotId,
    this.assetId,
    this.asset,
    this.sourceType = TemplateClipSourceTypes.templateBuiltin,
    this.startTime = 0,
    this.endTime,
    this.layerOrder = 0,
    this.speed = 1,
    this.volume = 1,
    this.rotation = 0,
    this.scale = 1,
    this.positionX = 0,
    this.positionY = 0,
    this.opacity = 1,
    this.blendMode,
    this.effects = const [],
    this.filters = const [],
    this.keyframes = const [],
  });

  final String id;
  final String? trackId;
  final String? slotId;
  final String? assetId;
  final TemplateAssetEntity? asset;
  /// `TemplateClipSourceType` — unknown preserved.
  final String sourceType;
  final double startTime;
  final double? endTime;
  final int layerOrder;
  final double speed;
  final double volume;
  final double rotation;
  final double scale;
  final double positionX;
  final double positionY;
  final double opacity;
  final String? blendMode;
  final List<TemplateEffectEntity> effects;
  final List<TemplateFilterEntity> filters;
  final List<TemplateKeyframeEntity> keyframes;

  factory TemplateClipEntity.fromJson(Map<String, dynamic> json) {
    TemplateAssetEntity? asset;
    final assetRaw = json['asset'];
    if (assetRaw is Map) {
      asset = TemplateAssetEntity.fromJson(Map<String, dynamic>.from(assetRaw));
    }
    return TemplateClipEntity(
      id: json['id']?.toString() ?? '',
      trackId: json['trackId']?.toString(),
      slotId: json['slotId']?.toString(),
      assetId: json['assetId']?.toString() ?? asset?.id,
      asset: asset,
      sourceType: TemplateClipSourceTypes.normalize(
        json['sourceType']?.toString(),
      ),
      startTime: _asDouble(json['startTime']),
      endTime: _asDoubleOrNull(json['endTime']),
      layerOrder: _asInt(json['layerOrder']),
      speed: _asDouble(json['speed'], fallback: 1),
      volume: _asDouble(json['volume'], fallback: 1),
      rotation: _asDouble(json['rotation']),
      scale: _asDouble(json['scale'], fallback: 1),
      positionX: _asDouble(json['positionX']),
      positionY: _asDouble(json['positionY']),
      opacity: _asDouble(json['opacity'], fallback: 1),
      blendMode: json['blendMode']?.toString(),
      effects: _parseList(json['effects'], TemplateEffectEntity.fromJson),
      filters: _parseList(json['filters'], TemplateFilterEntity.fromJson),
      keyframes: _parseList(
        json['keyframes'] ?? json['templateKeyframes'],
        TemplateKeyframeEntity.fromJson,
      ),
    );
  }

  @override
  List<Object?> get props => [
        id,
        trackId,
        slotId,
        assetId,
        asset,
        sourceType,
        startTime,
        endTime,
        layerOrder,
        speed,
        volume,
        rotation,
        scale,
        positionX,
        positionY,
        opacity,
        blendMode,
        effects,
        filters,
        keyframes,
      ];
}

class TemplateTextEntity extends Equatable {
  const TemplateTextEntity({
    required this.id,
    this.trackId,
    required this.text,
    this.fontAssetId,
    this.fontAsset,
    this.fontAssetUrl,
    this.fontSize,
    this.color,
    this.alignment,
    this.startTime = 0,
    this.endTime = 0,
    this.positionX = 0,
    this.positionY = 0,
    this.animationIn,
    this.animationOut,
    this.style,
  });

  final String id;
  final String? trackId;
  final String text;
  final String? fontAssetId;
  final TemplateAssetEntity? fontAsset;
  /// Resolved CDN path from recipe (`fontAssetUrl`).
  final String? fontAssetUrl;
  final double? fontSize;
  final String? color;
  final String? alignment;
  final double startTime;
  final double endTime;
  final double positionX;
  final double positionY;
  final String? animationIn;
  final String? animationOut;
  /// Free-form style JSON from schema.
  final Map<String, dynamic>? style;

  factory TemplateTextEntity.fromJson(Map<String, dynamic> json) {
    TemplateAssetEntity? font;
    final fontRaw = json['fontAsset'] ?? json['font'];
    if (fontRaw is Map) {
      font = TemplateAssetEntity.fromJson(Map<String, dynamic>.from(fontRaw));
    }
    Map<String, dynamic>? style;
    final styleRaw = json['style'];
    if (styleRaw is Map) {
      style = Map<String, dynamic>.from(styleRaw);
    }
    return TemplateTextEntity(
      id: json['id']?.toString() ?? '',
      trackId: json['trackId']?.toString(),
      text: json['text']?.toString() ?? '',
      fontAssetId: json['fontAssetId']?.toString() ?? font?.id,
      fontAsset: font,
      fontAssetUrl: (json['fontAssetUrl'] ?? font?.url)?.toString(),
      fontSize: _asDoubleOrNull(json['fontSize']),
      color: json['color']?.toString(),
      alignment: json['alignment']?.toString(),
      startTime: _asDouble(json['startTime']),
      endTime: _asDouble(json['endTime']),
      positionX: _asDouble(json['positionX']),
      positionY: _asDouble(json['positionY']),
      animationIn: json['animationIn']?.toString(),
      animationOut: json['animationOut']?.toString(),
      style: style,
    );
  }

  @override
  List<Object?> get props => [
        id,
        trackId,
        text,
        fontAssetId,
        fontAsset,
        fontAssetUrl,
        fontSize,
        color,
        alignment,
        startTime,
        endTime,
        positionX,
        positionY,
        animationIn,
        animationOut,
        style,
      ];
}

class TemplateStickerEntity extends Equatable {
  const TemplateStickerEntity({
    required this.id,
    this.trackId,
    this.assetId,
    this.asset,
    this.assetUrl,
    this.startTime = 0,
    this.endTime = 0,
    this.positionX = 0,
    this.positionY = 0,
    this.scale = 1,
    this.rotation = 0,
    this.opacity = 1,
  });

  final String id;
  final String? trackId;
  final String? assetId;
  final TemplateAssetEntity? asset;
  final String? assetUrl;
  final double startTime;
  final double endTime;
  final double positionX;
  final double positionY;
  final double scale;
  final double rotation;
  final double opacity;

  factory TemplateStickerEntity.fromJson(Map<String, dynamic> json) {
    TemplateAssetEntity? asset;
    final assetRaw = json['asset'];
    String? assetUrl;
    if (assetRaw is Map) {
      final map = Map<String, dynamic>.from(assetRaw);
      asset = TemplateAssetEntity.fromJson(map);
      assetUrl = asset.url.isNotEmpty ? asset.url : map['url']?.toString();
    }
    return TemplateStickerEntity(
      id: json['id']?.toString() ?? '',
      trackId: json['trackId']?.toString(),
      assetId: json['assetId']?.toString() ?? asset?.id,
      asset: asset,
      assetUrl:
          assetUrl ?? json['assetUrl']?.toString() ?? json['url']?.toString(),
      startTime: _asDouble(json['startTime']),
      endTime: _asDouble(json['endTime']),
      positionX: _asDouble(json['positionX']),
      positionY: _asDouble(json['positionY']),
      scale: _asDouble(json['scale'], fallback: 1),
      rotation: _asDouble(json['rotation']),
      opacity: _asDouble(json['opacity'], fallback: 1),
    );
  }

  @override
  List<Object?> get props => [
        id,
        trackId,
        assetId,
        asset,
        assetUrl,
        startTime,
        endTime,
        positionX,
        positionY,
        scale,
        rotation,
        opacity,
      ];
}

class TemplateOverlayEntity extends Equatable {
  const TemplateOverlayEntity({
    required this.id,
    this.trackId,
    this.assetId,
    this.asset,
    this.assetUrl,
    this.startTime = 0,
    this.endTime = 0,
    this.opacity = 1,
    this.blendMode,
  });

  final String id;
  final String? trackId;
  final String? assetId;
  final TemplateAssetEntity? asset;
  final String? assetUrl;
  final double startTime;
  final double endTime;
  final double opacity;
  final String? blendMode;

  factory TemplateOverlayEntity.fromJson(Map<String, dynamic> json) {
    TemplateAssetEntity? asset;
    final assetRaw = json['asset'];
    String? assetUrl;
    if (assetRaw is Map) {
      final map = Map<String, dynamic>.from(assetRaw);
      asset = TemplateAssetEntity.fromJson(map);
      assetUrl = asset.url.isNotEmpty ? asset.url : map['url']?.toString();
    }
    return TemplateOverlayEntity(
      id: json['id']?.toString() ?? '',
      trackId: json['trackId']?.toString(),
      assetId: json['assetId']?.toString() ?? asset?.id,
      asset: asset,
      assetUrl:
          assetUrl ?? json['assetUrl']?.toString() ?? json['url']?.toString(),
      startTime: _asDouble(json['startTime']),
      endTime: _asDouble(json['endTime']),
      opacity: _asDouble(json['opacity'], fallback: 1),
      blendMode: json['blendMode']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        trackId,
        assetId,
        asset,
        assetUrl,
        startTime,
        endTime,
        opacity,
        blendMode,
      ];
}

/// `renderHints` from `GET /video-templates/:id/recipe`.
///
/// Backend contract (mobile render handoff):
/// ```json
/// {
///   "preferredPath": "client" | "server",
///   "complexity": "low" | "medium" | "high",
///   "hasXfadeTransitions": true,
///   "hasOverlays": true,
///   "slotCount": 4,
///   "estimatedServerExportSeconds": 30,
///   "recommendedPreviewQuality": "draft",
///   "recommendedFinalQuality": "standard"
/// }
/// ```
class VideoTemplateRenderHintsEntity extends Equatable {
  const VideoTemplateRenderHintsEntity({
    this.preferredPath = 'client',
    this.complexity = 'low',
    this.estimatedServerExportSeconds,
    this.hasXfadeTransitions = false,
    this.hasOverlays = false,
    this.slotCount = 0,
    this.recommendedPreviewQuality = 'draft',
    this.recommendedFinalQuality = 'standard',
    this.fromApi = false,
  });

  final String preferredPath;
  final String complexity;
  final double? estimatedServerExportSeconds;
  final bool hasXfadeTransitions;
  final bool hasOverlays;
  final int slotCount;
  final String recommendedPreviewQuality;
  final String recommendedFinalQuality;
  /// True when parsed from recipe JSON `renderHints` (not app defaults).
  final bool fromApi;

  bool get prefersClientPath =>
      preferredPath.trim().toLowerCase() == 'client';
  bool get prefersServerPath =>
      preferredPath.trim().toLowerCase() == 'server';
  bool get isHighComplexity =>
      complexity.trim().toLowerCase() == 'high';
  bool get isMediumComplexity =>
      complexity.trim().toLowerCase() == 'medium';
  bool get isLowComplexity =>
      complexity.trim().toLowerCase() == 'low';
  /// Prefer server when hints say so or complexity is high (guide §1).
  bool get shouldUseServerExport =>
      prefersServerPath || isHighComplexity || !prefersClientPath;
  /// On-device compose for low-complexity / preferredPath=client.
  bool get shouldUseClientExport => prefersClientPath && !isHighComplexity;

  factory VideoTemplateRenderHintsEntity.fromJson(dynamic raw) {
    final map = _renderHintsMap(raw);
    if (map == null) {
      return const VideoTemplateRenderHintsEntity();
    }
    return VideoTemplateRenderHintsEntity(
      preferredPath: _normalizePreferredPath(
        map['preferredPath'] ?? map['preferred_path'],
      ),
      complexity: _normalizeComplexity(
        map['complexity'],
      ),
      estimatedServerExportSeconds: _asDoubleOrNull(
        map['estimatedServerExportSeconds'] ??
            map['estimated_server_export_seconds'],
      ),
      hasXfadeTransitions: _asBool(
        map['hasXfadeTransitions'] ?? map['has_xfade_transitions'],
      ),
      hasOverlays: _asBool(
        map['hasOverlays'] ?? map['has_overlays'],
      ),
      slotCount: _asInt(
        map['slotCount'] ?? map['slot_count'],
      ),
      recommendedPreviewQuality: _normalizeQuality(
        map['recommendedPreviewQuality'] ?? map['recommended_preview_quality'],
        fallback: 'draft',
      ),
      recommendedFinalQuality: _normalizeQuality(
        map['recommendedFinalQuality'] ?? map['recommended_final_quality'],
        fallback: 'standard',
      ),
      fromApi: true,
    );
  }

  /// Merge API hints with recipe content (slot/overlay counts as fallbacks).
  VideoTemplateRenderHintsEntity enriched({
    required int recipeSlotCount,
    required bool recipeHasOverlays,
    required bool recipeHasXfade,
  }) {
    return VideoTemplateRenderHintsEntity(
      preferredPath: preferredPath,
      complexity: complexity,
      estimatedServerExportSeconds: estimatedServerExportSeconds,
      hasXfadeTransitions: hasXfadeTransitions || recipeHasXfade,
      hasOverlays: hasOverlays || recipeHasOverlays,
      slotCount: slotCount > 0 ? slotCount : recipeSlotCount,
      recommendedPreviewQuality: recommendedPreviewQuality,
      recommendedFinalQuality: recommendedFinalQuality,
      fromApi: fromApi,
    );
  }

  static Map<String, dynamic>? _renderHintsMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static String _normalizePreferredPath(dynamic raw) {
    final v = (raw ?? 'client').toString().trim().toLowerCase();
    if (v == 'server' || v == 'backend' || v == 'ffmpeg') return 'server';
    return 'client';
  }

  static String _normalizeComplexity(dynamic raw) {
    final v = (raw ?? 'low').toString().trim().toLowerCase();
    if (v == 'high' || v == 'heavy') return 'high';
    if (v == 'medium' || v == 'med' || v == 'mid') return 'medium';
    return 'low';
  }

  static String _normalizeQuality(dynamic raw, {required String fallback}) {
    final v = (raw ?? fallback).toString().trim().toLowerCase();
    if (v == 'draft' || v == 'standard' || v == 'high') return v;
    return fallback;
  }

  @override
  List<Object?> get props => [
        preferredPath,
        complexity,
        estimatedServerExportSeconds,
        hasXfadeTransitions,
        hasOverlays,
        slotCount,
        recommendedPreviewQuality,
        recommendedFinalQuality,
        fromApi,
      ];
}

/// Recipe DTO from `GET /video-templates/:id/recipe?includeOverlays=1`.
class VideoTemplateRecipeEntity extends Equatable {
  const VideoTemplateRecipeEntity({
    required this.id,
    required this.name,
    this.templateKind = VideoTemplateKinds.video,
    this.primarySlotType = 'MIXED',
    this.allowedOutputs = const [],
    this.slotCount = 0,
    this.coverUrl,
    this.previewVideoUrl,
    this.duration,
    this.width = 1080,
    this.height = 1920,
    this.fps = 30,
    this.version = 1,
    this.versionInfo,
    this.useCount = 0,
    this.categoryId,
    this.category,
    this.musicId,
    this.music,
    this.soundId,
    this.sound,
    this.soundSegmentId,
    this.soundSegmentStartMs,
    this.soundSegmentEndMs,
    this.slots = const [],
    this.beatMap = const TemplateBeatMapEntity(),
    this.transitions = const [],
    this.tracks = const [],
    this.clips = const [],
    this.texts = const [],
    this.stickers = const [],
    this.overlays = const [],
    this.assets = const [],
    this.keyframes = const [],
    this.renderHints = const VideoTemplateRenderHintsEntity(),
  });

  final String id;
  final String name;
  final String templateKind;
  final String primarySlotType;
  /// e.g. `["VIDEO"]` or `["CAROUSEL", "VIDEO"]`
  final List<String> allowedOutputs;
  final int slotCount;
  final String? coverUrl;
  final String? previewVideoUrl;
  final double? duration;
  final int width;
  final int height;
  final double fps;
  final int version;
  final TemplateVersionEntity? versionInfo;
  final int useCount;
  final String? categoryId;
  final TemplateCategoryEntity? category;
  final String? musicId;
  final TemplateMusicEntity? music;
  final String? soundId;
  final SoundEntity? sound;
  final String? soundSegmentId;
  final int? soundSegmentStartMs;
  final int? soundSegmentEndMs;
  final List<VideoTemplateSlotEntity> slots;
  final TemplateBeatMapEntity beatMap;
  final List<VideoTemplateTransitionEntity> transitions;
  final List<TemplateTrackEntity> tracks;
  final List<TemplateClipEntity> clips;
  final List<TemplateTextEntity> texts;
  final List<TemplateStickerEntity> stickers;
  final List<TemplateOverlayEntity> overlays;
  final List<TemplateAssetEntity> assets;
  /// Flat keyframes when recipe emits them at root (also nested on clips).
  final List<TemplateKeyframeEntity> keyframes;
  final VideoTemplateRenderHintsEntity renderHints;

  /// Flattened beat timestamps (seconds) for sync helpers.
  List<double> get beatTimestamps => beatMap.beats;

  /// All keyframes: root list + nested on clips (deduped by id when present).
  List<TemplateKeyframeEntity> get allKeyframes {
    if (keyframes.isEmpty && clips.every((c) => c.keyframes.isEmpty)) {
      return const [];
    }
    final byId = <String, TemplateKeyframeEntity>{};
    final orphan = <TemplateKeyframeEntity>[];
    void add(TemplateKeyframeEntity kf) {
      if (kf.id.isNotEmpty) {
        byId.putIfAbsent(kf.id, () => kf);
      } else {
        orphan.add(kf);
      }
    }

    for (final kf in keyframes) {
      add(kf);
    }
    for (final clip in clips) {
      for (final kf in clip.keyframes) {
        add(
          kf.clipId == null || kf.clipId!.isEmpty
              ? TemplateKeyframeEntity(
                  id: kf.id,
                  clipId: clip.id,
                  property: kf.property,
                  time: kf.time,
                  value: kf.value,
                  easing: kf.easing,
                )
              : kf,
        );
      }
    }
    return [...byId.values, ...orphan];
  }

  bool get isPhotoCarousel =>
      templateKind.toUpperCase() == VideoTemplateKinds.photoCarousel ||
      templateKind.toUpperCase() == 'PHOTO';

  bool get isVideoKind =>
      templateKind.toUpperCase() == VideoTemplateKinds.video;

  /// Sound used under live preview (feed sound, else legacy template music).
  SoundEntity? get effectivePreviewSound =>
      sound ?? music?.toSoundEntity();

  bool get allowsVideoOutput {
    if (allowedOutputs.isEmpty) return isVideoKind || isPhotoCarousel;
    return allowedOutputs.any((o) => o.toUpperCase() == 'VIDEO');
  }

  bool get allowsCarouselOutput {
    if (allowedOutputs.isEmpty) return isPhotoCarousel;
    return allowedOutputs.any((o) => o.toUpperCase() == 'CAROUSEL');
  }

  /// Prefer client-rendered VIDEO (API recommended) over raw carousel dump.
  bool get prefersVideoOutput {
    if (isVideoKind) return true;
    if (allowsVideoOutput) return true;
    return false;
  }

  /// Backend rejects photo-template posts when no IMAGE slots exist on the template.
  bool get hasImageSlots =>
      slots.any((s) => s.isImage || s.acceptsImage);

  /// Safe to send [videoTemplateId] on create-post for this recipe.
  ///
  /// Nest rejects PHOTO_CAROUSEL posts when the template has no IMAGE slots
  /// ("Photo template has no IMAGE slots configured"). VIDEO kind is always OK.
  /// When slots are empty on a photo recipe but the client ships a composed
  /// VIDEO and [allowsVideoOutput], still omit the id — server validates the
  /// template graph, not the client output.
  bool get canAttachTemplateToPost {
    if (!isPhotoCarousel) return true;
    return hasImageSlots;
  }

  int get requiredSlotCount {
    if (slots.isEmpty) return slotCount;
    final required = slots.where((s) => s.required).length;
    return required > 0 ? required : slots.length;
  }

  /// Slot count used for local fill / project mapping.
  int get applySlotCount {
    final n = requiredSlotCount;
    if (n > 0) return n.clamp(1, 99);
    return isPhotoCarousel ? 5 : 1;
  }

  /// Resolve asset by id from recipe pack or nested clip/sticker/overlay assets.
  TemplateAssetEntity? assetById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in assets) {
      if (a.id == id) return a;
    }
    for (final c in clips) {
      if (c.asset?.id == id) return c.asset;
    }
    for (final s in stickers) {
      if (s.asset?.id == id) return s.asset;
    }
    for (final o in overlays) {
      if (o.asset?.id == id) return o.asset;
    }
    for (final f in slots.expand((s) => s.filters)) {
      if (f.lutAsset?.id == id) return f.lutAsset;
    }
    return null;
  }

  factory VideoTemplateRecipeEntity.fromJson(Map<String, dynamic> json) {
    final segment = json['soundSegment'];
    String? segmentId = _parseSegmentId(json);
    int? startMs;
    int? endMs;
    if (segment is Map) {
      startMs = _asIntOrNull(segment['startMs'] ?? segment['start']);
      endMs = _asIntOrNull(segment['endMs'] ?? segment['end']);
    }

    final slots = _parseList(json['slots'], VideoTemplateSlotEntity.fromJson);
    final transitions = _parseList(
      json['transitions'],
      VideoTemplateTransitionEntity.fromJson,
    );
    final tracks = _parseList(json['tracks'], TemplateTrackEntity.fromJson);
    final clips = _parseList(
      json['clips'] ?? json['templateClips'],
      TemplateClipEntity.fromJson,
    );
    final texts = _parseList(
      json['texts'] ?? json['templateTexts'],
      TemplateTextEntity.fromJson,
    );
    final stickers = _parseList(
      json['stickers'] ?? json['templateStickers'],
      TemplateStickerEntity.fromJson,
    );
    final overlays = _parseList(
      json['overlays'] ?? json['templateOverlays'],
      TemplateOverlayEntity.fromJson,
    );
    final assets = _parseList(
      json['assets'] ?? json['templateAssets'],
      TemplateAssetEntity.fromJson,
    );
    final keyframes = _parseList(
      json['keyframes'] ?? json['templateKeyframes'],
      TemplateKeyframeEntity.fromJson,
    );

    final allowed = <String>[];
    final rawAllowed = json['allowedOutputs'];
    if (rawAllowed is List) {
      for (final item in rawAllowed) {
        final s = item?.toString();
        if (s != null && s.isNotEmpty) allowed.add(s);
      }
    }

    TemplateBeatMapEntity beatMap = TemplateBeatMapEntity.fromJson(
      json['beatMap'],
    );
    final soundRaw = json['sound'];
    final musicRaw = json['templateMusic'] ?? json['music'];
    if (beatMap.isEmpty && soundRaw is Map && soundRaw['beatMap'] != null) {
      beatMap = TemplateBeatMapEntity.fromJson(soundRaw['beatMap']);
    }
    if (beatMap.isEmpty && musicRaw is Map && musicRaw['beatMap'] != null) {
      beatMap = TemplateBeatMapEntity.fromJson(musicRaw['beatMap']);
    }

    TemplateCategoryEntity? category;
    final categoryRaw = json['category'];
    if (categoryRaw is Map) {
      category = TemplateCategoryEntity.fromJson(
        Map<String, dynamic>.from(categoryRaw),
      );
    }

    TemplateVersionEntity? versionInfo;
    final versionRaw = json['versionInfo'] ?? json['templateVersion'];
    if (versionRaw is Map) {
      versionInfo = TemplateVersionEntity.fromJson(
        Map<String, dynamic>.from(versionRaw),
      );
    }

    final version = versionInfo?.version ??
        _asInt(json['version'], fallback: 1);

    // Recipe API delivers renderHints at the top level (see mobile handoff).
    final hints = VideoTemplateRenderHintsEntity.fromJson(
      json['renderHints'] ?? json['render_hints'],
    );
    final recipeHasOverlays =
        texts.isNotEmpty || stickers.isNotEmpty || overlays.isNotEmpty;
    final recipeHasXfade = transitions.any((t) {
      final type = t.type.toLowerCase();
      return type.contains('xfade') ||
          type.contains('crossfade') ||
          type == 'fade' ||
          type.contains('glitch');
    });
    final resolvedSlotCount =
        _asInt(json['slotCount'], fallback: slots.length);
    final renderHints = hints.enriched(
      recipeSlotCount: resolvedSlotCount > 0 ? resolvedSlotCount : slots.length,
      recipeHasOverlays: recipeHasOverlays,
      recipeHasXfade: recipeHasXfade,
    );

    return VideoTemplateRecipeEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      templateKind: VideoTemplateKinds.normalize(
        json['templateKind']?.toString(),
      ),
      primarySlotType: json['primarySlotType']?.toString() ?? 'MIXED',
      allowedOutputs: allowed,
      slotCount: resolvedSlotCount,
      coverUrl: json['coverUrl']?.toString(),
      previewVideoUrl: json['previewVideoUrl']?.toString(),
      duration: _asDoubleOrNull(json['duration']),
      width: _asInt(json['width'], fallback: 1080),
      height: _asInt(json['height'], fallback: 1920),
      fps: _asDouble(json['fps'], fallback: 30),
      version: version,
      versionInfo: versionInfo,
      useCount: _asInt(json['useCount']),
      categoryId: json['categoryId']?.toString() ?? category?.id,
      category: category,
      musicId: json['musicId']?.toString(),
      music: _parseMusic(musicRaw),
      soundId: json['soundId']?.toString(),
      sound: _parseSound(soundRaw ?? musicRaw),
      soundSegmentId: segmentId,
      soundSegmentStartMs: startMs,
      soundSegmentEndMs: endMs,
      slots: slots,
      beatMap: beatMap,
      transitions: transitions,
      tracks: tracks,
      clips: clips,
      texts: texts,
      stickers: stickers,
      overlays: overlays,
      assets: assets,
      keyframes: keyframes,
      renderHints: renderHints,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        templateKind,
        primarySlotType,
        allowedOutputs,
        slotCount,
        coverUrl,
        previewVideoUrl,
        duration,
        width,
        height,
        fps,
        version,
        versionInfo,
        useCount,
        categoryId,
        category,
        musicId,
        music,
        soundId,
        sound,
        soundSegmentId,
        soundSegmentStartMs,
        soundSegmentEndMs,
        slots,
        beatMap,
        transitions,
        tracks,
        clips,
        texts,
        stickers,
        overlays,
        assets,
        keyframes,
        renderHints,
      ];
}

/// One media item for `POST /video-templates/projects/from-media` (Flow B).
class ProjectFromMediaInput extends Equatable {
  const ProjectFromMediaInput({
    required this.url,
    required this.type,
  });

  final String url;
  /// `IMAGE` | `VIDEO`
  final String type;

  Map<String, dynamic> toJson() => {
        'url': url,
        'type': type.toUpperCase(),
      };

  @override
  List<Object?> get props => [url, type];
}

/// Prisma `UserTemplateProject`.
class VideoTemplateProjectEntity extends Equatable {
  const VideoTemplateProjectEntity({
    required this.id,
    required this.templateId,
    this.userId,
    this.title,
    this.status = UserTemplateProjectStatuses.editing,
    this.duration,
    this.slots = const [],
    this.editable,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String templateId;
  final String? userId;
  final String? title;
  /// `EDITING` | `RENDERING` | `COMPLETED` | `FAILED` (unknown preserved)
  final String status;
  final double? duration;
  final List<VideoTemplateProjectSlotEntity> slots;
  final TemplateEditableFlags? editable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isEditing =>
      status.toUpperCase() == UserTemplateProjectStatuses.editing;
  bool get isRendering =>
      status.toUpperCase() == UserTemplateProjectStatuses.rendering;
  bool get isCompleted =>
      status.toUpperCase() == UserTemplateProjectStatuses.completed;
  bool get isFailed =>
      status.toUpperCase() == UserTemplateProjectStatuses.failed;

  factory VideoTemplateProjectEntity.fromJson(Map<String, dynamic> json) {
    final slots = _parseList(
      json['slots'] ?? json['projectSlots'] ?? json['userProjectSlots'],
      VideoTemplateProjectSlotEntity.fromJson,
    );
    return VideoTemplateProjectEntity(
      id: json['id']?.toString() ?? '',
      templateId: (json['templateId'] ?? json['videoTemplateId'])?.toString() ??
          '',
      userId: json['userId']?.toString(),
      title: json['title']?.toString(),
      status: UserTemplateProjectStatuses.normalize(json['status']?.toString()),
      duration: _asDoubleOrNull(json['duration']),
      slots: slots,
      editable: json['editable'] is Map
          ? TemplateEditableFlags.fromJson(
              Map<String, dynamic>.from(json['editable'] as Map),
            )
          : null,
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        templateId,
        userId,
        title,
        status,
        duration,
        slots,
        editable,
        createdAt,
        updatedAt,
      ];
}

/// Prisma `UserProjectSlot`.
class VideoTemplateProjectSlotEntity extends Equatable {
  const VideoTemplateProjectSlotEntity({
    required this.id,
    this.slotId,
    this.slotIndex = 0,
    this.userAssetUrl,
    this.trimStart,
    this.trimEnd,
    this.speed = 1,
    this.rotation = 0,
    this.scale = 1,
    this.volume = 1,
  });

  final String id;
  final String? slotId;
  final int slotIndex;
  final String? userAssetUrl;
  final double? trimStart;
  final double? trimEnd;
  final double speed;
  final double rotation;
  final double scale;
  final double volume;

  int get index => slotIndex;

  /// Id for `PATCH …/slots/{slotId}` — prefer template slot UUID from response.
  String get patchSlotId {
    final templateSlot = slotId?.trim();
    if (templateSlot != null &&
        templateSlot.isNotEmpty &&
        VideoTemplateProjectIds.isServerId(templateSlot)) {
      return templateSlot;
    }
    final rowId = id.trim();
    if (rowId.isNotEmpty && VideoTemplateProjectIds.isServerId(rowId)) {
      return rowId;
    }
    return templateSlot ?? rowId;
  }

  factory VideoTemplateProjectSlotEntity.fromJson(Map<String, dynamic> json) {
    final slotRaw = json['slot'];
    var slotIndex = _asInt(json['slotIndex'] ?? json['index']);
    if (slotRaw is Map) {
      final nested = Map<String, dynamic>.from(slotRaw);
      slotIndex = _asInt(nested['slotIndex'] ?? nested['index'] ?? slotIndex);
    }
    return VideoTemplateProjectSlotEntity(
      id: json['id']?.toString() ?? '',
      slotId: (json['slotId'] ?? json['templateSlotId'])?.toString(),
      slotIndex: slotIndex,
      userAssetUrl: json['userAssetUrl']?.toString(),
      trimStart: _asDoubleOrNull(json['trimStart']),
      trimEnd: _asDoubleOrNull(json['trimEnd']),
      speed: _asDouble(json['speed'], fallback: 1),
      rotation: _asDouble(json['rotation']),
      scale: _asDouble(json['scale'], fallback: 1),
      volume: _asDouble(json['volume'], fallback: 1),
    );
  }

  @override
  List<Object?> get props => [
        id,
        slotId,
        slotIndex,
        userAssetUrl,
        trimStart,
        trimEnd,
        speed,
        rotation,
        scale,
        volume,
      ];
}

/// Prisma `ProjectExport`.
class VideoTemplateExportEntity extends Equatable {
  const VideoTemplateExportEntity({
    required this.id,
    required this.projectId,
    this.status = TemplateExportStatuses.queued,
    this.progress = 0,
    this.exportUrl,
    this.resolution,
    this.fps,
    this.fileSize,
    this.errorMessage,
    this.stage,
    this.stageLabel,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  /// `QUEUED` | `PROCESSING` | `COMPLETED` | `FAILED` (unknown preserved)
  final String status;
  final double progress;
  final String? exportUrl;
  final String? resolution;
  final double? fps;
  final int? fileSize;
  final String? errorMessage;
  /// Internal stage (`slots`, `concat`, `overlay`, `mux`, …).
  final String? stage;
  /// Human-readable progress label for UI.
  final String? stageLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isComplete =>
      status.toUpperCase() == TemplateExportStatuses.completed;
  bool get isFailed => status.toUpperCase() == TemplateExportStatuses.failed;
  bool get isQueued => status.toUpperCase() == TemplateExportStatuses.queued;
  bool get isProcessing =>
      status.toUpperCase() == TemplateExportStatuses.processing;

  factory VideoTemplateExportEntity.fromJson(Map<String, dynamic> json) {
    return VideoTemplateExportEntity(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      status: TemplateExportStatuses.normalize(json['status']?.toString()),
      progress: _asDouble(json['progress']),
      exportUrl: (json['exportUrl'] ?? json['url'])?.toString(),
      resolution: json['resolution']?.toString(),
      fps: _asDoubleOrNull(json['fps']),
      fileSize: _asIntOrNull(json['fileSize'] ?? json['sizeBytes']),
      errorMessage:
          (json['errorMessage'] ?? json['error'] ?? json['message'])?.toString(),
      stage: json['stage']?.toString(),
      stageLabel: json['stageLabel']?.toString(),
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        status,
        progress,
        exportUrl,
        resolution,
        fps,
        fileSize,
        errorMessage,
        stage,
        stageLabel,
        createdAt,
        updatedAt,
      ];
}

/// Immediate response from `POST /video-templates/render` (one-shot export).
class VideoTemplateRenderJobEntity extends Equatable {
  const VideoTemplateRenderJobEntity({
    required this.projectId,
    required this.exportId,
    this.status = TemplateExportStatuses.queued,
    this.progress = 0,
    this.exportUrl,
    this.resolution,
    this.fps,
    this.pollPath,
    this.streamPath,
  });

  final String projectId;
  final String exportId;
  final String status;
  final double progress;
  final String? exportUrl;
  final String? resolution;
  final double? fps;
  final String? pollPath;
  final String? streamPath;

  bool get isComplete =>
      status.toUpperCase() == TemplateExportStatuses.completed;
  bool get isFailed => status.toUpperCase() == TemplateExportStatuses.failed;

  VideoTemplateExportEntity toExportEntity() {
    return VideoTemplateExportEntity(
      id: exportId,
      projectId: projectId,
      status: status,
      progress: progress,
      exportUrl: exportUrl,
      resolution: resolution,
      fps: fps,
    );
  }

  factory VideoTemplateRenderJobEntity.fromJson(Map<String, dynamic> json) {
    return VideoTemplateRenderJobEntity(
      projectId: json['projectId']?.toString() ?? '',
      exportId: (json['exportId'] ?? json['id'])?.toString() ?? '',
      status: TemplateExportStatuses.normalize(json['status']?.toString()),
      progress: _asDouble(json['progress']),
      exportUrl: (json['exportUrl'] ?? json['url'])?.toString(),
      resolution: json['resolution']?.toString(),
      fps: _asDoubleOrNull(json['fps']),
      pollPath: json['pollPath']?.toString(),
      streamPath: json['streamPath']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        projectId,
        exportId,
        status,
        progress,
        exportUrl,
        resolution,
        fps,
        pollPath,
        streamPath,
      ];
}

/// Selection carried through camera → editor → add-post → publish.
class VideoTemplateSelection extends Equatable {
  const VideoTemplateSelection({
    required this.templateId,
    required this.name,
    this.templateKind = VideoTemplateKinds.photoCarousel,
    this.slotCount = 1,
    this.sound,
    this.soundSegmentId,
    this.recipe,
    this.projectId,
  });

  final String templateId;
  final String name;
  final String templateKind;
  final int slotCount;
  final SoundEntity? sound;
  final String? soundSegmentId;
  final VideoTemplateRecipeEntity? recipe;
  /// Prefer a server UUID. `local_*` values are ignored by apply/export.
  final String? projectId;

  /// Server id only — strips client draft keys.
  String? get serverProjectId =>
      VideoTemplateProjectIds.normalizeServerId(projectId);

  VideoTemplateSelection copyWith({
    String? templateId,
    String? name,
    String? templateKind,
    int? slotCount,
    SoundEntity? sound,
    String? soundSegmentId,
    VideoTemplateRecipeEntity? recipe,
    String? projectId,
    bool clearProjectId = false,
  }) {
    return VideoTemplateSelection(
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      templateKind: templateKind ?? this.templateKind,
      slotCount: slotCount ?? this.slotCount,
      sound: sound ?? this.sound,
      soundSegmentId: soundSegmentId ?? this.soundSegmentId,
      recipe: recipe ?? this.recipe,
      projectId: clearProjectId
          ? null
          : VideoTemplateProjectIds.normalizeServerId(
              projectId ?? this.projectId,
            ),
    );
  }

  factory VideoTemplateSelection.fromCard(VideoTemplateCardEntity card) {
    return VideoTemplateSelection(
      templateId: card.id,
      name: card.name,
      templateKind: card.templateKind,
      slotCount: card.slotCount.clamp(1, 99),
      sound: card.sound,
      soundSegmentId: card.soundSegmentId,
    );
  }

  factory VideoTemplateSelection.fromRecipe(VideoTemplateRecipeEntity recipe) {
    return VideoTemplateSelection(
      templateId: recipe.id,
      name: recipe.name,
      templateKind: recipe.templateKind,
      slotCount: recipe.applySlotCount,
      sound: recipe.effectivePreviewSound,
      soundSegmentId: recipe.soundSegmentId,
      recipe: recipe,
    );
  }

  @override
  List<Object?> get props => [
        templateId,
        name,
        templateKind,
        slotCount,
        sound,
        soundSegmentId,
        recipe,
        projectId,
      ];
}

SoundEntity? _parseSound(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  // TemplateMusic-shaped payloads (title + audioUrl, no sound name) skip Sound.
  if (map['title'] != null && map['name'] == null && map['author'] == null) {
    return null;
  }
  try {
    return SoundEntity.fromJson(map);
  } catch (_) {
    return null;
  }
}

TemplateMusicEntity? _parseMusic(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  // Prefer TemplateMusic shape; Sound-shaped maps are handled by [_parseSound].
  final looksLikeMusic = map['title'] != null ||
      (map['audioUrl'] != null && map['name'] == null);
  if (!looksLikeMusic && map['name'] != null) return null;
  try {
    return TemplateMusicEntity.fromJson(map);
  } catch (_) {
    return null;
  }
}

String? _parseSegmentId(Map<String, dynamic> json) {
  final segment = json['soundSegment'];
  if (segment is Map) {
    final id = segment['id']?.toString();
    if (id != null && id.isNotEmpty) return id;
  }
  return json['soundSegmentId']?.toString();
}

List<T> _parseList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw is! List) return const [];
  final out = <T>[];
  for (final item in raw) {
    if (item is Map) {
      try {
        out.add(fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Skip malformed entries — never crash recipe parse.
      }
    }
  }
  return out;
}

List<double> _parseDoubleList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map(_asDouble).where((e) => e >= 0).toList(growable: false);
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().trim().toLowerCase();
  if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
  if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
  return fallback;
}

int? _asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? _asDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  if (value is int) {
    if (value > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
  return null;
}
