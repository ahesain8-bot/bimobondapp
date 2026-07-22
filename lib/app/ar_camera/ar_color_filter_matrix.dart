import 'package:flutter/material.dart';

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
    // Color filters are LUT-only — GPU PNG path, no colorMatrix in catalog.
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
