import 'dart:io';

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Result when [AddPostCameraScreen] is opened only to pick more media.
class CameraMediaPickResult {
  const CameraMediaPickResult({
    required this.files,
    required this.type,
    this.filterName,
    this.sound,
    this.soundOffset = Duration.zero,
    this.soundWindow = const Duration(seconds: 15),
    this.soundDidTrim = false,
    this.soundSegmentId,
    this.videoTemplateId,
  });

  final List<File> files;
  final String type;
  final String? filterName;
  final SoundEntity? sound;
  final Duration soundOffset;
  final Duration soundWindow;
  final bool soundDidTrim;
  final String? soundSegmentId;
  final String? videoTemplateId;
}

/// Runs gallery items through the media studio editor, then opens add post.
class MediaGalleryImportFlow {
  MediaGalleryImportFlow._();

  static List<Map<String, String>> itemsToExtra(List<GalleryMediaItem> items) {
    return items
        .map((item) => {'path': item.file.path, 'type': item.type})
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

  /// Files shown in Add Post / published as the post body.
  /// Prefers client-rendered template VIDEO over slot stills.
  static List<File> composerFiles(MediaStudioExportResult edited) {
    final rendered = edited.templateRenderedVideo;
    if (rendered != null) return <File>[rendered];
    return edited.files;
  }

  static String composerType(MediaStudioExportResult edited) {
    if (edited.templateRenderedVideo != null) return 'VIDEO';
    return resolvePostType(edited.files);
  }

  static Future<MediaStudioExportResult?> openBatchEditor(
    BuildContext context, {
    required List<GalleryMediaItem> items,
    bool isStory = false,
    Object? initialSound,
    Duration initialSoundOffset = Duration.zero,
    bool initialMuteOriginal = false,
    int initialIndex = 0,
    MediaEditorSeed? initialEdit,
    String? videoTemplateId,
    String? videoTemplateName,
    int? videoTemplateSlotCount,
    String? templateProjectId,
  }) {
    if (items.isEmpty) return Future.value(null);

    return context.pushNamed<MediaStudioExportResult>(
      'media_studio_editor',
      extra: {
        'items': itemsToExtra(items),
        'initialIndex': initialIndex,
        'isStory': isStory,
        'initialSound': initialSound,
        'initialSoundOffsetMs': initialSoundOffset.inMilliseconds,
        'initialMuteOriginal': initialMuteOriginal,
        'popOnDone': true,
        if (initialEdit != null) 'initialEdit': initialEdit.toExtra(),
        if (videoTemplateId != null) 'videoTemplateId': videoTemplateId,
        if (videoTemplateName != null) 'videoTemplateName': videoTemplateName,
        if (videoTemplateSlotCount != null)
          'videoTemplateSlotCount': videoTemplateSlotCount,
        if (templateProjectId != null) 'templateProjectId': templateProjectId,
      },
    );
  }

  static Future<void> editAndOpenComposer(
    BuildContext context, {
    required List<GalleryMediaItem> items,
    bool isStory = false,
    Object? initialSound,
    Duration initialSoundOffset = Duration.zero,
    bool initialMuteOriginal = false,
    bool replaceRoute = true,
  }) async {
    final edited = await openBatchEditor(
      context,
      items: items,
      isStory: isStory,
      initialSound: initialSound,
      initialSoundOffset: initialSoundOffset,
      initialMuteOriginal: initialMuteOriginal,
    );
    if (edited == null || edited.files.isEmpty || !context.mounted) return;

    final postFiles = composerFiles(edited);
    final extra = {
      'files': postFiles,
      'type': composerType(edited),
      'isStory': isStory,
      'initialSound': edited.sound ?? initialSound,
      'initialSoundOffset': edited.soundOffset,
      'initialSoundWindow': edited.soundWindow,
      'initialSoundDidTrim': edited.soundDidTrim,
      'initialSoundSegmentId': edited.soundSegmentId,
      if (edited.filterName != null) 'filterName': edited.filterName,
      'filterCategory': edited.filterCategory.name,
      if (edited.effectSlug != null) 'effectSlug': edited.effectSlug,
      'beautyEnabled': edited.beautyEnabled,
      if (edited.videoTemplateId != null)
        'videoTemplateId': edited.videoTemplateId,
      if (edited.videoTemplateName != null)
        'videoTemplateName': edited.videoTemplateName,
      if (edited.videoTemplateSlotCount != null)
        'videoTemplateSlotCount': edited.videoTemplateSlotCount,
      if (edited.templateProjectId != null)
        'templateProjectId': edited.templateProjectId,
      if (edited.templateRenderedVideo != null)
        'templateRenderedVideo': edited.templateRenderedVideo,
      if (edited.templateSlotFiles != null &&
          edited.templateSlotFiles!.isNotEmpty)
        'templateSlotFiles': edited.templateSlotFiles,
      if (edited.templateServerExportUrl != null)
        'templateServerExportUrl': edited.templateServerExportUrl,
      if (edited.templateClientExportQuality != null)
        'templateClientExportQuality': edited.templateClientExportQuality,
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
