import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Color matrices for recipe `filterName` values (TikTok / admin parity).
///
/// Intensity 0 = identity, 1 = full look. Shared by live preview (and later bake).
abstract final class TemplateFilterMatrices {
  static const identity = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static List<double> forName(String? name, {double intensity = 1}) {
    final t = intensity.clamp(0.0, 1.0);
    final key = (name ?? 'none').trim().toLowerCase();
    if (key.isEmpty || key == 'none' || t <= 0) return identity;

    final full = switch (key) {
      'cinematic' => _cinematic,
      'warm' => _warm,
      'cool' => _cool,
      'vintage' => _vintage,
      'vivid' => _vivid,
      'fade' => _fade,
      'black_white' || 'bw' || 'grayscale' => _bw,
      'sepia' => _sepia,
      'high_contrast' => _highContrast,
      'soft_glow' => _softGlow,
      'teal_orange' => _tealOrange,
      'duotone' => _duotone,
      _ => identity,
    };
    if (identical(full, identity) || t >= 0.999) return full;
    return _lerp(identity, full, t);
  }

  static List<double> _lerp(List<double> a, List<double> b, double t) {
    return List<double>.generate(20, (i) => a[i] + (b[i] - a[i]) * t);
  }

  // 4x5 color matrices (Flutter ColorFilter.matrix).
  static const _cinematic = <double>[
    1.1, 0.05, 0.0, 0, -8,
    0.0, 1.0, 0.05, 0, -4,
    0.05, 0.0, 0.95, 0, 4,
    0, 0, 0, 1, 0,
  ];

  static const _warm = <double>[
    1.15, 0.05, 0.0, 0, 8,
    0.05, 1.05, 0.0, 0, 4,
    0.0, 0.0, 0.85, 0, -6,
    0, 0, 0, 1, 0,
  ];

  static const _cool = <double>[
    0.9, 0.0, 0.05, 0, -4,
    0.0, 1.0, 0.05, 0, 0,
    0.05, 0.05, 1.15, 0, 8,
    0, 0, 0, 1, 0,
  ];

