import 'dart:io';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
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

  /// Key for [TemplateFilterMatrices] / local preview (not the display name).
  String get previewFilterKey => normalizeFilterPreviewKey(
        filterName ?? name,
      );

  /// Key for [TemplateEffectVisual] / local preview (not the display name).
  String get previewEffectKey => normalizeEffectPreviewKey(
        effectType ?? name,
      );

  /// Maps API / display names to local preview matrix keys.
  static String normalizeFilterPreviewKey(String? raw) {
    var key = _slugKey(raw);
    if (key.isEmpty || key == 'none') return 'none';
    if (key.startsWith('filter_')) {
      key = key.substring('filter_'.length);
    }
    key = switch (key) {
      'black_white' || 'blackandwhite' || 'grayscale' || 'mono' => 'bw',
      'black_and_white' => 'bw',
      'highcontrast' => 'high_contrast',
      'softglow' => 'soft_glow',
      'tealandorange' || 'teal_and_orange' => 'teal_orange',
      _ => key,
    };
    const known = {
      'cinematic',
      'warm',
      'cool',
      'vintage',
      'vivid',
      'fade',
      'bw',
      'sepia',
      'high_contrast',
      'soft_glow',
      'teal_orange',
      'duotone',
    };
    return known.contains(key) ? key : key;
  }

  /// Maps API / display names to local effect visual keys.
  static String normalizeEffectPreviewKey(String? raw) {
    var key = _slugKey(raw);
    if (key.isEmpty || key == 'none') return 'none';
    if (key.startsWith('effect_')) {
      key = key.substring('effect_'.length);
    }
    key = switch (key) {
      'zoomin' || 'zoom_in_effect' => 'zoom_in',
      'zoomout' || 'zoom_out_effect' => 'zoom_out',
      'kenburns' || 'ken_burns' || 'ken_burn' => 'ken_burns',
      'slowzoom' || 'slow_zoom' => 'zoom_in',
      'punch' || 'zoom_punch' => 'zoom_punch',
      _ => key,
    };
    return key;
  }

  static String _slugKey(String? raw) {
    final s = raw?.trim().toLowerCase() ?? '';
    if (s.isEmpty) return '';
    return s
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  factory TemplatePresetItem.fromJson(
    Map<String, dynamic> json, {
    required TemplatePresetKind kind,
  }) {
    final id = json['id']?.toString() ?? '';
    final name = (json['name'] ?? json['label'] ?? json['title'])?.toString() ??
        'Preset';
    final engineType = json['engineType']?.toString();
    final rawFilter = (json['filterName'] ??
            json['filterType'] ??
            engineType ??
            json['slug'] ??
            json['key'] ??
            json['code'] ??
            json['presetKey'])
        ?.toString();
    final rawEffect = (json['effectType'] ??
            json['effectName'] ??
            engineType ??
            json['slug'] ??
            json['key'] ??
            json['code'] ??
            json['presetKey'])
        ?.toString();
    return TemplatePresetItem(
      id: id,
      name: name,
      kind: kind,
      thumbnailUrl: (json['thumbnailUrl'] ?? json['coverUrl'] ?? json['previewUrl'])
          ?.toString(),
      filterName: kind == TemplatePresetKind.filter
          ? normalizeFilterPreviewKey(rawFilter ?? name)
          : (rawFilter != null ? normalizeFilterPreviewKey(rawFilter) : null),
      effectType: kind == TemplatePresetKind.effect
          ? normalizeEffectPreviewKey(rawEffect ?? name)
          : (rawEffect != null ? normalizeEffectPreviewKey(rawEffect) : null),
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

const kMaxFiltersPerSlot = 8;
const kMaxEffectsPerSlot = 8;

/// One filter layer on a slot (stack up to [kMaxFiltersPerSlot]).
class UserEditorFilterTrack extends Equatable {
  const UserEditorFilterTrack({
    required this.id,
    required this.slotId,
    this.presetId,
    required this.filterName,
    this.label,
    this.intensity = 1,
    this.startTime = 0,
    this.endTime,
  });

  final String id;
  final String slotId;
  final String? presetId;
  final String filterName;
  final String? label;
  final double intensity;
  final double startTime;
  final double? endTime;

  String get displayName {
    final l = label?.trim();
    if (l != null && l.isNotEmpty) return l;
    return filterName;
  }

  UserEditorFilterTrack copyWith({
    String? id,
    String? slotId,
    String? presetId,
    String? filterName,
    String? label,
    double? intensity,
    double? startTime,
    double? endTime,
  }) {
    return UserEditorFilterTrack(
      id: id ?? this.id,
      slotId: slotId ?? this.slotId,
      presetId: presetId ?? this.presetId,
      filterName: filterName ?? this.filterName,
      label: label ?? this.label,
      intensity: intensity ?? this.intensity,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  List<Object?> get props =>
      [id, slotId, presetId, filterName, label, intensity, startTime, endTime];
}

/// One effect layer on a slot (stack up to [kMaxEffectsPerSlot]).
class UserEditorEffectTrack extends Equatable {
  const UserEditorEffectTrack({
    required this.id,
    required this.slotId,
    this.presetId,
    required this.effectType,
    this.label,
    this.parameters = const {},
    this.startTime = 0,
    this.endTime,
  });

  final String id;
  final String slotId;
  final String? presetId;
  final String effectType;
  final String? label;
  final Map<String, dynamic> parameters;
  final double startTime;
  final double? endTime;

  String get displayName {
    final l = label?.trim();
    if (l != null && l.isNotEmpty) return l;
    return effectType;
  }

  UserEditorEffectTrack copyWith({
    String? id,
    String? slotId,
    String? presetId,
    String? effectType,
    String? label,
    Map<String, dynamic>? parameters,
    double? startTime,
    double? endTime,
  }) {
    return UserEditorEffectTrack(
      id: id ?? this.id,
      slotId: slotId ?? this.slotId,
      presetId: presetId ?? this.presetId,
      effectType: effectType ?? this.effectType,
      label: label ?? this.label,
      parameters: parameters ?? this.parameters,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  List<Object?> get props => [
        id,
        slotId,
        presetId,
        effectType,
        label,
        parameters,
        startTime,
        endTime,
      ];
}

/// Avoids [ArgumentError] when [min] > [max] (short clips / timeline edges).
double safeEditorClamp(double value, double min, double max) {
  if (min > max) return max;
  return value.clamp(min, max);
}

/// Clip-local effect/filter window (seconds from slot start).
///
/// See server timing guide: minimum 0.05s, `endTime` clamped to slot duration.
class SlotLocalTiming {
  const SlotLocalTiming({required this.start, required this.end});

  final double start;
  final double end;

  static SlotLocalTiming normalize({
    required double slotDuration,
    double startTime = 0,
    double? endTime,
  }) {
    final dur = slotDuration > 0 ? slotDuration : 0.05;
    final start = startTime.clamp(0.0, dur);
    final end = safeEditorClamp(endTime ?? dur, start + 0.05, dur);
    return SlotLocalTiming(start: start, end: end);
  }

  /// Whether [localTime] (seconds from slot start) falls inside the window.
  static bool containsLocalTime({
    required double slotDuration,
    required double localTime,
    double startTime = 0,
    double? endTime,
  }) {
    final window = normalize(
      slotDuration: slotDuration,
      startTime: startTime,
      endTime: endTime,
    );
    return localTime >= window.start && localTime < window.end;
  }
}

/// Normalize template / API coordinates to center-origin canvas pixels (1080×1920).
///
/// Handles normalized (-1…1), top-left absolute, and center-origin offsets.
({double x, double y}) normalizeEditorCanvasPosition({
  required double positionX,
  required double positionY,
  int canvasWidth = 1080,
  int canvasHeight = 1920,
}) {
  final cw = canvasWidth > 0 ? canvasWidth : 1080;
  final ch = canvasHeight > 0 ? canvasHeight : 1920;
  final halfW = cw / 2.0;
  final halfH = ch / 2.0;

  var x = positionX;
  var y = positionY;

  // Normalized alignment-style (-1…1).
  if (x.abs() <= 1.05 && y.abs() <= 1.05) {
    return (x: x * halfW, y: y * halfH);
  }

  // Top-left absolute pixels → center origin.
  if (x >= 0 && x <= cw && y >= 0 && y <= ch) {
    return (x: x - halfW, y: y - halfH);
  }

  return (
    x: x.clamp(-halfW + 8, halfW - 8),
    y: y.clamp(-halfH + 8, halfH - 8),
  );
}

/// Caption added in the editor (maps to POST …/texts).
class UserEditorTextOverlay extends Equatable {
  const UserEditorTextOverlay({
    required this.id,
    required this.text,
    this.fontSize = 48,
    this.color = '#FFFFFF',
    this.positionX = 0,
    this.positionY = 120,
    this.startTime = 0,
    this.endTime = 5,
    this.animationIn,
    this.animationOut,
    this.fontAssetId,
    this.fontAssetUrl,
    this.fontLabel,
  });

  final String id;
  final String text;
  final double fontSize;
  final String color;
  /// Canvas offset in 1080×1920 space (0,0 = center).
  final double positionX;
  final double positionY;
  final double startTime;
  final double endTime;
  final String? animationIn;
  final String? animationOut;
  final String? fontAssetId;
  final String? fontAssetUrl;
  final String? fontLabel;

  UserEditorTextOverlay copyWith({
    String? id,
    String? text,
    double? fontSize,
    String? color,
    double? positionX,
    double? positionY,
    double? startTime,
    double? endTime,
    String? animationIn,
    String? animationOut,
    String? fontAssetId,
    String? fontAssetUrl,
    String? fontLabel,
    bool clearFont = false,
  }) {
    return UserEditorTextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      animationIn: animationIn ?? this.animationIn,
      animationOut: animationOut ?? this.animationOut,
      fontAssetId: clearFont ? null : (fontAssetId ?? this.fontAssetId),
      fontAssetUrl: clearFont ? null : (fontAssetUrl ?? this.fontAssetUrl),
      fontLabel: clearFont ? null : (fontLabel ?? this.fontLabel),
    );
  }

  @override
  List<Object?> get props => [
        id,
        text,
        fontSize,
        color,
        positionX,
        positionY,
        startTime,
        endTime,
        animationIn,
        animationOut,
        fontAssetId,
        fontAssetUrl,
        fontLabel,
      ];
}

/// Font catalog item from `GET /video-templates/fonts`.
class TemplateFontItem extends Equatable {
  const TemplateFontItem({
    required this.id,
    required this.label,
    required this.url,
    this.thumbnailUrl,
    this.sizeBytes,
  });

  final String id;
  final String label;
  final String url;
  final String? thumbnailUrl;
  final int? sizeBytes;

  /// Flutter [TextStyle.fontFamily] key after [TemplateFontCache.load].
  String get familyName => 'tpl_font_$id';

  factory TemplateFontItem.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final url = (json['url'] ?? json['assetUrl'] ?? '').toString();
    var label = (json['label'] ?? json['name'] ?? '').toString().trim();
    if (label.isEmpty && url.isNotEmpty) {
      final file = url.split('/').last;
      label = file.contains('.')
          ? file.substring(0, file.lastIndexOf('.'))
          : file;
      label = label.replaceAll(RegExp(r'[-_]+'), ' ').trim();
      if (label.isEmpty) label = 'Font';
    }
    if (label.isEmpty) label = 'Font';
    return TemplateFontItem(
      id: id,
      label: label,
      url: url,
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      sizeBytes: json['sizeBytes'] is int
          ? json['sizeBytes'] as int
          : int.tryParse('${json['sizeBytes'] ?? ''}'),
    );
  }

  @override
  List<Object?> get props => [id, label, url, thumbnailUrl, sizeBytes];
}

/// Returned when the user finishes Edit (top Apply) — render then continue to Next.
class VideoTemplateEditorFinishResult extends Equatable {
  const VideoTemplateEditorFinishResult({
    required this.selection,
    this.renderedFile,
    this.serverExportUrl,
    this.proceedToNext = false,
  });

  final VideoTemplateSelection selection;
  final File? renderedFile;
  final String? serverExportUrl;
  /// When true, studio runs the Next / post handoff with the rendered media.
  final bool proceedToNext;

  @override
  List<Object?> get props =>
      [selection, renderedFile, serverExportUrl, proceedToNext];
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

/// One background music layer on the global timeline (maps to `audios[]` on render).
class UserEditorAudioTrack extends Equatable {
  const UserEditorAudioTrack({
    required this.id,
    required this.sound,
    this.soundSegmentId,
    this.segmentStartMs = 0,
    this.segmentEndMs,
    this.startTime = 0,
    this.endTime,
  });

  final String id;
  final SoundEntity sound;
  final String? soundSegmentId;

  /// Trim in-point on the source sound file (milliseconds).
  final int segmentStartMs;

  /// Trim out-point on the source sound file (milliseconds).
  final int? segmentEndMs;

  /// When this track plays on the exported video (seconds, global timeline).
  final double startTime;

  /// When this track stops on the exported video (seconds, global timeline).
  final double? endTime;

  String get name {
    final n = sound.name.trim();
    return n.isNotEmpty ? n : 'Audio';
  }

  /// Timeline bar label — sound name + visible period as text.
  String timelineLabel({required double totalDuration}) {
    final end = endTime ?? totalDuration;
    return '$name · ${formatEditorSeconds(startTime)}–${formatEditorSeconds(end)}';
  }

  UserEditorAudioTrack copyWith({
    String? id,
    SoundEntity? sound,
    String? soundSegmentId,
    int? segmentStartMs,
    int? segmentEndMs,
    double? startTime,
    double? endTime,
  }) {
    return UserEditorAudioTrack(
      id: id ?? this.id,
      sound: sound ?? this.sound,
      soundSegmentId: soundSegmentId ?? this.soundSegmentId,
      segmentStartMs: segmentStartMs ?? this.segmentStartMs,
      segmentEndMs: segmentEndMs ?? this.segmentEndMs,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sound,
        soundSegmentId,
        segmentStartMs,
        segmentEndMs,
        startTime,
        endTime,
      ];
}

/// `0:02` / `1:05` for editor timeline labels.
String formatEditorSeconds(double seconds) {
  final s = seconds.clamp(0, 86400).floor();
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

/// Sticker placed in the editor (maps to POST …/stickers).
class UserEditorStickerOverlay extends Equatable {
  const UserEditorStickerOverlay({
    required this.id,
    this.presetId,
    this.assetUrl,
    this.label,
    this.positionX = 0,
    this.positionY = 0,
    this.scale = 1,
    this.opacity = 1,
    this.startTime = 0,
    this.endTime,
  });

  final String id;
  final String? presetId;
  final String? assetUrl;
  /// Emoji or short label when [assetUrl] is missing (built-in presets).
  final String? label;
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
    String? label,
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
      label: label ?? this.label,
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
        label,
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
