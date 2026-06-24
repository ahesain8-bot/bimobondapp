import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Deletes intermediate files produced by the camera studio pipeline.
class MediaTempUtils {
  MediaTempUtils._();

  static bool isPipelineArtifact(String path) {
    final name = path.split(RegExp(r'[/\\]')).last.toLowerCase();
    return name.startsWith('filter_') ||
        name.startsWith('effect_') ||
        name.startsWith('overlay_') ||
        name.startsWith('story_export_') ||
        path.contains(r'\vf_') ||
        path.contains('/vf_');
  }

  static Future<void> deleteIfSafe(File? file) async {
    if (file == null || !isPipelineArtifact(file.path)) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<File> replaceKeepingOutput({
    required File input,
    required File output,
  }) async {
    if (input.path == output.path) return output;
    if (isPipelineArtifact(input.path)) {
      await deleteIfSafe(input);
    } else {
      await deleteReplacedOriginal(original: input, result: output);
    }
    return output;
  }

  /// Removes a camera/cache capture after it has been replaced by an export file.
  static Future<void> deleteReplacedOriginal({
    required File original,
    required File result,
  }) async {
    if (original.path == result.path) return;
    try {
      final tempDir = await getTemporaryDirectory();
      if (!original.path.startsWith(tempDir.path)) return;
      if (await original.exists()) await original.delete();
    } catch (_) {}
  }
}
