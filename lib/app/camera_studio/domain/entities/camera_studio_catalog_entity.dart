import 'package:equatable/equatable.dart';

class CameraStudioCatalogEntity extends Equatable {
  const CameraStudioCatalogEntity({
    required this.version,
    required this.filterCategories,
    required this.effectCategories,
  });

  final String version;
  final List<CameraFilterCategoryEntity> filterCategories;
  final List<CameraEffectCategoryEntity> effectCategories;

  @override
  List<Object?> get props => [version, filterCategories, effectCategories];
}

class CameraFilterCategoryEntity extends Equatable {
  const CameraFilterCategoryEntity({
    required this.slug,
    required this.labelKey,
    required this.sortOrder,
    required this.filters,
  });

  final String slug;
  final String labelKey;
  final int sortOrder;
  final List<CameraFilterEntity> filters;

  @override
  List<Object?> get props => [slug, labelKey, sortOrder, filters];
}

class CameraFilterEntity extends Equatable {
  const CameraFilterEntity({
    required this.slug,
    required this.engineKey,
    this.id,
    this.engineType = 'camerawesome',
    this.labelKey,
    this.customLabel,
    this.thumbnailUrl,
    this.previewColorHex,
    this.isOriginal = false,
    this.isBeautyDefault = false,
    this.sortOrder = 0,
    this.colorMatrix,
  });

  final String? id;
  final String slug;
  final String engineType;
  final String engineKey;
  final String? labelKey;
  final String? customLabel;
  final String? thumbnailUrl;
  final String? previewColorHex;
  final bool isOriginal;
  final bool isBeautyDefault;
  final int sortOrder;
  final List<double>? colorMatrix;

  @override
  List<Object?> get props => [
        id,
        slug,
        engineType,
        engineKey,
        labelKey,
        customLabel,
        thumbnailUrl,
        previewColorHex,
        isOriginal,
        isBeautyDefault,
        sortOrder,
        colorMatrix,
      ];
}

class CameraEffectCategoryEntity extends Equatable {
  const CameraEffectCategoryEntity({
    required this.slug,
    required this.labelKey,
    required this.sortOrder,
    required this.effects,
  });

  final String slug;
  final String labelKey;
  final int sortOrder;
  final List<CameraEffectEntity> effects;

  @override
  List<Object?> get props => [slug, labelKey, sortOrder, effects];
}

class CameraEffectEntity extends Equatable {
  const CameraEffectEntity({
    required this.slug,
    required this.effectType,
    required this.previewColorHex,
    required this.labelKey,
    this.id,
    this.emoji,
    this.assetUrl,
    this.requiresFaceDetection = false,
    this.isScreenEffect = false,
    this.anchorType,
    this.anchorLandmarks = const [],
    this.scaleFactor,
    this.offsetX,
    this.offsetY,
    this.landmarkSize,
    this.fallbackAnchorType,
    this.fallbackOffsetY,
    this.fallbackScaleFactor,
    this.sortOrder = 0,
  });

  final String? id;
  final String slug;
  final String effectType;
  final String? emoji;
  final String? assetUrl;
  final String previewColorHex;
  final String labelKey;
  final bool requiresFaceDetection;
  final bool isScreenEffect;
  final String? anchorType;
  final List<String> anchorLandmarks;
  final double? scaleFactor;
  final double? offsetX;
  final double? offsetY;
  final double? landmarkSize;
  final String? fallbackAnchorType;
  final double? fallbackOffsetY;
  final double? fallbackScaleFactor;
  final int sortOrder;

  @override
  List<Object?> get props => [
        id,
        slug,
        effectType,
        emoji,
        assetUrl,
        previewColorHex,
        labelKey,
        requiresFaceDetection,
        isScreenEffect,
        anchorType,
        anchorLandmarks,
        scaleFactor,
        offsetX,
        offsetY,
        landmarkSize,
        fallbackAnchorType,
        fallbackOffsetY,
        fallbackScaleFactor,
        sortOrder,
      ];
}
