import 'package:bimobondapp/app/camera_studio/presentation/utils/camera_studio_l10n.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

class CameraFilterPreset {
  const CameraFilterPreset({
    required this.filter,
    this.thumbnailUrl,
    this.customLabel,
    this.labelKey,
    this.previewColor,
    this.slug,
    this.isOriginal = false,
    this.colorMatrix,
  });

  final AwesomeFilter filter;
  final String? thumbnailUrl;
  final String? customLabel;
  final String? labelKey;
  final Color? previewColor;
  final String? slug;
  final bool isOriginal;
  final List<double>? colorMatrix;

  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;

  String label({AppLocalizations? l10n, String? originalLabel}) {
    if ((isOriginal || filter == AwesomeFilter.None) &&
        originalLabel != null) {
      return originalLabel;
    }
    if (customLabel != null && customLabel!.isNotEmpty) return customLabel!;
    if (labelKey != null && labelKey!.isNotEmpty && l10n != null) {
      return cameraStudioLabelFromKey(l10n, labelKey!);
    }
    return filter.name;
  }
}
