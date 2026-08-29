import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

/// Localized display name for a built-in filter / effect / transition preset.
String localizeTemplatePresetName(
  AppLocalizations l10n,
  TemplatePresetItem preset,
) {
  return localizeTemplatePresetKey(l10n, preset.id) ??
      localizeTemplatePresetKey(l10n, preset.previewFilterKey) ??
      localizeTemplatePresetKey(l10n, preset.previewEffectKey) ??
      localizeTemplatePresetKey(l10n, preset.previewTransitionKey) ??
      preset.name;
}

/// Localized name from a raw preset / filter / effect / transition key.
String? localizeTemplatePresetKey(AppLocalizations l10n, String? raw) {
  if (raw == null) return null;
  final key = raw.trim().toLowerCase();
  if (key.isEmpty) return null;
  switch (key) {
    case 'none':
    case 'cut':
      return l10n.templateEditorPresetNone;
    case 'cinematic':
      return l10n.templateEditorPresetCinematic;
    case 'warm':
      return l10n.templateEditorPresetWarm;
    case 'cool':
      return l10n.templateEditorPresetCool;
    case 'vintage':
      return l10n.templateEditorPresetVintage;
    case 'vivid':
      return l10n.templateEditorPresetVivid;
    case 'fade':
      return l10n.templateEditorPresetFade;
    case 'bw':
    case 'b&w':
      return l10n.templateEditorPresetBw;
    case 'zoom_in':
      return l10n.templateEditorPresetZoomIn;
    case 'zoom_out':
      return l10n.templateEditorPresetZoomOut;
    case 'shake':
      return l10n.templateEditorPresetShake;
    case 'pulse':
      return l10n.templateEditorPresetPulse;
    case 'crossfade':
      return l10n.templateEditorPresetCrossfade;
    case 'flash':
      return l10n.templateEditorPresetFlash;
    case 'slide_left':
      return l10n.templateEditorPresetSlideLeft;
    case 'slide_right':
      return l10n.templateEditorPresetSlideRight;
    case 'zoom':
      return l10n.templateEditorPresetZoom;
    case 'blur':
      return l10n.templateEditorPresetBlur;
    case 'glitch':
      return l10n.templateEditorPresetGlitch;
    case 'film_burn':
      return l10n.templateEditorPresetFilmBurn;
    default:
      return null;
  }
}

/// Localized overlay / track label when the raw value is a known preset key.
String localizeTemplateOverlayLabel(AppLocalizations l10n, String raw) {
  return localizeTemplatePresetKey(l10n, raw) ?? raw;
}
