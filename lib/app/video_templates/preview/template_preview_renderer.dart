import 'dart:io';

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_export_native.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_preview_look.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';

/// Chooses soft-preview backend: native GPU texture vs Flutter compositor.
///
/// Export remains server-only on Next — this is preview only.
abstract final class TemplatePreviewRenderer {
  /// True when recipe uses collage layouts the GPU composer cannot draw yet.
  static bool recipeNeedsFlutterLayout(VideoTemplateRecipeEntity recipe) {
    final types = <String>[];
    for (final slot in recipe.slots) {
      for (final e in slot.effects) {
        final t = e.effectType.trim();
        if (t.isNotEmpty) types.add(t);
      }
    }
    for (final clip in recipe.clips) {
      for (final e in clip.effects) {
        final t = e.effectType.trim();
        if (t.isNotEmpty) types.add(t);
      }
    }
    return templateHasLayoutEffect(types);
  }

  /// Prefer GPU soft preview on Android when layouts are not required.
  static bool preferGpuSoftPreview({
    required VideoTemplateRecipeEntity recipe,
    required List<File> sources,
  }) {
    if (!TemplateExportNative.supported) return false;
    if (recipeNeedsFlutterLayout(recipe)) return false;
    // GPU video path uses metadata stills — prefer Flutter for video sources.
    final hasVideo = sources.any(VideoThumbnailUtils.isVideoFile);
    if (hasVideo) return false;
    return true;
  }
}
