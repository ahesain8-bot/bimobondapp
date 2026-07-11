import 'dart:async';

import 'package:bimobondapp/app/camera_studio/data/models/camera_studio_catalog_model.dart';
import 'package:bimobondapp/app/camera_studio/domain/entities/camera_studio_catalog_entity.dart';
import 'package:bimobondapp/app/camera_studio/presentation/utils/camera_studio_l10n.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_asset_loader.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_placement.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// @deprecated Prefer [CameraEffectDefinition.slug] for API-backed effects.
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
    required this.slug,
    required this.emoji,
    required this.previewColor,
    required this.placement,
    this.assetUrl,
    this.requiresFaceDetection = false,
    this.isScreenEffect = false,
    this.labelKey,
    this.effectType = 'face_ar',
  });

  final String slug;
  final String emoji;
  final Color previewColor;
  final CameraEffectPlacement placement;
  /// Resolved absolute URL when the API provides [assetUrl].
  final String? assetUrl;
  final bool requiresFaceDetection;
  final bool isScreenEffect;
  final String? labelKey;
  final String effectType;

  bool get isNone => slug == 'none';
  bool get hasAsset => CameraEffectAssetLoader.hasAsset(assetUrl);

  CameraEffectId? get legacyId => CameraEffectsCatalog.legacyIdFromSlug(slug);
}

class CameraEffectsCatalog {
  CameraEffectsCatalog._();

  static CameraStudioCatalogEntity _catalog = CameraStudioCatalogModel.bundled();

  static void apply(CameraStudioCatalogEntity catalog) {
    if (catalog.effectCategories.isEmpty) return;
    _catalog = catalog;
    unawaited(preloadAllAssets());
  }

  static List<CameraEffectCategoryEntity> get effectCategories {
    if (_catalog.effectCategories.isEmpty) return const [];
    final categories = List<CameraEffectCategoryEntity>.from(
      _catalog.effectCategories,
    )..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  static List<CameraEffectEntity> effectsForCategorySlug(String slug) {
    for (final category in effectCategories) {
      if (category.slug != slug) continue;
      final effects = List<CameraEffectEntity>.from(category.effects)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return effects;
    }
    return const [];
  }

  /// Effects for the default picker tab (`trending` slug, else first category).
  static List<CameraEffectDefinition> get trending {
    final categories = effectCategories;
    if (categories.isEmpty) return const [];
    final trendingCategory = categories
        .where((c) => c.slug == 'trending')
        .firstOrNull;
    return effectsForCategory(
      trendingCategory?.slug ?? categories.first.slug,
    );
  }

  static List<CameraEffectDefinition> effectsForCategory(String slug) {
    return effectsForCategorySlug(slug)
        .map(definitionFromEntity)
        .toList(growable: false);
  }

  static Future<void> preloadAllAssets() {
    final urls = <String?>[];
    for (final category in effectCategories) {
      for (final effect in category.effects) {
        urls.add(effect.assetUrl);
      }
    }
    return CameraEffectAssetLoader.preloadAll(urls);
  }

  static CameraEffectDefinition definitionFromEntity(CameraEffectEntity entity) {
    final resolvedAsset = CameraEffectAssetLoader.resolveUrl(entity.assetUrl);
    return CameraEffectDefinition(
      slug: entity.slug,
      emoji: entity.emoji ?? '○',
      previewColor:
          parsePreviewColorHex(entity.previewColorHex) ??
          const Color(0xFF7A7A7A),
      placement: CameraEffectPlacementDefaults.resolve(entity),
      assetUrl: resolvedAsset,
      requiresFaceDetection: entity.requiresFaceDetection,
      isScreenEffect: entity.isScreenEffect,
      labelKey: entity.labelKey,
      effectType: entity.effectType,
    );
  }

  static CameraEffectId? effectIdFromSlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    return legacyIdFromSlug(slug);
  }

  static String effectSlug(CameraEffectId? id) {
    if (id == null || id == CameraEffectId.none) return 'none';
    return id.name;
  }

  static CameraEffectId? legacyIdFromSlug(String slug) {
    return CameraEffectId.values.asNameMap()[slug];
  }

  static CameraEffectDefinition? bySlug(String? slug) {
    if (slug == null || slug.isEmpty || slug == 'none') return null;
    for (final category in effectCategories) {
      for (final entity in category.effects) {
        if (entity.slug == slug) return definitionFromEntity(entity);
      }
    }
    return null;
  }

  static CameraEffectDefinition? byId(CameraEffectId? id) {
    if (id == null) return null;
    return bySlug(effectSlug(id));
  }

  static String label(AppLocalizations l10n, CameraEffectDefinition effect) {
    if (effect.labelKey != null && effect.labelKey!.isNotEmpty) {
      return cameraStudioLabelFromKey(l10n, effect.labelKey!);
    }
    return switch (effect.legacyId) {
      CameraEffectId.none => l10n.cameraFilterOriginal,
      CameraEffectId.crown => l10n.cameraEffectCrown,
      CameraEffectId.bunny => l10n.cameraEffectBunny,
      CameraEffectId.sunglasses => l10n.cameraEffectSunglasses,
      CameraEffectId.dog => l10n.cameraEffectDog,
      CameraEffectId.hearts => l10n.cameraEffectHearts,
      CameraEffectId.sparkle => l10n.cameraEffectSparkle,
      CameraEffectId.neon => l10n.cameraEffectNeon,
      CameraEffectId.glitch => l10n.cameraEffectGlitch,
      null => effect.slug,
    };
  }

  static bool needsAnalysis(String? slug) {
    final effect = bySlug(slug);
    if (effect == null || effect.isNone) return false;
    return effect.requiresFaceDetection || effect.isScreenEffect;
  }

  static bool needsFaceDetection(String? slug) {
    return bySlug(slug)?.requiresFaceDetection ?? false;
  }
}
