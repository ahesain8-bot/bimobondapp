import 'package:flutter/material.dart';

/// Approximate ColorFilters for [ArFilterCatalog] color grades (preview / export).
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

  static List<double>? matrixFor(String? filterId) {
    return switch (filterId) {
      null || 'none' => null,
      'whitening' => const [
          1.12, 0.02, 0.02, 0, 12,
          0.02, 1.10, 0.02, 0, 10,
          0.02, 0.02, 1.08, 0, 8,
          0, 0, 0, 1, 0,
        ],
      'clarendon' => const [
          1.15, -0.04, 0.04, 0, 8,
          -0.02, 1.12, 0.02, 0, 4,
          0.02, -0.06, 1.20, 0, 6,
          0, 0, 0, 1, 0,
        ],
      'ludwig' => const [
          1.05, 0.02, 0.00, 0, 6,
          0.00, 1.08, 0.02, 0, 4,
          0.00, 0.00, 1.12, 0, 8,
          0, 0, 0, 1, 0,
        ],
      'rosy' => const [
          1.14, 0.04, 0.04, 0, 10,
          0.02, 0.98, 0.02, 0, 4,
          0.06, 0.02, 1.02, 0, 8,
          0, 0, 0, 1, 0,
        ],
      'valencia' => const [
          1.18, 0.06, -0.02, 0, 14,
          0.04, 1.06, -0.02, 0, 8,
          -0.04, 0.00, 0.96, 0, 2,
          0, 0, 0, 1, 0,
        ],
      'warm' => const [
          1.16, 0.08, 0.00, 0, 12,
          0.04, 1.06, 0.00, 0, 6,
          -0.04, -0.02, 0.94, 0, 0,
          0, 0, 0, 1, 0,
        ],
      'cool' => const [
          0.94, 0.00, 0.06, 0, 0,
          0.00, 1.02, 0.06, 0, 4,
          0.04, 0.04, 1.18, 0, 10,
          0, 0, 0, 1, 0,
        ],
      'vintage' => const [
          0.95, 0.10, 0.05, 0, 8,
          0.05, 0.90, 0.05, 0, 4,
          0.05, 0.10, 0.78, 0, 0,
          0, 0, 0, 1, 0,
        ],
      'mono' => const [
          0.33, 0.59, 0.08, 0, 0,
          0.33, 0.59, 0.08, 0, 0,
          0.33, 0.59, 0.08, 0, 0,
          0, 0, 0, 1, 0,
        ],
      _ => null,
    };
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
