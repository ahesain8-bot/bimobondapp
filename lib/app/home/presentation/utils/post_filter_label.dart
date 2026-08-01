import 'package:bimobondapp/app/ar_camera/ar_filter_l10n.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

bool isDisplayablePostFilterName(String? filterName) {
  final name = filterName?.trim();
  if (name == null || name.isEmpty) return false;
  final lower = name.toLowerCase();
  return lower != 'original' && lower != 'none';
}

String postFilterDisplayLabel(
  AppLocalizations l10n,
  String filterId, {
  String? apiName,
}) {
  final apiLabel = apiName?.trim();
  if (apiLabel != null && apiLabel.isNotEmpty) return apiLabel;

  final id = filterId.trim();
  if (CameraFilterCatalog.presetForName(id) != null) {
    return CameraFilterCatalog.localizedFilterLabel(l10n, id);
  }
  return arFilterLabelFromId(l10n, id, fallback: id);
}
