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
  });

  final CameraEffectId id;
  final String emoji;
  final Color previewColor;
  final bool requiresFaceDetection;
  final bool isScreenEffect;

  bool get isNone => id == CameraEffectId.none;
}

class CameraEffectsCatalog {
  CameraEffectsCatalog._();

  static const none = CameraEffectDefinition(
    id: CameraEffectId.none,
    emoji: '○',
    previewColor: Color(0xFF555555),
  );

  static const crown = CameraEffectDefinition(
    id: CameraEffectId.crown,
    emoji: '👑',
    previewColor: Color(0xFFFFD700),
    requiresFaceDetection: true,
  );

  static const bunny = CameraEffectDefinition(
    id: CameraEffectId.bunny,
    emoji: '🐰',
    previewColor: Color(0xFFF8BBD0),
    requiresFaceDetection: true,
  );

  static const sunglasses = CameraEffectDefinition(
    id: CameraEffectId.sunglasses,
    emoji: '😎',
    previewColor: Color(0xFF37474F),
    requiresFaceDetection: true,
  );

  static const dog = CameraEffectDefinition(
    id: CameraEffectId.dog,
    emoji: '🐶',
    previewColor: Color(0xFF8D6E63),
    requiresFaceDetection: true,
  );

  static const hearts = CameraEffectDefinition(
    id: CameraEffectId.hearts,
    emoji: '💕',
    previewColor: Color(0xFFE91E63),
    requiresFaceDetection: true,
  );

  static const sparkle = CameraEffectDefinition(
    id: CameraEffectId.sparkle,
    emoji: '✨',
    previewColor: Color(0xFFCE93D8),
    isScreenEffect: true,
  );

  static const neon = CameraEffectDefinition(
    id: CameraEffectId.neon,
    emoji: '💜',
    previewColor: Color(0xFF7C4DFF),
    isScreenEffect: true,
  );

  static const glitch = CameraEffectDefinition(
    id: CameraEffectId.glitch,
    emoji: '⚡',
    previewColor: Color(0xFF00E5FF),
    isScreenEffect: true,
  );

  static const List<CameraEffectDefinition> trending = [
    none,
    crown,
    bunny,
    sunglasses,
    dog,
    hearts,
    sparkle,
    neon,
    glitch,
  ];

  static CameraEffectDefinition? byId(CameraEffectId? id) {
    if (id == null) return null;
    for (final effect in trending) {
      if (effect.id == id) return effect;
    }
    return null;
  }

  static String label(AppLocalizations l10n, CameraEffectDefinition effect) {
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
