import 'dart:convert';

import 'package:bimobondapp/app/home/presentation/widgets/stories/story_text_style.dart';
import 'package:flutter/material.dart';

class StoryTextOverlay {
  const StoryTextOverlay({
    required this.id,
    required this.text,
    this.x = 0.5,
    this.y = 0.42,
    this.scale = 1,
    this.rotation = 0,
    this.textColor = Colors.white,
    this.backgroundColor = Colors.white,
    this.backgroundMode = StoryTextBackgroundMode.none,
    this.fontStyle = StoryTextFontStyle.modern,
    this.alignment = StoryTextAlignment.center,
  });

  final String id;
  final String text;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final Color textColor;
  final Color backgroundColor;
  final StoryTextBackgroundMode backgroundMode;
  final StoryTextFontStyle fontStyle;
  final StoryTextAlignment alignment;

  Color get displayTextColor {
    return switch (backgroundMode) {
      StoryTextBackgroundMode.none => textColor,
      StoryTextBackgroundMode.translucent => textColor,
      StoryTextBackgroundMode.solid =>
        StoryTextStyleKit.contrastingTextOn(backgroundColor),
    };
  }

  StoryTextOverlay copyWith({
    String? id,
    String? text,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    Color? textColor,
    Color? backgroundColor,
    StoryTextBackgroundMode? backgroundMode,
    StoryTextFontStyle? fontStyle,
    StoryTextAlignment? alignment,
  }) {
    return StoryTextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      fontStyle: fontStyle ?? this.fontStyle,
      alignment: alignment ?? this.alignment,
    );
  }

  StoryTextOverlay applyPaletteColor(Color color) {
    return switch (backgroundMode) {
      StoryTextBackgroundMode.none =>
        copyWith(textColor: color, backgroundColor: color),
      StoryTextBackgroundMode.translucent ||
      StoryTextBackgroundMode.solid =>
        copyWith(backgroundColor: color, textColor: color),
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'textColor': textColor.toARGB32(),
        'backgroundColor': backgroundColor.toARGB32(),
        'backgroundMode': backgroundMode.name,
        'fontStyle': fontStyle.name,
        'alignment': alignment.jsonValue,
      };

  factory StoryTextOverlay.fromJson(Map<String, dynamic> json) {
    final legacyColor = json['color'] != null
        ? Color((json['color'] as num).toInt())
        : null;

    return StoryTextOverlay(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.42,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      textColor: json['textColor'] != null
          ? Color((json['textColor'] as num).toInt())
          : legacyColor ?? Colors.white,
      backgroundColor: json['backgroundColor'] != null
          ? Color((json['backgroundColor'] as num).toInt())
          : legacyColor ?? Colors.white,
      backgroundMode: _parseBackgroundMode(json),
      fontStyle: _parseFontStyle(json['fontStyle']?.toString()),
      alignment: StoryTextAlignment.fromJson(json['alignment']?.toString()),
    );
  }

  static StoryTextBackgroundMode _parseBackgroundMode(Map<String, dynamic> json) {
    final raw = json['backgroundMode']?.toString();
    if (raw != null) {
      for (final mode in StoryTextBackgroundMode.values) {
        if (mode.name == raw) return mode;
      }
    }
    if (json['hasBackground'] == true) {
      return StoryTextBackgroundMode.translucent;
    }
    return StoryTextBackgroundMode.none;
  }

  static StoryTextFontStyle _parseFontStyle(String? raw) {
    if (raw == null) return StoryTextFontStyle.modern;
    for (final style in StoryTextFontStyle.values) {
      if (style.name == raw) return style;
    }
    return StoryTextFontStyle.modern;
  }
}

class StoryTextOverlayCodec {
  StoryTextOverlayCodec._();

  static const prefixV1 = '__STORY_TEXT_V1__:';
  static const prefixV2 = '__STORY_TEXT_V2__:';

  static String encode(List<StoryTextOverlay> overlays) {
    final items = overlays.where((o) => o.text.trim().isNotEmpty).toList();
    if (items.isEmpty) return '';
    return '$prefixV2${jsonEncode(items.map((e) => e.toJson()).toList())}';
  }

  static List<StoryTextOverlay> decode(String? description) {
    final raw = description?.trim() ?? '';
    if (raw.startsWith(prefixV2)) {
      return _decodeList(raw.substring(prefixV2.length));
    }
    if (raw.startsWith(prefixV1)) {
      return _decodeList(raw.substring(prefixV1.length));
    }
    return const [];
  }

  static List<StoryTextOverlay> _decodeList(String jsonPayload) {
    try {
      final decoded = jsonDecode(jsonPayload);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => StoryTextOverlay.fromJson(Map<String, dynamic>.from(e)))
          .where((o) => o.text.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static bool hasEncodedOverlays(String? description) =>
      decode(description).isNotEmpty;
}
