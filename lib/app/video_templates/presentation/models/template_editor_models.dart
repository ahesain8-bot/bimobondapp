import 'package:equatable/equatable.dart';

/// Bottom toolbar / edit sheet panels (TikTok-style).
enum TemplateEditorPanel {
  edit,
  audio,
  text,
  effects,
  filters,
  stickers,
}

/// Which preset catalog to load in the picker sheet.
enum TemplatePresetKind {
  filter,
  effect,
  sticker,
}

/// Catalog preset tile (filter / effect / sticker).
class TemplatePresetItem extends Equatable {
  const TemplatePresetItem({
    required this.id,
    required this.name,
    required this.kind,
    this.thumbnailUrl,
    this.filterName,
    this.effectType,
    this.assetUrl,
    this.category,
  });

  final String id;
  final String name;
  final TemplatePresetKind kind;
  final String? thumbnailUrl;

  /// Local preview key for filters (`TemplateFilterMatrices`).
  final String? filterName;

  /// Local preview key for effects.
  final String? effectType;
  final String? assetUrl;
  final String? category;

  bool get isClear => id.isEmpty || id == 'none';

  factory TemplatePresetItem.fromJson(
    Map<String, dynamic> json, {
    required TemplatePresetKind kind,
  }) {
    final id = json['id']?.toString() ?? '';
    final name = (json['name'] ?? json['label'] ?? json['title'])?.toString() ??
        'Preset';
    return TemplatePresetItem(
      id: id,
      name: name,
      kind: kind,
      thumbnailUrl: (json['thumbnailUrl'] ?? json['coverUrl'] ?? json['previewUrl'])
          ?.toString(),
      filterName: (json['filterName'] ?? json['filterType'] ?? json['slug'])
          ?.toString(),
      effectType: (json['effectType'] ?? json['effectName'] ?? json['slug'])
          ?.toString(),
      assetUrl: (json['assetUrl'] ?? json['url'])?.toString(),
      category: json['category']?.toString(),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, kind, thumbnailUrl, filterName, effectType, assetUrl, category];
}

/// User-applied slot filter — replaces admin slot filters in merged preview.
class UserSlotFilterOverride extends Equatable {
  const UserSlotFilterOverride({
    this.presetId,
    required this.filterName,
    this.intensity = 1,
    this.startTime = 0,
    this.endTime,
  });

  final String? presetId;
  final String filterName;
  final double intensity;

  /// Seconds from slot start when filter begins.
  final double startTime;

  /// Seconds from slot start when filter ends; null = slot end.
  final double? endTime;

