import 'dart:io';

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Result when [AddPostCameraScreen] is opened only to pick more media.
class CameraMediaPickResult {
  const CameraMediaPickResult({
    required this.files,
    required this.type,
    this.filterName,
  });

  final List<File> files;
  final String type;
  final String? filterName;
}

/// Runs gallery items through the media studio editor, then opens add post.
class MediaGalleryImportFlow {
  MediaGalleryImportFlow._();

  static List<Map<String, String>> itemsToExtra(List<GalleryMediaItem> items) {
    return items
        .map(
          (item) => {
            'path': item.file.path,
            'type': item.type,
          },
        )
        .toList(growable: false);
  }

  static String resolvePostType(List<File> files) {
    if (files.isEmpty) return 'IMAGE';
    final hasVideo = files.any(VideoThumbnailUtils.isVideoFile);
    if (files.length > 1) {
      return hasVideo ? 'VIDEO' : 'CAROUSEL';
    }
    return hasVideo ? 'VIDEO' : 'IMAGE';
  }

  static Future<MediaStudioExportResult?> openBatchEditor(
    BuildContext context, {
    required List<GalleryMediaItem> items,
    bool isStory = false,
    Object? initialSound,
    int initialIndex = 0,
    MediaEditorSeed? initialEdit,
  }) {
    if (items.isEmpty) return Future.value(null);

    return context.pushNamed<MediaStudioExportResult>(
      'media_studio_editor',
      extra: {
        'items': itemsToExtra(items),
        'initialIndex': initialIndex,
        'isStory': isStory,
        'initialSound': initialSound,
        'popOnDone': true,
        if (initialEdit != null) 'initialEdit': initialEdit.toExtra(),
      },
    );
  }

  static Future<void> editAndOpenComposer(
    BuildContext context, {
    required List<GalleryMediaItem> items,
    bool isStory = false,
    Object? initialSound,
    bool replaceRoute = true,
  }) async {
    final edited = await openBatchEditor(
      context,
      items: items,
      isStory: isStory,
      initialSound: initialSound,
    );
    if (edited == null || edited.files.isEmpty || !context.mounted) return;

    final extra = {
      'files': edited.files,
      'type': resolvePostType(edited.files),
      'isStory': isStory,
      'initialSound': initialSound,
      if (edited.filterName != null) 'filterName': edited.filterName,
    };

    if (replaceRoute) {
      context.pushReplacementNamed('add_post', extra: extra);
    } else {
      context.pushNamed('add_post', extra: extra);
    }
  }

  static Future<MediaStudioExportResult?> editAndReturn(
    BuildContext context, {
    required List<GalleryMediaItem> items,
    bool isStory = false,
  }) {
    return openBatchEditor(context, items: items, isStory: isStory);
  }
}
