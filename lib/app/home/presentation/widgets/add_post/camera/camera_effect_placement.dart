import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';

/// Placement modes from `GET /camera-studio/catalog` (snake_case).
enum CameraEffectAnchorType {
  onFace('on_face'),
  coverFace('cover_face'),
  aboveFace('above_face'),
  dualAboveFace('dual_above_face'),
  betweenLandmarks('between_landmarks'),
  onLandmark('on_landmark'),
  onLandmarks('on_landmarks'),
  screen('screen');

  const CameraEffectAnchorType(this.apiValue);

  final String apiValue;

  static CameraEffectAnchorType? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.trim().toLowerCase();
    for (final value in values) {
      if (value.apiValue == normalized) return value;
    }
    final screaming = normalized.replaceAll('_', '');
    return switch (screaming) {
      'onface' => onFace,
      'coverface' => coverFace,
      'aboveface' => aboveFace,
      'dualaboveface' => dualAboveFace,
      'betweenlandmarks' => betweenLandmarks,
      'onlandmark' => onLandmark,
      'onlandmarks' => onLandmarks,
      'screen' => screen,
      _ => null,
    };
  }
}

/// Resolved placement metadata for drawing an effect on a face or screen.
class CameraEffectPlacement {
  const CameraEffectPlacement({
    this.anchorType,
    this.anchorLandmarks = const [],
    this.scaleFactor,
    this.offsetX,
    this.offsetY,
    this.landmarkSize,
    this.fallbackAnchorType,
    this.fallbackOffsetY,
    this.fallbackScaleFactor,
  });

  final CameraEffectAnchorType? anchorType;
  final List<CameraFaceLandmarkType> anchorLandmarks;
  final double? scaleFactor;
  final double? offsetX;
  final double? offsetY;
  final double? landmarkSize;
  final CameraEffectAnchorType? fallbackAnchorType;
  final double? fallbackOffsetY;
  final double? fallbackScaleFactor;

  CameraEffectPlacement copyWith({
    CameraEffectAnchorType? anchorType,
    List<CameraFaceLandmarkType>? anchorLandmarks,
    double? scaleFactor,
    double? offsetX,
    double? offsetY,
    double? landmarkSize,
    CameraEffectAnchorType? fallbackAnchorType,
    double? fallbackOffsetY,
    double? fallbackScaleFactor,
  }) {
    return CameraEffectPlacement(
      anchorType: anchorType ?? this.anchorType,
      anchorLandmarks: anchorLandmarks ?? this.anchorLandmarks,
      scaleFactor: scaleFactor ?? this.scaleFactor,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      landmarkSize: landmarkSize ?? this.landmarkSize,
      fallbackAnchorType: fallbackAnchorType ?? this.fallbackAnchorType,
      fallbackOffsetY: fallbackOffsetY ?? this.fallbackOffsetY,
      fallbackScaleFactor: fallbackScaleFactor ?? this.fallbackScaleFactor,
    );
  }
}

/// Seed defaults from `GET /camera-studio/effect-placement/schema`.
class CameraEffectPlacementDefaults {
  CameraEffectPlacementDefaults._();

  /// Eye-anchored placement; must not be replaced by API `on_face` + positive offsetY.
  static const CameraEffectPlacement sunglasses = CameraEffectPlacement(
    anchorType: CameraEffectAnchorType.betweenLandmarks,
    anchorLandmarks: [
      CameraFaceLandmarkType.leftEye,
      CameraFaceLandmarkType.rightEye,
    ],
    scaleFactor: 2.5,
    offsetY: -0.06,
    fallbackAnchorType: CameraEffectAnchorType.onFace,
    fallbackOffsetY: -0.2,
    fallbackScaleFactor: 1,
  );

  static final Map<String, CameraEffectPlacement> bySlug = {
    'sunglasses': sunglasses,
    'crown': const CameraEffectPlacement(
      anchorType: CameraEffectAnchorType.aboveFace,
      scaleFactor: 1.1,
      offsetY: -0.55,
    ),
    'bunny': const CameraEffectPlacement(
      anchorType: CameraEffectAnchorType.dualAboveFace,
      scaleFactor: 0.35,
      offsetX: 0.22,
      offsetY: -0.15,
    ),
    'dog': const CameraEffectPlacement(
      anchorType: CameraEffectAnchorType.coverFace,
      scaleFactor: 1,
    ),
    'hearts': const CameraEffectPlacement(
      anchorType: CameraEffectAnchorType.onFace,
      scaleFactor: 1,
      offsetY: 0,
    ),
    'sparkle': const CameraEffectPlacement(
      anchorType: CameraEffectAnchorType.screen,
    ),
    'neon': const CameraEffectPlacement(
      anchorType: CameraEffectAnchorType.screen,
    ),
    'glitch': const CameraEffectPlacement(
      anchorType: CameraEffectAnchorType.screen,
    ),
  };

