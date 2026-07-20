import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

String arFilterLabel(AppLocalizations l10n, ArFilterItem item) {
  return arFilterLabelFromId(l10n, item.id, fallback: item.label);
}

String arFilterLabelFromId(
  AppLocalizations l10n,
  String id, {
  String? fallback,
}) {
  return switch (id) {
    'none' => l10n.cameraFilterOriginal,
    'glasses' => l10n.cameraEffectGlasses,
    'shades' => l10n.cameraEffectSunglasses,
    'dog' => l10n.cameraEffectDog,
    'moustache' => l10n.cameraEffectMoustache,
    'mask' => fallback ?? 'Mask',
    'big_eyes' => l10n.cameraEffectBigEyes,
    'big_lips' => l10n.cameraEffectBigLips,
    'long_nose' => l10n.cameraEffectNose,
    'whitening' => l10n.cameraFilterPure,
    'clarendon' => l10n.cameraFilterBright,
    'ludwig' => l10n.cameraFilterClean,
    'rosy' => l10n.cameraFilterSoft,
    'valencia' => l10n.cameraFilterSunset,
    'warm' => l10n.cameraFilterWarm,
    'cool' => l10n.cameraFilterCool,
    'vintage' => l10n.cameraFilterRetro,
    'mono' => l10n.cameraFilterBw,
    _ => fallback ?? id,
  };
}

String arFilterCategoryLabel(
  AppLocalizations l10n,
  ArColorFilterCategory category,
) {
  return arFilterCategoryLabelFromId(
    l10n,
    category.id,
    fallback: category.label,
  );
}

String arFilterCategoryLabelFromId(
  AppLocalizations l10n,
  String id, {
  String? fallback,
}) {
  return switch (id) {
    'portrait' => l10n.cameraCategoryPortrait,
    'life' => l10n.cameraCategoryLife,
    'retro' => l10n.cameraFilterRetro,
    _ => fallback ?? id,
  };
}
