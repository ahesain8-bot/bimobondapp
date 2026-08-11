import 'dart:convert';

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:equatable/equatable.dart';

/// Local editable project — never mutates [VideoTemplateRecipeEntity].
///
/// Mirrors backend `UserTemplateProject` + user layer overrides. Binary media
/// lives on disk via [mediaId] refs, not in this document.
class UserTemplateProjectDraft extends Equatable {
  const UserTemplateProjectDraft({
    required this.id,
    required this.templateId,
    required this.templateVersion,
    required this.createdAt,
    required this.updatedAt,
    this.backendProjectId,
    this.templateVersionId,
    this.title,
    this.status = UserTemplateProjectStatuses.editing,
    this.duration,
    this.slots = const [],
    this.filters = const [],
    this.effects = const [],
    this.texts = const [],
    this.stickers = const [],
    this.overlays = const [],
    this.keyframes = const [],
    this.audio,
    this.userModifications = const {},
  });

  /// Stable local id (often equals backend project id when known).
  final String id;
  final String? backendProjectId;
  final String templateId;
  final int templateVersion;
  final String? templateVersionId;
  final String? title;
  final String status;
  final double? duration;
  final List<UserProjectSlotDraft> slots;
  final List<UserProjectFilterDraft> filters;
  final List<UserProjectEffectDraft> effects;
  final List<UserProjectTextDraft> texts;
  final List<UserProjectStickerDraft> stickers;
  final List<UserProjectOverlayDraft> overlays;
  final List<UserProjectKeyframeDraft> keyframes;
  final UserProjectAudioDraft? audio;
  /// Free-form user overrides that don't map to a typed layer yet.
  final Map<String, dynamic> userModifications;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Server UUID only — never falls back to a `local_*` draft id.
  String? get effectiveBackendId =>
      VideoTemplateProjectIds.normalizeServerId(backendProjectId) ??
      VideoTemplateProjectIds.normalizeServerId(id);

