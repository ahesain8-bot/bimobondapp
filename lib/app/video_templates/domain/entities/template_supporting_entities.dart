import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/template_schema_enums.dart';
import 'package:equatable/equatable.dart';

/// Prisma `TemplateCategory`.
class TemplateCategoryEntity extends Equatable {
  const TemplateCategoryEntity({
    required this.id,
    required this.name,
    this.iconUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TemplateCategoryEntity.fromJson(Map<String, dynamic> json) {
    return TemplateCategoryEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      iconUrl: json['iconUrl']?.toString(),
      sortOrder: _asInt(json['sortOrder']),
      isActive: json['isActive'] != false,
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, iconUrl, sortOrder, isActive, createdAt, updatedAt];
}

/// Prisma `TemplateMusic` (legacy template-owned audio).
/// Prefer feed [SoundEntity] via `soundId` when both are present.
class TemplateMusicEntity extends Equatable {
  const TemplateMusicEntity({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.artist,
    this.coverUrl,
    this.duration,
    this.bpm,
    this.beatMap,
    this.license,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String audioUrl;
  final String? artist;
  final String? coverUrl;
  /// Duration in seconds (schema).
  final double? duration;
  final double? bpm;
  /// Raw beat map JSON (`{ bpm, beats[], downbeats[], source }`).
  final Map<String, dynamic>? beatMap;
  final String? license;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TemplateMusicEntity.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? beatMap;
    final rawBeat = json['beatMap'];
    if (rawBeat is Map) {
      beatMap = Map<String, dynamic>.from(rawBeat);
    }

    return TemplateMusicEntity(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? json['name'] ?? '').toString(),
      audioUrl: (json['audioUrl'] ?? json['url'] ?? '').toString(),
      artist: (json['artist'] ?? json['author'])?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      duration: _asSecondsOrNull(json['duration']),
      bpm: _asDoubleOrNull(json['bpm']),
      beatMap: beatMap,
      license: json['license']?.toString(),
      isActive: json['isActive'] != false,
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }

  /// Studio / feed preview bed — same shape as library sounds.
  SoundEntity? toSoundEntity() {
    final url = audioUrl.trim();
    if (id.isEmpty || url.isEmpty) return null;
    return SoundEntity(
      id: id,
      name: title.trim().isEmpty ? 'Template music' : title.trim(),
      author: (artist ?? '').trim().isEmpty ? 'Template' : artist!.trim(),
      audioUrl: url,
      coverUrl: coverUrl,
      duration: (duration ?? 0).round().clamp(0, 36000),
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        audioUrl,
        artist,
        coverUrl,
        duration,
        bpm,
        beatMap,
        license,
        isActive,
        createdAt,
        updatedAt,
      ];
}

/// Prisma `TemplateAsset` (LUT / sticker / overlay / font / media packs).
class TemplateAssetEntity extends Equatable {
  const TemplateAssetEntity({
    required this.id,
    required this.url,
    this.type = TemplateAssetTypes.other,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.duration,
    this.sizeBytes,
    this.checksum,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  /// `TemplateAssetType` string — unknown values are preserved.
  final String type;
  final String url;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final double? duration;
  final int? sizeBytes;
  final String? checksum;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLut => type.toUpperCase() == TemplateAssetTypes.lut;
  bool get isFont => type.toUpperCase() == TemplateAssetTypes.font;
  bool get isSticker => type.toUpperCase() == TemplateAssetTypes.sticker;
  bool get isOverlay => type.toUpperCase() == TemplateAssetTypes.overlay;

  factory TemplateAssetEntity.fromJson(Map<String, dynamic> json) {
    return TemplateAssetEntity(
      id: json['id']?.toString() ?? '',
      type: TemplateAssetTypes.normalize(json['type']?.toString()),
      url: (json['url'] ?? json['assetUrl'] ?? '').toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      width: _asIntOrNull(json['width']),
      height: _asIntOrNull(json['height']),
      duration: _asDoubleOrNull(json['duration']),
      sizeBytes: _asIntOrNull(json['sizeBytes'] ?? json['fileSize']),
      checksum: json['checksum']?.toString(),
      createdAt: _asDateTime(json['createdAt']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        url,
        thumbnailUrl,
        width,
        height,
        duration,
        sizeBytes,
        checksum,
        createdAt,
        updatedAt,
      ];
}

/// Prisma `TemplateKeyframe` — property animation on a clip.
class TemplateKeyframeEntity extends Equatable {
  const TemplateKeyframeEntity({
    required this.id,
    required this.property,
    required this.time,
    required this.value,
    this.clipId,
    this.easing,
  });

  final String id;
  final String? clipId;
  /// e.g. `scale`, `positionX`, `opacity`, `volume`
  final String property;
  final double time;
  /// Schema JSON value — number, string, map, or list.
  final dynamic value;
  final String? easing;

  double? get valueAsDouble {
    if (value is num) return (value as num).toDouble();
    if (value is String) return double.tryParse(value as String);
    if (value is Map && value['value'] != null) {
      final nested = value['value'];
      if (nested is num) return nested.toDouble();
      if (nested is String) return double.tryParse(nested);
    }
    return null;
  }

  factory TemplateKeyframeEntity.fromJson(Map<String, dynamic> json) {
    return TemplateKeyframeEntity(
      id: json['id']?.toString() ?? '',
      clipId: json['clipId']?.toString(),
      property: (json['property'] ?? json['prop'] ?? '').toString(),
      time: _asDouble(json['time'] ?? json['t']),
      value: json['value'] ?? json['val'],
      easing: TemplateKeyframeEasings.normalizeNullable(
        json['easing']?.toString(),
      ),
    );
  }

  @override
  List<Object?> get props => [id, clipId, property, time, value, easing];
}

/// Prisma `TemplateVersion` — immutable recipe snapshot metadata.
class TemplateVersionEntity extends Equatable {
  const TemplateVersionEntity({
    required this.id,
    required this.templateId,
    required this.version,
    this.changeLog,
    this.createdAt,
  });

  final String id;
  final String templateId;
  final int version;
  final String? changeLog;
  final DateTime? createdAt;

  factory TemplateVersionEntity.fromJson(Map<String, dynamic> json) {
    return TemplateVersionEntity(
      id: json['id']?.toString() ?? '',
      templateId: (json['templateId'] ?? json['videoTemplateId'])?.toString() ??
          '',
      version: _asInt(json['version'], fallback: 1),
      changeLog: (json['changeLog'] ?? json['changelog'])?.toString(),
      createdAt: _asDateTime(json['createdAt']),
    );
  }

  @override
  List<Object?> get props => [id, templateId, version, changeLog, createdAt];
}

// --- local JSON helpers (keep file self-contained) ---

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
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

/// Accepts seconds (num) or milliseconds when value looks like ms (>= 1000 and int-ish).
double? _asSecondsOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final d = value.toDouble();
    // SoundEntity often uses ms; TemplateMusic uses seconds.
    if (d >= 1000 && d == d.roundToDouble()) return d / 1000.0;
    return d;
  }
  if (value is String) {
    final d = double.tryParse(value);
    if (d == null) return null;
    if (d >= 1000 && d == d.roundToDouble()) return d / 1000.0;
    return d;
  }
  return null;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  if (value is int) {
    // Heuristic: ms vs seconds.
    if (value > 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
  return null;
}