  static void applyRemoteDefaults(Map<String, dynamic> defaultsBySlug) {
    for (final entry in defaultsBySlug.entries) {
      final slug = entry.key;
      if (slug == 'sunglasses') continue;
      final raw = entry.value;
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final resolved = _fromJsonMap(map);
      if (resolved.anchorType == null) continue;
      final existing = bySlug[slug];
      bySlug[slug] = existing == null
          ? resolved
          : _mergePlacement(existing, resolved);
    }
  }

  static CameraEffectPlacement resolve(CameraEffectEntity entity) {
    // Sunglasses must anchor between eyes; API `on_face` + positive offsetY sits on the mouth.
    if (entity.slug == 'sunglasses') {
      return sunglasses;
    }

    final fromEntity = _fromEntity(entity);
    final defaults = bySlug[entity.slug];

    // Seeded defaults win over API entity fields for known slugs.
    if (defaults?.anchorType != null) {
      return _mergePlacement(defaults!, fromEntity);
    }

    if (fromEntity.anchorType != null) {
      return fromEntity;
    }

    if (entity.isScreenEffect) {
      return const CameraEffectPlacement(
        anchorType: CameraEffectAnchorType.screen,
      );
    }

    return defaults ?? const CameraEffectPlacement();
  }

  static CameraEffectPlacement _mergePlacement(
    CameraEffectPlacement primary,
    CameraEffectPlacement? defaults,
  ) {
    if (defaults == null) return primary;
    return CameraEffectPlacement(
      anchorType: primary.anchorType ?? defaults.anchorType,
      anchorLandmarks: primary.anchorLandmarks.isNotEmpty
          ? primary.anchorLandmarks
          : defaults.anchorLandmarks,
      scaleFactor: primary.scaleFactor ?? defaults.scaleFactor,
      offsetX: primary.offsetX ?? defaults.offsetX,
      offsetY: primary.offsetY ?? defaults.offsetY,
      landmarkSize: primary.landmarkSize ?? defaults.landmarkSize,
      fallbackAnchorType:
          primary.fallbackAnchorType ?? defaults.fallbackAnchorType,
      fallbackOffsetY: primary.fallbackOffsetY ?? defaults.fallbackOffsetY,
      fallbackScaleFactor:
          primary.fallbackScaleFactor ?? defaults.fallbackScaleFactor,
    );
  }

  static CameraEffectPlacement _fromEntity(CameraEffectEntity entity) {
    return CameraEffectPlacement(
      anchorType: CameraEffectAnchorType.parse(entity.anchorType),
      anchorLandmarks: _parseLandmarkKeys(entity.anchorLandmarks),
      scaleFactor: entity.scaleFactor,
      offsetX: entity.offsetX,
      offsetY: entity.offsetY,
      landmarkSize: entity.landmarkSize,
      fallbackAnchorType:
          CameraEffectAnchorType.parse(entity.fallbackAnchorType),
      fallbackOffsetY: entity.fallbackOffsetY,
      fallbackScaleFactor: entity.fallbackScaleFactor,
    );
  }

  static CameraEffectPlacement _fromJsonMap(Map<String, dynamic> json) {
    final landmarksRaw = json['anchorLandmarks'];
    final landmarks = landmarksRaw is List
        ? _parseLandmarkKeys(landmarksRaw.map((e) => e.toString()).toList())
        : const <CameraFaceLandmarkType>[];

    return CameraEffectPlacement(
      anchorType: CameraEffectAnchorType.parse(json['anchorType']?.toString()),
      anchorLandmarks: landmarks,
      scaleFactor: _readDouble(json['scaleFactor']),
      offsetX: _readDouble(json['offsetX']),
      offsetY: _readDouble(json['offsetY']),
      landmarkSize: _readDouble(json['landmarkSize']),
      fallbackAnchorType:
          CameraEffectAnchorType.parse(json['fallbackAnchorType']?.toString()),
      fallbackOffsetY: _readDouble(json['fallbackOffsetY']),
      fallbackScaleFactor: _readDouble(json['fallbackScaleFactor']),
    );
  }

  static List<CameraFaceLandmarkType> _parseLandmarkKeys(List<String> keys) {
    return keys
        .map(apiLandmarkToNative)
        .whereType<CameraFaceLandmarkType>()
        .toList(growable: false);
  }

  static CameraFaceLandmarkType? apiLandmarkToNative(String key) {
    return switch (key) {
      'leftEye' => CameraFaceLandmarkType.leftEye,
      'rightEye' => CameraFaceLandmarkType.rightEye,
      'noseBase' => CameraFaceLandmarkType.noseBase,
      'mouth' => CameraFaceLandmarkType.mouth,
      'leftEar' => CameraFaceLandmarkType.leftEar,
      'rightEar' => CameraFaceLandmarkType.rightEar,
      _ => null,
    };
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