  UserSlotFilterOverride copyWith({
    String? presetId,
    String? filterName,
    double? intensity,
    double? startTime,
    double? endTime,
  }) {
    return UserSlotFilterOverride(
      presetId: presetId ?? this.presetId,
      filterName: filterName ?? this.filterName,
      intensity: intensity ?? this.intensity,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  List<Object?> get props =>
      [presetId, filterName, intensity, startTime, endTime];
}

/// User-applied slot effect — replaces admin slot effects in merged preview.
class UserSlotEffectOverride extends Equatable {
  const UserSlotEffectOverride({
    this.presetId,
    required this.effectType,
    this.parameters = const {},
    this.startTime = 0,
    this.endTime,
  });

  final String? presetId;
  final String effectType;
  final Map<String, dynamic> parameters;

  /// Seconds from slot start when effect begins.
  final double startTime;

  /// Seconds from slot start when effect ends; null = slot end.
  final double? endTime;

  UserSlotEffectOverride copyWith({
    String? presetId,
    String? effectType,
    Map<String, dynamic>? parameters,
    double? startTime,
    double? endTime,
  }) {
    return UserSlotEffectOverride(
      presetId: presetId ?? this.presetId,
      effectType: effectType ?? this.effectType,
      parameters: parameters ?? this.parameters,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  List<Object?> get props =>
      [presetId, effectType, parameters, startTime, endTime];
}

/// Caption added in the editor (maps to POST …/texts).
class UserEditorTextOverlay extends Equatable {
  const UserEditorTextOverlay({
    required this.id,
    required this.text,
    this.fontSize = 48,
    this.color = '#FFFFFF',
    this.positionY = 120,
    this.startTime = 0,
    this.endTime = 5,
    this.animationIn,
    this.animationOut,
  });

  final String id;
  final String text;
  final double fontSize;
  final String color;
  final double positionY;
  final double startTime;
  final double endTime;
  final String? animationIn;
  final String? animationOut;

  UserEditorTextOverlay copyWith({
    String? id,
    String? text,
    double? fontSize,
    String? color,
    double? positionY,
    double? startTime,
    double? endTime,
    String? animationIn,
    String? animationOut,
  }) {
    return UserEditorTextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      positionY: positionY ?? this.positionY,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      animationIn: animationIn ?? this.animationIn,
      animationOut: animationOut ?? this.animationOut,
    );
  }

  @override
  List<Object?> get props => [
        id,
        text,
        fontSize,
        color,
        positionY,
        startTime,
        endTime,
        animationIn,
        animationOut,
      ];
}

/// When template / original sound plays on the edit timeline (seconds).
class UserEditorAudioTiming extends Equatable {
  const UserEditorAudioTiming({
    this.startTime = 0,
    this.endTime,
  });

  final double startTime;
  final double? endTime;

  UserEditorAudioTiming copyWith({
    double? startTime,
    double? endTime,
  }) {
    return UserEditorAudioTiming(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  List<Object?> get props => [startTime, endTime];
}

/// Sticker placed in the editor (maps to POST …/stickers).
class UserEditorStickerOverlay extends Equatable {
  const UserEditorStickerOverlay({
    required this.id,
    this.presetId,
    this.assetUrl,
    this.positionX = 0,
    this.positionY = -200,
    this.scale = 1,
    this.opacity = 1,
    this.startTime = 0,
    this.endTime,
  });

  final String id;
  final String? presetId;
  final String? assetUrl;
  final double positionX;
  final double positionY;
  final double scale;
  final double opacity;
  final double startTime;
  final double? endTime;

  UserEditorStickerOverlay copyWith({
    String? id,
    String? presetId,
    String? assetUrl,
    double? positionX,
    double? positionY,
    double? scale,
    double? opacity,
    double? startTime,
    double? endTime,
  }) {
    return UserEditorStickerOverlay(
      id: id ?? this.id,
      presetId: presetId ?? this.presetId,
      assetUrl: assetUrl ?? this.assetUrl,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  List<Object?> get props => [
        id,
        presetId,
        assetUrl,
        positionX,
        positionY,
        scale,
        opacity,
        startTime,
        endTime,
      ];
}

/// Built-in filter presets when API catalog is unavailable.
const kFallbackFilterPresets = <TemplatePresetItem>[
  TemplatePresetItem(
    id: 'none',
    name: 'None',
    kind: TemplatePresetKind.filter,
    filterName: 'none',
  ),
  TemplatePresetItem(
    id: 'cinematic',
    name: 'Cinematic',
    kind: TemplatePresetKind.filter,
    filterName: 'cinematic',
  ),
  TemplatePresetItem(
    id: 'warm',
    name: 'Warm',
    kind: TemplatePresetKind.filter,
    filterName: 'warm',
  ),
  TemplatePresetItem(
    id: 'cool',
    name: 'Cool',
    kind: TemplatePresetKind.filter,
    filterName: 'cool',
  ),
  TemplatePresetItem(
    id: 'vintage',
    name: 'Vintage',
    kind: TemplatePresetKind.filter,
    filterName: 'vintage',
  ),
  TemplatePresetItem(
    id: 'vivid',
    name: 'Vivid',
    kind: TemplatePresetKind.filter,
    filterName: 'vivid',
  ),
  TemplatePresetItem(
    id: 'fade',
    name: 'Fade',
    kind: TemplatePresetKind.filter,
    filterName: 'fade',
  ),
  TemplatePresetItem(
    id: 'bw',
    name: 'B&W',
    kind: TemplatePresetKind.filter,
    filterName: 'bw',
  ),
];

const kFallbackEffectPresets = <TemplatePresetItem>[
  TemplatePresetItem(
    id: 'none',
    name: 'None',
    kind: TemplatePresetKind.effect,
    effectType: 'none',
  ),
  TemplatePresetItem(
    id: 'zoom_in',
    name: 'Zoom in',
    kind: TemplatePresetKind.effect,
    effectType: 'zoom_in',
  ),
  TemplatePresetItem(
    id: 'zoom_out',
    name: 'Zoom out',
    kind: TemplatePresetKind.effect,
    effectType: 'zoom_out',
  ),
  TemplatePresetItem(
    id: 'shake',
    name: 'Shake',
    kind: TemplatePresetKind.effect,
    effectType: 'shake',
  ),
  TemplatePresetItem(
    id: 'pulse',
    name: 'Pulse',
    kind: TemplatePresetKind.effect,
    effectType: 'pulse',
  ),
];
