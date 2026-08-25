/// Visual effect that can be applied to the live camera preview.
enum LiveEffectKind {
  /// No effect.
  none,

  /// Landmark-anchored AR overlay (glasses, beard, ears, …).
  faceOverlay,

  /// Full-frame color grading.
  colorGrade,

  /// Approximate virtual background using a head ellipse mask.
  virtualBackground,
}

/// Catalog entry for a selectable live effect.
class LiveEffect {
  const LiveEffect({
    required this.id,
    required this.nameAr,
    required this.kind,
    required this.categoryId,
    this.isClear = false,
  });

  final String id;
  final String nameAr;
  final LiveEffectKind kind;
  final String categoryId;

  /// True for the dedicated "remove effect" tile.
  final bool isClear;

  bool get needsFaceTracking =>
      kind == LiveEffectKind.faceOverlay ||
      kind == LiveEffectKind.virtualBackground;
}

/// Effects category shown in the expanded panel tabs.
class LiveEffectCategory {
  const LiveEffectCategory({
    required this.id,
    required this.labelAr,
  });

  final String id;
  final String labelAr;
}
