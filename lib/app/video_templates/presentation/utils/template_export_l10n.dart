import 'package:bimobondapp/l10n/app_localizations.dart';

/// Maps template-export progress labels (client keys + server [stageLabel])
/// to the active locale.
String localizeTemplateExportLabel(AppLocalizations l10n, String? raw) {
  final label = (raw ?? '').trim();
  if (label.isEmpty) return l10n.templateExportRendering;

  switch (label.toLowerCase()) {
    case 'preparing':
    case 'preparing…':
    case 'preparing...':
      return l10n.templateExportPreparing;
    case 'uploading':
    case 'uploading…':
    case 'uploading...':
      return l10n.templateExportUploading;
    case 'uploaded':
      return l10n.templateExportUploaded;
    case 'preparing slots':
    case 'preparing slots…':
    case 'preparing slots...':
      return l10n.templateExportPreparingSlots;
    case 'rendering':
    case 'rendering…':
    case 'rendering...':
      return l10n.templateExportRendering;
    case 'almost done':
    case 'almost done…':
    case 'almost done...':
      return l10n.templateExportAlmostDone;
    case 'downloading':
    case 'downloading…':
    case 'downloading...':
      return l10n.templateExportDownloading;
    case 'done':
      return l10n.templateExportDone;
  }

  final lower = label.toLowerCase();
  if (lower.contains('upload')) return l10n.templateExportUploading;
  if (lower.contains('download')) return l10n.templateExportDownloading;
  if (lower.contains('prepar') || lower.contains('queue')) {
    return l10n.templateExportPreparing;
  }
  if (lower.contains('render') ||
      lower.contains('encode') ||
      lower.contains('process')) {
    return l10n.templateExportRendering;
  }
  if (lower.contains('done') || lower.contains('complete')) {
    return l10n.templateExportDone;
  }

  return label;
}
