import 'package:bimobondapp/l10n/app_localizations.dart';

/// Maps template-export progress labels (client keys + server [stageLabel])
/// to the active locale. Covers rendering-guide stages (§7).
String localizeTemplateExportLabel(AppLocalizations l10n, String? raw) {
  final label = (raw ?? '').trim();
  if (label.isEmpty) return l10n.templateExportRendering;

  switch (label.toLowerCase()) {
    case 'preparing':
    case 'preparing…':
    case 'preparing...':
    case 'preparing export…':
    case 'preparing export...':
    case 'starting':
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
    case 'rendering clips…':
    case 'rendering clips...':
    case 'slots':
      return l10n.templateExportRendering;
    case 'joining clips…':
    case 'joining clips...':
    case 'concat':
      return l10n.templateExportRendering;
    case 'adding text and stickers…':
    case 'adding text and stickers...':
    case 'overlay':
      return l10n.templateExportRendering;
    case 'adding sound…':
    case 'adding sound...':
    case 'mux':
      return l10n.templateExportRendering;
    case 'finalizing…':
    case 'finalizing...':
    case 'finalize':
    case 'almost done':
    case 'almost done…':
    case 'almost done...':
      return l10n.templateExportAlmostDone;
    case 'downloading':
    case 'downloading…':
    case 'downloading...':
      return l10n.templateExportDownloading;
    case 'done':
    case 'export complete':
      return l10n.templateExportDone;
    case 'failed':
    case 'export failed':
      return l10n.templateExportRendering;
    case 'rendering on device…':
    case 'rendering on device...':
      return l10n.templateExportRendering;
  }

  final lower = label.toLowerCase();
  if (lower.contains('upload')) return l10n.templateExportUploading;
  if (lower.contains('download')) return l10n.templateExportDownloading;
  if (lower.contains('prepar') ||
      lower.contains('queue') ||
      lower.contains('start')) {
    return l10n.templateExportPreparing;
  }
  if (lower.contains('render') ||
      lower.contains('encode') ||
      lower.contains('process') ||
      lower.contains('clip') ||
      lower.contains('overlay') ||
      lower.contains('mux') ||
      lower.contains('concat') ||
      lower.contains('sound') ||
      lower.contains('sticker') ||
      lower.contains('text')) {
    return l10n.templateExportRendering;
  }
  if (lower.contains('final') ||
      lower.contains('done') ||
      lower.contains('complete')) {
    return l10n.templateExportDone;
  }

  return label;
}
