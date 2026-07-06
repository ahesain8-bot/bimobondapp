import 'package:bimobondapp/app/camera_studio/data/models/camera_studio_catalog_model.dart';
import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/camera_studio/presentation/utils/camera_studio_l10n.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum CameraEffectId {
  none,
  crown,
  bunny,
  sunglasses,
  dog,
  hearts,
  sparkle,
  neon,
  glitch,
}

class CameraEffectDefinition {
  const CameraEffectDefinition({
    required this.id,
    required this.emoji,
    required this.previewColor,
    this.requiresFaceDetection = false,
    this.isScreenEffect = false,
    this.labelKey,
  });

  final CameraEffectId id;
  final String emoji;
  final Color previewColor;
  final bool requiresFaceDetection;
  final bool isScreenEffect;
  final String? labelKey;

  bool get isNone => id == CameraEffectId.none;
}

class CameraEffectsCatalog {
  CameraEffectsCatalog._();

  static CameraStudioCatalogEntity _catalog = CameraStudioCatalogModel.bundled();

  static void apply(CameraStudioCatalogEntity catalog) {
    if (catalog.effectCategories.isEmpty) return;
    _catalog = catalog;
  }

  static List<CameraEffectEntity> get _effects {
    if (_catalog.effectCategories.isEmpty) return const [];
    final categories = List<CameraEffectCategoryEntity>.from(
      _catalog.effectCategories,
    )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (categories.isEmpty) return const [];
    return categories.first.effects;
  }

  static List<CameraEffectDefinition> get trending =>
      _effects.map(definitionFromEntity).toList(growable: false);

  static CameraEffectDefinition definitionFromEntity(CameraEffectEntity entity) {
    return CameraEffectDefinition(
      id: _effectIdFromSlug(entity.slug) ?? CameraEffectId.none,
      emoji: entity.emoji ?? '○',
      previewColor:
          parsePreviewColorHex(entity.previewColorHex) ??
          const Color(0xFF7A7A7A),
      requiresFaceDetection: entity.requiresFaceDetection,
      isScreenEffect: entity.isScreenEffect,
      labelKey: entity.labelKey,
    );
  }

  static CameraEffectId? effectIdFromSlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    return _effectIdFromSlug(slug);
  }

  static String effectSlug(CameraEffectId? id) {
    if (id == null || id == CameraEffectId.none) return 'none';
    return id.name;
  }

  static CameraEffectId? _effectIdFromSlug(String slug) {
    return CameraEffectId.values.asNameMap()[slug];
  }

  static CameraEffectDefinition? byId(CameraEffectId? id) {
    if (id == null) return null;
    for (final effect in trending) {
      if (effect.id == id) return effect;
    }
    return null;
  }

  static String label(AppLocalizations l10n, CameraEffectDefinition effect) {
    if (effect.labelKey != null && effect.labelKey!.isNotEmpty) {
      return cameraStudioLabelFromKey(l10n, effect.labelKey!);
    }
    return switch (effect.id) {
      CameraEffectId.none => l10n.cameraFilterOriginal,
      CameraEffectId.crown => l10n.cameraEffectCrown,
      CameraEffectId.bunny => l10n.cameraEffectBunny,
      CameraEffectId.sunglasses => l10n.cameraEffectSunglasses,
      CameraEffectId.dog => l10n.cameraEffectDog,
      CameraEffectId.hearts => l10n.cameraEffectHearts,
      CameraEffectId.sparkle => l10n.cameraEffectSparkle,
      CameraEffectId.neon => l10n.cameraEffectNeon,
      CameraEffectId.glitch => l10n.cameraEffectGlitch,
    };
  }

  static bool needsAnalysis(CameraEffectId? id) {
    final effect = byId(id);
    if (effect == null || effect.isNone) return false;
    return effect.requiresFaceDetection || effect.isScreenEffect;
  }

  static bool needsFaceDetection(CameraEffectId? id) {
    return byId(id)?.requiresFaceDetection ?? false;
  }
}