  UserTemplateProjectDraft copyWith({
    String? backendProjectId,
    String? title,
    String? status,
    double? duration,
    List<UserProjectSlotDraft>? slots,
    List<UserProjectFilterDraft>? filters,
    List<UserProjectEffectDraft>? effects,
    List<UserProjectTextDraft>? texts,
    List<UserProjectStickerDraft>? stickers,
    List<UserProjectOverlayDraft>? overlays,
    List<UserProjectKeyframeDraft>? keyframes,
    UserProjectAudioDraft? audio,
    Map<String, dynamic>? userModifications,
    DateTime? updatedAt,
    bool clearAudio = false,
  }) {
    return UserTemplateProjectDraft(
      id: id,
      backendProjectId: backendProjectId ?? this.backendProjectId,
      templateId: templateId,
      templateVersion: templateVersion,
      templateVersionId: templateVersionId,
      title: title ?? this.title,
      status: status ?? this.status,
      duration: duration ?? this.duration,
      slots: slots ?? this.slots,
      filters: filters ?? this.filters,
      effects: effects ?? this.effects,
      texts: texts ?? this.texts,
      stickers: stickers ?? this.stickers,
      overlays: overlays ?? this.overlays,
      keyframes: keyframes ?? this.keyframes,
      audio: clearAudio ? null : (audio ?? this.audio),
      userModifications: userModifications ?? this.userModifications,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'backendProjectId': backendProjectId,
        'templateId': templateId,
        'templateVersion': templateVersion,
        'templateVersionId': templateVersionId,
        'title': title,
        'status': status,
        'duration': duration,
        'slots': slots.map((e) => e.toJson()).toList(),
        'filters': filters.map((e) => e.toJson()).toList(),
        'effects': effects.map((e) => e.toJson()).toList(),
        'texts': texts.map((e) => e.toJson()).toList(),
        'stickers': stickers.map((e) => e.toJson()).toList(),
        'overlays': overlays.map((e) => e.toJson()).toList(),
        'keyframes': keyframes.map((e) => e.toJson()).toList(),
        'audio': audio?.toJson(),
        'userModifications': userModifications,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  factory UserTemplateProjectDraft.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic raw, DateTime fallback) {
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw)?.toUtc() ?? fallback;
      }
      return fallback;
    }

    final now = DateTime.now().toUtc();
    return UserTemplateProjectDraft(
      id: json['id']?.toString() ?? '',
      backendProjectId: json['backendProjectId']?.toString(),
      templateId: json['templateId']?.toString() ?? '',
      templateVersion: (json['templateVersion'] as num?)?.toInt() ?? 1,
      templateVersionId: json['templateVersionId']?.toString(),
      title: json['title']?.toString(),
      status: UserTemplateProjectStatuses.normalize(json['status']?.toString()),
      duration: (json['duration'] as num?)?.toDouble(),
      slots: _mapList(json['slots'], UserProjectSlotDraft.fromJson),
      filters: _mapList(json['filters'], UserProjectFilterDraft.fromJson),
      effects: _mapList(json['effects'], UserProjectEffectDraft.fromJson),
      texts: _mapList(json['texts'], UserProjectTextDraft.fromJson),
      stickers: _mapList(json['stickers'], UserProjectStickerDraft.fromJson),
      overlays: _mapList(json['overlays'], UserProjectOverlayDraft.fromJson),
      keyframes: _mapList(json['keyframes'], UserProjectKeyframeDraft.fromJson),
      audio: json['audio'] is Map
          ? UserProjectAudioDraft.fromJson(
              Map<String, dynamic>.from(json['audio'] as Map),
            )
          : null,
      userModifications: json['userModifications'] is Map
          ? Map<String, dynamic>.from(json['userModifications'] as Map)
          : const {},
      createdAt: parseDate(json['createdAt'], now),
      updatedAt: parseDate(json['updatedAt'], now),
    );
  }

  factory UserTemplateProjectDraft.decode(String raw) =>
      UserTemplateProjectDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );

  /// Bootstrap empty slots from an immutable recipe (template never mutated).
  factory UserTemplateProjectDraft.fromRecipe({
    required String projectId,
    required VideoTemplateRecipeEntity recipe,
    String? backendProjectId,
    String? title,
  }) {
    final now = DateTime.now().toUtc();
    final recipeSlots = List<VideoTemplateSlotEntity>.from(recipe.slots)
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final count = recipe.applySlotCount.clamp(1, 99);
    final slots = <UserProjectSlotDraft>[];
    for (var i = 0; i < count; i++) {
      final recipeSlot = i < recipeSlots.length ? recipeSlots[i] : null;
      slots.add(
        UserProjectSlotDraft(
          id: 'local_slot_$i',
          templateSlotId: recipeSlot?.id,
          slotIndex: recipeSlot?.slotIndex ?? i,
          mediaType: recipeSlot?.isImage == true || recipe.isPhotoCarousel
              ? 'IMAGE'
              : 'VIDEO',
          duration: recipeSlot?.resolvedDurationSeconds,
        ),
      );
    }
    final serverId = VideoTemplateProjectIds.normalizeServerId(backendProjectId) ??
        VideoTemplateProjectIds.normalizeServerId(projectId);
    return UserTemplateProjectDraft(
      id: projectId,
      backendProjectId: serverId,
      templateId: recipe.id,
      templateVersion: recipe.version,
      templateVersionId: recipe.versionInfo?.id,
      title: title ?? recipe.name,
      status: UserTemplateProjectStatuses.editing,
      duration: (recipe.duration != null && recipe.duration! > 0)
          ? recipe.duration
          : null,
      slots: slots,
      audio: recipe.sound != null || recipe.soundSegmentId != null
          ? UserProjectAudioDraft(
              soundId: recipe.soundId ?? recipe.sound?.id,
              soundSegmentId: recipe.soundSegmentId,
              volume: 1,
            )
          : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  static List<T> _mapList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => parse(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  @override
  List<Object?> get props => [
        id,
        backendProjectId,
        templateId,
        templateVersion,
        templateVersionId,
        title,
        status,
        duration,
        slots,
        filters,
        effects,
        texts,
        stickers,
        overlays,
        keyframes,
        audio,
        userModifications,
        createdAt,
        updatedAt,
      ];
}

class UserProjectSlotDraft extends Equatable {
  const UserProjectSlotDraft({
    required this.id,
    required this.slotIndex,
    this.templateSlotId,
    this.mediaId,
    this.mediaType = 'IMAGE',
    this.uploadedUrl,
    this.trimStart,
    this.trimEnd,
    this.duration,
    this.speed = 1,
    this.volume = 1,
    this.cropLeft,
    this.cropTop,
    this.cropRight,
    this.cropBottom,
    this.positionX = 0,
    this.positionY = 0,
    this.scale = 1,
    this.rotation = 0,
  });

  final String id;
  final String? templateSlotId;
  final int slotIndex;
  final String? mediaId;
  final String mediaType;
  final String? uploadedUrl;
  final double? trimStart;
  final double? trimEnd;
  final double? duration;
  final double speed;
  final double volume;
  final double? cropLeft;
  final double? cropTop;
  final double? cropRight;
  final double? cropBottom;
  final double positionX;
  final double positionY;
  final double scale;
  final double rotation;

  UserProjectSlotDraft copyWith({
    String? mediaId,
    String? mediaType,
    String? uploadedUrl,
    double? trimStart,
    double? trimEnd,
    double? duration,
    double? speed,
    double? volume,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
    double? positionX,
    double? positionY,
    double? scale,
    double? rotation,
    bool clearMedia = false,
    bool clearUploadedUrl = false,
  }) {
    return UserProjectSlotDraft(
      id: id,
      templateSlotId: templateSlotId,
      slotIndex: slotIndex,
      mediaId: clearMedia ? null : (mediaId ?? this.mediaId),
      mediaType: mediaType ?? this.mediaType,
      uploadedUrl:
          clearUploadedUrl ? null : (uploadedUrl ?? this.uploadedUrl),
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      cropLeft: cropLeft ?? this.cropLeft,
      cropTop: cropTop ?? this.cropTop,
      cropRight: cropRight ?? this.cropRight,
      cropBottom: cropBottom ?? this.cropBottom,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateSlotId': templateSlotId,
        'slotIndex': slotIndex,
        'mediaId': mediaId,
        'mediaType': mediaType,
        'uploadedUrl': uploadedUrl,
        'trimStart': trimStart,
        'trimEnd': trimEnd,
        'duration': duration,
        'speed': speed,
        'volume': volume,
        'cropLeft': cropLeft,
        'cropTop': cropTop,
        'cropRight': cropRight,
        'cropBottom': cropBottom,
        'positionX': positionX,
        'positionY': positionY,
        'scale': scale,
        'rotation': rotation,
      };

  factory UserProjectSlotDraft.fromJson(Map<String, dynamic> json) {
    return UserProjectSlotDraft(
      id: json['id']?.toString() ?? '',
      templateSlotId: json['templateSlotId']?.toString(),
      slotIndex: (json['slotIndex'] as num?)?.toInt() ?? 0,
      mediaId: json['mediaId']?.toString(),
      mediaType: json['mediaType']?.toString() ?? 'IMAGE',
      uploadedUrl: json['uploadedUrl']?.toString(),
      trimStart: (json['trimStart'] as num?)?.toDouble(),
      trimEnd: (json['trimEnd'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble() ?? 1,
      volume: (json['volume'] as num?)?.toDouble() ?? 1,
      cropLeft: (json['cropLeft'] as num?)?.toDouble(),
      cropTop: (json['cropTop'] as num?)?.toDouble(),
      cropRight: (json['cropRight'] as num?)?.toDouble(),
      cropBottom: (json['cropBottom'] as num?)?.toDouble(),
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        templateSlotId,
        slotIndex,
        mediaId,
        mediaType,
        uploadedUrl,
        trimStart,
        trimEnd,
        duration,
        speed,
        volume,
        cropLeft,
        cropTop,
        cropRight,
        cropBottom,
        positionX,
        positionY,
        scale,
        rotation,
      ];
}

class UserProjectFilterDraft extends Equatable {
  const UserProjectFilterDraft({
    required this.id,
    required this.filterName,
    this.slotId,
    this.intensity = 1,
    this.lutAssetId,
  });

  final String id;
  final String? slotId;
  final String filterName;
  final double intensity;
  final String? lutAssetId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'slotId': slotId,
        'filterName': filterName,
        'intensity': intensity,
        'lutAssetId': lutAssetId,
      };

  factory UserProjectFilterDraft.fromJson(Map<String, dynamic> json) {
    return UserProjectFilterDraft(
      id: json['id']?.toString() ?? '',
      slotId: json['slotId']?.toString(),
      filterName: json['filterName']?.toString() ?? '',
      intensity: (json['intensity'] as num?)?.toDouble() ?? 1,
      lutAssetId: json['lutAssetId']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, slotId, filterName, intensity, lutAssetId];
}

class UserProjectEffectDraft extends Equatable {
  const UserProjectEffectDraft({
    required this.id,
    required this.effectType,
    this.slotId,
    this.startTime,
    this.endTime,
    this.parameters = const {},
  });

  final String id;
  final String? slotId;
  final String effectType;
  final double? startTime;
  final double? endTime;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() => {
        'id': id,
        'slotId': slotId,
        'effectType': effectType,
        'startTime': startTime,
        'endTime': endTime,
        'parameters': parameters,
      };

  factory UserProjectEffectDraft.fromJson(Map<String, dynamic> json) {
    return UserProjectEffectDraft(
      id: json['id']?.toString() ?? '',
      slotId: json['slotId']?.toString(),
      effectType: json['effectType']?.toString() ?? '',
      startTime: (json['startTime'] as num?)?.toDouble(),
      endTime: (json['endTime'] as num?)?.toDouble(),
      parameters: json['parameters'] is Map
          ? Map<String, dynamic>.from(json['parameters'] as Map)
          : const {},
    );
  }

  @override
  List<Object?> get props =>
      [id, slotId, effectType, startTime, endTime, parameters];
}

class UserProjectTextDraft extends Equatable {
  const UserProjectTextDraft({
    required this.id,
    required this.text,
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.fontSize,
    this.color,
    this.alignment,
    this.animationIn,
    this.animationOut,
    this.startTime,
    this.endTime,
  });

  final String id;
  final String text;
  final double positionX;
  final double positionY;
  final double? fontSize;
  final String? color;
  final String? alignment;
  final String? animationIn;
  final String? animationOut;
  final double? startTime;
  final double? endTime;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'positionX': positionX,
        'positionY': positionY,
        'fontSize': fontSize,
        'color': color,
        'alignment': alignment,
        'animationIn': animationIn,
        'animationOut': animationOut,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory UserProjectTextDraft.fromJson(Map<String, dynamic> json) {
    return UserProjectTextDraft(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.5,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.5,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      color: json['color']?.toString(),
      alignment: json['alignment']?.toString(),
      animationIn: json['animationIn']?.toString(),
      animationOut: json['animationOut']?.toString(),
      startTime: (json['startTime'] as num?)?.toDouble(),
      endTime: (json['endTime'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        text,
        positionX,
        positionY,
        fontSize,
        color,
        alignment,
        animationIn,
        animationOut,
        startTime,
        endTime,
      ];
}

class UserProjectStickerDraft extends Equatable {
  const UserProjectStickerDraft({
    required this.id,
    required this.assetUrl,
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.scale = 1,
    this.rotation = 0,
    this.startTime,
    this.endTime,
  });

  final String id;
  final String assetUrl;
  final double positionX;
  final double positionY;
  final double scale;
  final double rotation;
  final double? startTime;
  final double? endTime;

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetUrl': assetUrl,
        'positionX': positionX,
        'positionY': positionY,
        'scale': scale,
        'rotation': rotation,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory UserProjectStickerDraft.fromJson(Map<String, dynamic> json) {
    return UserProjectStickerDraft(
      id: json['id']?.toString() ?? '',
      assetUrl: json['assetUrl']?.toString() ?? '',
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.5,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.5,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      startTime: (json['startTime'] as num?)?.toDouble(),
      endTime: (json['endTime'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        assetUrl,
        positionX,
        positionY,
        scale,
        rotation,
        startTime,
        endTime,
      ];
}

class UserProjectOverlayDraft extends Equatable {
  const UserProjectOverlayDraft({
    required this.id,
    required this.assetUrl,
    this.opacity = 1,
    this.startTime,
    this.endTime,
  });

  final String id;
  final String assetUrl;
  final double opacity;
  final double? startTime;
  final double? endTime;

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetUrl': assetUrl,
        'opacity': opacity,
        'startTime': startTime,
        'endTime': endTime,
      };

  factory UserProjectOverlayDraft.fromJson(Map<String, dynamic> json) {
    return UserProjectOverlayDraft(
      id: json['id']?.toString() ?? '',
      assetUrl: json['assetUrl']?.toString() ?? '',
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
      startTime: (json['startTime'] as num?)?.toDouble(),
      endTime: (json['endTime'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [id, assetUrl, opacity, startTime, endTime];
}

class UserProjectKeyframeDraft extends Equatable {
  const UserProjectKeyframeDraft({
    required this.id,
    required this.targetId,
    required this.property,
    required this.time,
    required this.value,
    this.easing,
  });

  final String id;
  final String targetId;
  final String property;
  final double time;
  final dynamic value;
  final String? easing;

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetId': targetId,
        'property': property,
        'time': time,
        'value': value,
        'easing': easing,
      };

  factory UserProjectKeyframeDraft.fromJson(Map<String, dynamic> json) {
    return UserProjectKeyframeDraft(
      id: json['id']?.toString() ?? '',
      targetId: json['targetId']?.toString() ?? '',
      property: json['property']?.toString() ?? '',
      time: (json['time'] as num?)?.toDouble() ?? 0,
      value: json['value'],
      easing: json['easing']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, targetId, property, time, value, easing];
}

class UserProjectAudioDraft extends Equatable {
  const UserProjectAudioDraft({
    this.soundId,
    this.soundSegmentId,
    this.mediaId,
    this.volume = 1,
    this.startMs,
    this.endMs,
  });

  final String? soundId;
  final String? soundSegmentId;
  final String? mediaId;
  final double volume;
  final int? startMs;
  final int? endMs;

  UserProjectAudioDraft copyWith({
    String? soundId,
    String? soundSegmentId,
    String? mediaId,
    double? volume,
    int? startMs,
    int? endMs,
  }) {
    return UserProjectAudioDraft(
      soundId: soundId ?? this.soundId,
      soundSegmentId: soundSegmentId ?? this.soundSegmentId,
      mediaId: mediaId ?? this.mediaId,
      volume: volume ?? this.volume,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'soundId': soundId,
        'soundSegmentId': soundSegmentId,
        'mediaId': mediaId,
        'volume': volume,
        'startMs': startMs,
        'endMs': endMs,
      };

  factory UserProjectAudioDraft.fromJson(Map<String, dynamic> json) {
    return UserProjectAudioDraft(
      soundId: json['soundId']?.toString(),
      soundSegmentId: json['soundSegmentId']?.toString(),
      mediaId: json['mediaId']?.toString(),
      volume: (json['volume'] as num?)?.toDouble() ?? 1,
      startMs: (json['startMs'] as num?)?.toInt(),
      endMs: (json['endMs'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props =>
      [soundId, soundSegmentId, mediaId, volume, startMs, endMs];
}