  static const _vintage = <double>[
    0.9, 0.3, 0.1, 0, 10,
    0.2, 0.85, 0.1, 0, 5,
    0.1, 0.2, 0.7, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const _vivid = <double>[
    1.25, -0.05, -0.05, 0, 0,
    -0.05, 1.25, -0.05, 0, 0,
    -0.05, -0.05, 1.25, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const _fade = <double>[
    0.9, 0.05, 0.05, 0, 18,
    0.05, 0.9, 0.05, 0, 18,
    0.05, 0.05, 0.9, 0, 18,
    0, 0, 0, 1, 0,
  ];

  static const _bw = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const _sepia = <double>[
    0.393, 0.769, 0.189, 0, 0,
    0.349, 0.686, 0.168, 0, 0,
    0.272, 0.534, 0.131, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const _highContrast = <double>[
    1.4, 0, 0, 0, -30,
    0, 1.4, 0, 0, -30,
    0, 0, 1.4, 0, -30,
    0, 0, 0, 1, 0,
  ];

  static const _softGlow = <double>[
    1.08, 0.04, 0.04, 0, 12,
    0.04, 1.08, 0.04, 0, 12,
    0.04, 0.04, 1.1, 0, 14,
    0, 0, 0, 1, 0,
  ];

  static const _tealOrange = <double>[
    1.2, 0.05, -0.1, 0, 10,
    -0.05, 1.05, 0.1, 0, 0,
    -0.1, 0.1, 1.15, 0, 5,
    0, 0, 0, 1, 0,
  ];

  /// Warm highlights / cool shadows two-tone.
  static const _duotone = <double>[
    0.45, 0.55, 0.15, 0, 28,
    0.25, 0.35, 0.45, 0, 10,
    0.55, 0.25, 0.65, 0, 35,
    0, 0, 0, 1, 0,
  ];
}

/// Single-photo collage layouts (1 slot + layout effect — not multi-photo).
enum TemplateCollageKind {
  none,
  pip,
  mirrorStack,
  gridTriple,
  lyricSandwich,
  duoSplit,
  quadGrid,
  circlePip,
  filmStrip,
  diagonalSplit,
  sideBySideMirror,
  shapedCutout,
}

/// Visual transform derived from active recipe effects (preview only).
class TemplateEffectVisual {
  const TemplateEffectVisual({
    this.scale = 1,
    this.dx = 0,
    this.dy = 0,
    this.rotation = 0,
    this.opacity = 1,
    this.flashWhite = 0,
    this.rgbSplitPx = 0,
    this.blurSigma = 0,
    this.collage = TemplateCollageKind.none,
    this.pipInsetScale,
    this.pipWidthRatio,
    this.pipHeightRatio,
    this.pipInsetX = 0,
    this.pipInsetY = 0,
    this.pipBgBlur = 0,
    this.pipBgScale = 1.12,
    this.bandHeightRatio = 0.18,
    this.imageCropRatio = 0.41,
    this.bandColor = 0xFFD8D8D8,
    this.duoDirectionVertical = true,
    this.shapedShape = 'circle',
    this.shapedBgUrl,
    this.shapedMaskUrl,
    this.shapedWidthRatio = 0.42,
    this.shapedHeightRatio = 0.42,
    this.shapedPosX = 0,
    this.shapedPosY = 0,
    this.shapedCornerRadius = 48,
    this.lightLeak = 0,
    this.vhs = 0,
    this.duotone = 0,
    this.filmBurn = 0,
  });

  final double scale;
  final double dx;
  final double dy;
  final double rotation;
  final double opacity;
  final double flashWhite;
  final double rgbSplitPx;
  final double blurSigma;
  final TemplateCollageKind collage;
  final double? pipInsetScale;
  final double? pipWidthRatio;
  final double? pipHeightRatio;
  final double pipInsetX;
  final double pipInsetY;
  final double pipBgBlur;
  final double pipBgScale;
  final double bandHeightRatio;
  final double imageCropRatio;
  final int bandColor;

  /// `duo_split`: true = left|right, false = top|bottom.
  final bool duoDirectionVertical;

  final String shapedShape;
  final String? shapedBgUrl;
  final String? shapedMaskUrl;
  final double shapedWidthRatio;
  final double shapedHeightRatio;
  final double shapedPosX;
  final double shapedPosY;
  final double shapedCornerRadius;

  /// Soft overlays (0..1).
  final double lightLeak;
  final double vhs;
  final double duotone;
  final double filmBurn;

  bool get hasPip =>
      collage == TemplateCollageKind.pip &&
      ((pipInsetScale != null && pipInsetScale! > 0) ||
          (pipWidthRatio != null && pipWidthRatio! > 0));

  bool get hasCollage => collage != TemplateCollageKind.none;

  static TemplateEffectVisual resolve(
    Iterable<({String type, double progress, Map<String, dynamic> params})>
        effects,
  ) {
    var scale = 1.0;
    var dx = 0.0;
    var dy = 0.0;
    var rotation = 0.0;
    var opacity = 1.0;
    var flash = 0.0;
    var rgb = 0.0;
    var blur = 0.0;
    var collage = TemplateCollageKind.none;
    double? pipScale;
    double? pipW;
    double? pipH;
    var pipX = 0.0;
    var pipY = 0.0;
    var pipBlur = 0.0;
    var pipBgScale = 1.12;
    var bandHeight = 0.18;
    var imageCrop = 0.41;
    var bandColor = 0xFFD8D8D8;
    var duoVertical = true;
    var shapedShape = 'circle';
    String? shapedBg;
    String? shapedMask;
    var shapedW = 0.42;
    var shapedH = 0.42;
    var shapedX = 0.0;
    var shapedY = 0.0;
    var shapedRadius = 48.0;
    var lightLeak = 0.0;
    var vhs = 0.0;
    var duotone = 0.0;
    var filmBurn = 0.0;

    // Layout first, then motion — last layout wins if stacked (authors shouldn't).
    final ordered = effects.toList(growable: false)
      ..sort((a, b) {
        final aLayout =
            kTemplateLayoutEffectTypes.contains(a.type.toLowerCase());
        final bLayout =
            kTemplateLayoutEffectTypes.contains(b.type.toLowerCase());
        if (aLayout == bLayout) return 0;
        return aLayout ? -1 : 1;
      });

    for (final e in ordered) {
      final p = e.progress.clamp(0.0, 1.0);
      final type = e.type.toLowerCase();
      final params = e.params;

      switch (type) {
        case 'beat_zoom':
        case 'zoom_pulse':
          final peakAt = _d(params['peakAt'], 0.5);
          final peakScale = _d(params['scale'], 1.15);
          final pulse = 1 - ((p - peakAt).abs() / math.max(0.01, 1 - peakAt));
          scale *= 1 + (peakScale - 1) * pulse.clamp(0.0, 1.0);
          break;
        case 'zoom_punch':
          final peak = _d(params['scale'], 1.32).clamp(1.1, 1.6);
          final punch = (1 - p).clamp(0.0, 1.0);
          scale *= 1 + (peak - 1) * punch * punch;
          break;
        case 'ken_burns':
          final endScale = _d(
            params['zoom'] ?? params['scale'],
            1.2,
          );
          scale *= 1 + (endScale - 1) * p;
          final panX = _d(params['panX'], 0.03);
          final panY = _d(params['panY'], 0.01);
          dx += (panX.abs() < 1 ? panX * 300 : panX) * p;
          dy += (panY.abs() < 1 ? panY * 400 : panY) * p;
          break;
        case 'parallax_layers':
          final zoom = _d(params['zoom'], 1.12).clamp(1.04, 1.25);
          scale *= 1 + (zoom - 1) * p;
          dx += math.sin(p * math.pi) * 18;
          dy += math.cos(p * math.pi * 0.7) * 12;
          break;
        case 'whip_pan':
          final strength = _d(params['strength'], 0.18).clamp(0.08, 0.35);
          final sweep = math.sin(p * math.pi);
          dx += sweep * strength * 520;
          blur = math.max(blur, 6 + strength * 40 * sweep);
          break;
        case 'shake':
          final intensity = _d(params['intensity'], 0.4);
          final amp = 8 * intensity;
          dx += math.sin(p * math.pi * 24) * amp;
          dy += math.cos(p * math.pi * 18) * amp * 0.7;
          break;
        case 'rgb_split':
          rgb = math.max(rgb, _d(params['offsetPx'], 8) * (0.4 + 0.6 * p));
          break;
        case 'vhs':
          vhs = math.max(
            vhs,
            0.55 + 0.45 * (0.5 + 0.5 * math.sin(p * math.pi * 6)),
          );
          rgb = math.max(rgb, 5 + 4 * p);
          break;
        case 'light_leak':
          lightLeak = math.max(
            lightLeak,
            (0.35 + 0.55 * math.sin(p * math.pi)).clamp(0.0, 1.0),
          );
          break;
        case 'duotone':
          duotone = math.max(duotone, 0.85);
          break;
        case 'flash_frame':
        case 'flash':
          flash = math.max(flash, (1 - (p - 0.1).abs() * 4).clamp(0.0, 1.0));
          break;
        case 'blur_in':
          blur = math.max(blur, 8 * (1 - p));
          break;
        case 'blur_out':
          blur = math.max(blur, 8 * p);
          break;
        case 'spin':
          final deg = _d(params['degrees'], _d(params['turns'], 0.05) * 360);
          rotation += deg * p * math.pi / 180;
          break;
        case 'mirror':
          break;
        case 'pip_layout':
          collage = TemplateCollageKind.pip;
          final rawW = _d(params['pipWidthRatio'], 0);
          pipW = rawW > 0 ? rawW : 0.36;
          pipH = pipW;
          pipScale = pipW;
          final centerX = _d(params['pipCenterX'], double.nan);
          if (!centerX.isNaN) {
            pipX = centerX * 540;
          } else {
            pipX = _d(params['insetX'], 0);
          }
          pipY = _d(params['insetY'], 0);
          pipBlur = _d(
            params['backgroundBlur'] ?? params['bgBlur'],
            12,
          );
          pipBgScale = _d(params['backgroundScale'], 1.0);
          break;
        case 'circle_pip':
          collage = TemplateCollageKind.circlePip;
          final rawW = _d(params['pipWidthRatio'], 0);
          pipW = rawW > 0 ? rawW : 0.42;
          pipH = pipW;
          pipScale = pipW;
          pipBlur = _d(params['backgroundBlur'] ?? params['bgBlur'], 14);
          pipBgScale = _d(params['backgroundScale'], 1.08);
          break;
        case 'mirror_stack':
          collage = TemplateCollageKind.mirrorStack;
          break;
        case 'grid_triple':
          collage = TemplateCollageKind.gridTriple;
          break;
        case 'lyric_sandwich':
          collage = TemplateCollageKind.lyricSandwich;
          bandHeight = _d(params['bandHeightRatio'], 0.18).clamp(0.08, 0.35);
          imageCrop = _d(params['imageCropRatio'], 0.41).clamp(0.2, 0.7);
          bandColor = _colorInt(params['bandColor'], 0xFFD8D8D8);
          break;
        case 'duo_split':
          collage = TemplateCollageKind.duoSplit;
          final dir = '${params['direction'] ?? 'vertical'}'.toLowerCase();
          duoVertical = dir != 'horizontal';
          break;
        case 'quad_grid':
          collage = TemplateCollageKind.quadGrid;
          break;
        case 'film_strip':
          collage = TemplateCollageKind.filmStrip;
          break;
        case 'diagonal_split':
          collage = TemplateCollageKind.diagonalSplit;
          break;
        case 'side_by_side_mirror':
          collage = TemplateCollageKind.sideBySideMirror;
          break;
        case 'shaped_cutout':
          collage = TemplateCollageKind.shapedCutout;
          shapedShape = '${params['shape'] ?? 'circle'}'.toLowerCase();
          shapedBg = _s(params['backgroundAssetUrl']);
          shapedMask = _s(params['maskAssetUrl']);
          shapedW = _d(params['widthRatio'] ?? params['pipWidthRatio'], 0.42)
              .clamp(0.15, 0.95);
          shapedH = _d(params['heightRatio'], shapedW).clamp(0.15, 0.95);
          if (shapedShape == 'circle') shapedH = shapedW;
          shapedX = _d(params['positionX'], 0);
          shapedY = _d(params['positionY'], 0);
          shapedRadius = _d(params['cornerRadius'], 48);
          break;
        default:
          break;
      }
    }

    return TemplateEffectVisual(
      scale: scale,
      dx: dx,
      dy: dy,
      rotation: rotation,
      opacity: opacity,
      flashWhite: flash,
      rgbSplitPx: rgb,
      blurSigma: blur,
      collage: collage,
      pipInsetScale: pipScale,
      pipWidthRatio: pipW,
      pipHeightRatio: pipH,
      pipInsetX: pipX,
      pipInsetY: pipY,
      pipBgBlur: pipBlur,
      pipBgScale: pipBgScale,
      bandHeightRatio: bandHeight,
      imageCropRatio: imageCrop,
      bandColor: bandColor,
      duoDirectionVertical: duoVertical,
      shapedShape: shapedShape,
      shapedBgUrl: shapedBg,
      shapedMaskUrl: shapedMask,
      shapedWidthRatio: shapedW,
      shapedHeightRatio: shapedH,
      shapedPosX: shapedX,
      shapedPosY: shapedY,
      shapedCornerRadius: shapedRadius,
      lightLeak: lightLeak,
      vhs: vhs,
      duotone: duotone,
      filmBurn: filmBurn,
    );
  }

  static double _d(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? fallback;
  }

  static String? _s(dynamic v) {
    final s = '$v'.trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  /// Accepts `0xd8d8d8`, `#D8D8D8`, or int.
  static int _colorInt(dynamic v, int fallback) {
    if (v is int) return v | 0xFF000000;
    if (v is num) return v.toInt() | 0xFF000000;
    final s = '$v'.trim().toLowerCase();
    if (s.isEmpty) return fallback;
    var hex = s;
    if (hex.startsWith('0x')) hex = hex.substring(2);
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'ff$hex';
    return int.tryParse(hex, radix: 16) ?? fallback;
  }
}

/// Center-origin canvas offsets → [Alignment] (0,0 = middle; +Y = down).
///
/// Defaults match recipe canvas 1080×1920 (half = 540×960).
Alignment templateCanvasAlignment(
  double positionX,
  double positionY, {
  int canvasWidth = 1080,
  int canvasHeight = 1920,
}) {
  final halfW = (canvasWidth > 0 ? canvasWidth : 1080) / 2.0;
  final halfH = (canvasHeight > 0 ? canvasHeight : 1920) / 2.0;
  return Alignment(
    (positionX / halfW).clamp(-1.0, 1.0),
    (positionY / halfH).clamp(-1.0, 1.0),
  );
}

/// Layout effect types that require a compositor (not full-screen media alone).
const kTemplateLayoutEffectTypes = <String>{
  'pip_layout',
  'mirror_stack',
  'grid_triple',
  'lyric_sandwich',
  'duo_split',
  'quad_grid',
  'circle_pip',
  'film_strip',
  'diagonal_split',
  'side_by_side_mirror',
  'shaped_cutout',
};

bool templateHasLayoutEffect(Iterable<String> effectTypes) {
  for (final t in effectTypes) {
    if (kTemplateLayoutEffectTypes.contains(t.toLowerCase())) return true;
  }
  return false;
}
