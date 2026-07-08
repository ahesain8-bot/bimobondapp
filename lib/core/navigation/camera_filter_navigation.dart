import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> openCameraWithFilter(
  BuildContext context, {
  required String filterName,
}) async {
  if (!CameraFilterCatalog.isUsableFilterName(filterName)) return;

  final filter = CameraFilterCatalog.filterByName(filterName);
  final category = CameraFilterCatalog.categoryForFilter(filter);

  FeedPlaybackGate.instance.setBlocked(true);
  await context.pushNamed(
    'add_post_camera',
    extra: {
      'initialFilterName': filterName,
      'initialFilterCategory': category.name,
    },
  );
}
