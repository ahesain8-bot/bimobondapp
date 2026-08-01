import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> openCameraWithFilter(
  BuildContext context, {
  required String filterName,
  String? filterCategory,
}) async {
  if (!CameraFilterCatalog.isUsableFilterName(filterName)) return;

  final filter = CameraFilterCatalog.filterByName(filterName);
  final category = filterCategory != null
      ? CameraFilterCatalog.categoryFromSlug(filterCategory) ??
          CameraFilterCatalog.categoryForFilter(filter)
      : CameraFilterCatalog.categoryForFilter(filter);

  FeedPlaybackGate.instance.setBlocked(true);
  await context.pushNamed(
    'add_post_camera',
    extra: {
      'initialFilterName': filterName,
      'initialFilterCategory': category.name,
    },
  );
}

/// Opens the camera with the filter used on a post (AR color / CamerAwesome).
Future<void> openCameraWithPostFilter(
  BuildContext context, {
  required String filterId,
  String? filterCategory,
}) async {
  final id = filterId.trim();
  if (id.isEmpty || id.toLowerCase() == 'original' || id.toLowerCase() == 'none') {
    return;
  }

  FeedPlaybackGate.instance.setBlocked(true);

  if (_isArFilterId(id)) {
    await context.pushNamed(
      'add_post_camera',
      extra: {
        'initialArFilterId': id,
        if (filterCategory != null && filterCategory.trim().isNotEmpty)
          'initialArColorCategoryId': filterCategory.trim(),
      },
    );
    return;
  }

  if (CameraFilterCatalog.isUsableFilterName(id)) {
    await openCameraWithFilter(
      context,
      filterName: id,
      filterCategory: filterCategory,
    );
    return;
  }

  // Unknown id — still open camera and let catalog loading resolve it.
  await context.pushNamed(
    'add_post_camera',
    extra: {
      'initialArFilterId': id,
      if (filterCategory != null && filterCategory.trim().isNotEmpty)
        'initialArColorCategoryId': filterCategory.trim(),
    },
  );
}

bool _isArFilterId(String id) {
  if (ArFilterCatalog.colorFilterById(id) != null) return true;
  if (ArFilterCatalog.isColorFilter(id)) return true;
  return ArFilterCatalog.items.any((item) => item.id == id);
}

bool canOpenCameraWithPostFilter(String filterId) {
  final id = filterId.trim();
  if (id.isEmpty || id.toLowerCase() == 'original' || id.toLowerCase() == 'none') {
    return false;
  }
  return _isArFilterId(id) || CameraFilterCatalog.isUsableFilterName(id);
}
