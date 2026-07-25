import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:flutter/material.dart';

/// Renders a selected filter's color grade (brightness/contrast/saturation/
/// warmth — NOT the beauty fields smooth/whiten/blush/lipTint, which need
/// face-landmark detection and aren't supported post-capture yet) as a
/// standard 4x5 Skia/Android [ColorFilter] matrix, so it can be:
///  - shown live in the editor preview ([preview], applied via a
///    `ColorFiltered` widget over the photo/video player), and
///  - baked into an exported video via [exportMatrix] (passed to
///    `NativeVideoProcessor.renderVideoEdits`'s `colorMatrix` argument).
/// Photos are baked separately through `MediaSkinSmooth.apply` (native
/// OpenCV), which reuses the same filter params — see
/// `_bakeColorFilterToFile` in media_studio_editor_screen.dart.
class ArColorFilterMatrix {
  ArColorFilterMatrix._();

  static ColorFilter? preview(String? filterId, {double intensity = 1.0}) {
    final matrix = matrixFor(filterId);
    if (matrix == null) return null;
    final t = intensity.clamp(0.0, 1.0);
    if (t <= 0) return null;
    if (t >= 0.999) return ColorFilter.matrix(matrix);
    return ColorFilter.matrix(_lerpIdentity(matrix, t));
  }

  static List<double>? exportMatrix(String? filterId, {double intensity = 1.0}) {
    final matrix = matrixFor(filterId);
    if (matrix == null) return null;
    final t = intensity.clamp(0.0, 1.0);
    if (t <= 0) return null;
    if (t >= 0.999) return matrix;
    return _lerpIdentity(matrix, t);
  }

  static List<double>? matrixFor(String? filterId) {
    if (filterId == null || filterId.isEmpty) return null;
    final params = ArFilterCatalog.colorFilterById(filterId)?.params;
    if (params == null || !params.hasColorGrade) return null;
    return _buildColorGradeMatrix(
      brightness: params.brightness,
      contrast: params.contrast,
      saturation: params.saturation,
      warmth: params.warmth,
    );
  }

  static const List<double> _identity = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// Composes contrast+brightness, then saturation, then warmth — same order
  /// and same -1..1 -> effect mapping as the native live-preview shader's
  /// applyRetouchColor() (FaceWarpRenderer.kt), so an exported clip's color
  /// grade looks close to what the live camera would have shown with the
  /// same filter. Not byte-exact (that function also has exposure/
  /// highlights/shadows terms this filter model doesn't expose, and combines
  /// steps with an intermediate clamp a single linear matrix can't
  /// replicate) — close enough for a color-grade-only filter.
  static List<double> _buildColorGradeMatrix({
    required double brightness,
    required double contrast,
    required double saturation,
    required double warmth,
  }) {
    var m = _identity;
    if (contrast.abs() > 0.001 || brightness.abs() > 0.001) {
      final alpha = 1 + contrast * 0.5;
      final translate = 128 * (1 - alpha) + brightness * 60;
      m = _multiply(<double>[
        alpha, 0, 0, 0, translate,
        0, alpha, 0, 0, translate,
        0, 0, alpha, 0, translate,
        0, 0, 0, 1, 0,
      ], m);
    }
    if (saturation.abs() > 0.001) {
      final s = 1 + saturation;
      const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
      m = _multiply(<double>[
        lumR * (1 - s) + s, lumG * (1 - s), lumB * (1 - s), 0, 0,
        lumR * (1 - s), lumG * (1 - s) + s, lumB * (1 - s), 0, 0,
        lumR * (1 - s), lumG * (1 - s), lumB * (1 - s) + s, 0, 0,
        0, 0, 0, 1, 0,
      ], m);
    }
    if (warmth.abs() > 0.001) {
      final k = warmth * 0.3;
      m = _multiply(<double>[
        1 + k, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 1 - k, 0, 0,
        0, 0, 0, 1, 0,
      ], m);
    }
    return m;
  }

  /// Composes two Android/Skia-style 4x5 color matrices (`a` applied after
  /// `b`), by embedding both as 5x5 matrices (last row `[0,0,0,0,1]`, so the
  /// translation column composes correctly through the multiply) and
  /// multiplying them as ordinary 5x5 matrices.
  static List<double> _multiply(List<double> aFlat, List<double> bFlat) {
    List<List<double>> to5x5(List<double> flat) => [
          flat.sublist(0, 5),
          flat.sublist(5, 10),
          flat.sublist(10, 15),
          flat.sublist(15, 20),
          const [0, 0, 0, 0, 1],
        ];
    final a = to5x5(aFlat);
    final b = to5x5(bFlat);
    final result = List.generate(5, (_) => List<double>.filled(5, 0));
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < 5; j++) {
        var sum = 0.0;
        for (var k = 0; k < 5; k++) {
          sum += a[i][k] * b[k][j];
        }
        result[i][j] = sum;
      }
    }
    return [
      ...result[0],
      ...result[1],
      ...result[2],
      ...result[3],
    ];
  }

  static List<double> _lerpIdentity(List<double> target, double t) {
    return List<double>.generate(20, (i) {
      return _identity[i] + (target[i] - _identity[i]) * t;
    });
  }
}
