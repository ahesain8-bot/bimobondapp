import 'package:camerawesome/camerawesome_plugin.dart';

class CameraFilterPreset {
  const CameraFilterPreset({
    required this.filter,
    this.thumbnailAsset,
    this.customLabel,
  });

  final AwesomeFilter filter;
  final String? thumbnailAsset;
  final String? customLabel;

  bool get isOriginal => filter == AwesomeFilter.None;

  bool get hasThumbnail =>
      thumbnailAsset != null && thumbnailAsset!.isNotEmpty;

  String label({String? originalLabel}) {
    if (isOriginal && originalLabel != null) return originalLabel;
    if (customLabel != null) return customLabel!;
    return filter.name;
  }
}
