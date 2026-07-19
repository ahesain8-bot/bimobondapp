import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:flutter/material.dart';

/// Approximate ColorFilters for [ArFilterCatalog] color grades (preview / export).
///
/// Matrices are read from [ArFilterCatalog.colorCatalog] (the model), so the
/// bundled/offline data and the future server data share one source of truth.
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

  /// Intensity-adjusted 4x5 color matrix for baking onto files (native export).
  /// Returns null when there's nothing to apply.
  static List<double>? exportMatrix(String? filterId, {double intensity = 1.0}) {
    final matrix = matrixFor(filterId);
    if (matrix == null) return null;
    final t = intensity.clamp(0.0, 1.0);
    if (t <= 0) return null;
    if (t >= 0.999) return matrix;
    return _lerpIdentity(matrix, t);
  }

  static List<double>? matrixFor(String? filterId) {
    if (filterId == null || filterId == 'none') return null;
    for (final category in ArFilterCatalog.colorCatalog.categories) {
      for (final filter in category.filters) {
        if (filter.id == filterId && filter.hasValidMatrix) {
          return filter.colorMatrix;
        }
      }
    }
    return null;
  }

  static List<double> _lerpIdentity(List<double> target, double t) {
    const identity = <double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];
    return List<double>.generate(20, (i) {
      return identity[i] + (target[i] - identity[i]) * t;
    });
  }
}
