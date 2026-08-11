import 'dart:io';

import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_file.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/timeline/timeline_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_export_native.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_preview_look.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/video_template_client_renderer.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/material.dart';

/// Native OpenGL ES texture preview (Android) — same composer as export.
class TemplateGpuPreviewController extends ChangeNotifier {
  TemplateGpuPreviewController();

  TemplateGpuPreviewSession? _session;
  bool _disposed = false;
  bool _playing = false;
  List<String> _sourcePaths = const [];

  int? get textureId => _session?.textureId;
  int get width => _session?.width ?? 540;
  int get height => _session?.height ?? 960;
  int get durationMs => _session?.durationMs ?? 0;
  bool get isReady => _session != null;
  bool get isPlaying => _playing;

  static bool _samePaths(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Opens or swaps GPU preview for [recipe] + [localFiles].
  ///
  /// When sources are unchanged, reuses the native texture via [setRecipe]
  /// (Template A→B→C without destroy/recreate).
  Future<bool> open({
    required VideoTemplateRecipeEntity recipe,
    required List<File> localFiles,
    List<bool>? isVideoHints,
    TemplateClientExportQuality quality = TemplateClientExportQuality.preview,
  }) async {
    if (!TemplateExportNative.supported || localFiles.isEmpty) return false;

    final paths =
        localFiles.map((f) => f.absolute.path).toList(growable: false);
    final canSwap = _session != null && _samePaths(paths, _sourcePaths);

    final args = await TemplateGpuTimelineBuilder.build(
      recipe: recipe,
      localFiles: localFiles,
      isVideoHints: isVideoHints,
      quality: quality,
    );
    if (args == null) return false;

    if (canSwap) {
      await TemplateExportNative.setRecipe(
        width: args.width,
        height: args.height,
        fps: args.fps,
        bitrate: args.bitrate,
        clips: args.clips,
        audio: args.audio,
        colorMatrix: args.colorMatrix,
        overlays: args.overlays,
      );
      if (_disposed) return false;
      await TemplateExportNative.seek(0);
      await TemplateExportNative.play();
      _playing = true;
      notifyListeners();
      return true;
    }

    await disposeSession();

    final session = await TemplateExportNative.openPreview(
      width: args.width,
      height: args.height,
      fps: args.fps,
      bitrate: args.bitrate,
      clips: args.clips,
      audio: args.audio,
      colorMatrix: args.colorMatrix,
      overlays: args.overlays,
    );
    if (_disposed) {
      await TemplateExportNative.disposePreview();
      return false;
    }
    if (session == null) return false;
    _session = session;
    _sourcePaths = paths;
    notifyListeners();
    await TemplateExportNative.play();
    _playing = true;
    notifyListeners();
    return true;
  }

  Future<void> play() async {
    await TemplateExportNative.play();
    _playing = true;
    notifyListeners();
  }

  Future<void> pause() async {
    await TemplateExportNative.pause();
    _playing = false;
    notifyListeners();
  }

  Future<void> seekMs(int ms) async {
    await TemplateExportNative.seek(ms);
  }

  /// Export using the open session (WYSIWYG path). Soft select does not call this.
  Future<File?> export({String quality = 'draft'}) {
    return TemplateExportNative.exportSession(quality: quality);
  }

  Future<void> disposeSession() async {
    _playing = false;
    _session = null;
    _sourcePaths = const [];
    await TemplateExportNative.disposePreview();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    disposeSession();
    super.dispose();
  }
}

/// Renders the native GPU texture when [controller] is ready.
class TemplateGpuPreview extends StatelessWidget {
  const TemplateGpuPreview({
    super.key,
    required this.controller,
    this.fit = BoxFit.cover,
  });

  final TemplateGpuPreviewController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final id = controller.textureId;
        if (id == null) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          );
        }
        return FittedBox(
          fit: fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.width.toDouble(),
            height: controller.height.toDouble(),
            child: Texture(textureId: id),
          ),
        );
      },
    );
  }
}

/// Builds native timeline args from recipe + files (shared by preview/export).
class TemplateGpuTimelineBuilder {
  TemplateGpuTimelineBuilder._();

  static Future<GpuTimelineArgs?> build({
    required VideoTemplateRecipeEntity recipe,
    required List<File> localFiles,
    List<bool>? isVideoHints,
    TemplateClientExportQuality quality = TemplateClientExportQuality.draft,
  }) async {
    if (localFiles.isEmpty) return null;
    final slotEngine = SlotEngine(recipe: recipe);
    final fills = slotEngine.applyBeatSyncTrims(
      slotEngine.fillsFromFiles(localFiles, isVideoHints: isVideoHints),
    );
    final timeline = const TimelineEngine().build(recipe: recipe, fills: fills);
    final size = quality.outputSize(
      recipeWidth: recipe.width,
      recipeHeight: recipe.height,
    );
    final fps = quality.outputFps(recipe.fps).round();

    final mediaItems = timeline.items
        .where(
          (i) =>
              i.kind == TimelineLayerKind.imageClip ||
              i.kind == TimelineLayerKind.videoClip,
        )
        .toList(growable: false)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final clips = <TemplateExportNativeClip>[];
    final slots = slotEngine.slots;

    if (mediaItems.isNotEmpty) {
      for (final item in mediaItems) {
        final slotId = item.slotId;
        if (slotId == null) continue;
        VideoTemplateSlotEntity? slot;
        for (final s in slots) {
          if (s.id == slotId) {
            slot = s;
            break;
          }
        }
        if (slot == null) continue;
        final fill = fills[slotId];
        final file = fill?.localFile;
        if (fill == null || file == null || !await file.exists()) continue;
        final durationMs = (item.duration * 1000).round().clamp(200, 60000);
        final isImage = !fill.isLocalVideo &&
            (item.kind == TimelineLayerKind.imageClip ||
                !VideoThumbnailUtils.isVideoFile(file));
        if (isImage) {
          clips.add(
            TemplateExportNativeClip(
              type: 'image',
              path: file.path,
              durationMs: durationMs,
            ),
          );
        } else {
          final startSec = fill.trimStart ?? 0;
          final endSec = fill.trimEnd ?? (startSec + durationMs / 1000.0);
          clips.add(
            TemplateExportNativeClip(
              type: 'video',
              path: file.path,
              durationMs: durationMs,
              trimStartMs: (startSec * 1000).round().clamp(0, 3600000),
              trimEndMs: (endSec * 1000).round(),
              volume: fill.volume.clamp(0.0, 1.0),
            ),
          );
        }
      }
    }

    if (clips.isEmpty) {
      for (var i = 0; i < slots.length && localFiles.isNotEmpty; i++) {
        final file = localFiles[i % localFiles.length];
        if (!await file.exists()) continue;
        final slot = slots[i];
        final holdMs = ((slot.resolvedDurationSeconds > 0
                    ? slot.resolvedDurationSeconds
                    : 2.0) *
                1000)
            .round()
            .clamp(200, 60000);
        final hinted = isVideoHints != null &&
            localFiles.isNotEmpty &&
            isVideoHints[i % localFiles.length];
        final isImage = !(hinted || VideoThumbnailUtils.isVideoFile(file));
        clips.add(
          TemplateExportNativeClip(
            type: isImage ? 'image' : 'video',
            path: file.path,
            durationMs: holdMs,
          ),
        );
      }
    }
    if (clips.isEmpty) return null;

    TemplateExportNativeAudio? audio;
    final sound = recipe.effectivePreviewSound;
    if (sound != null) {
      try {
        final audioFile = await SoundLocalFile.resolve(sound.resolvedAudioUrl);
        if (audioFile != null && await audioFile.exists()) {
          audio = TemplateExportNativeAudio(
            path: audioFile.path,
            startMs: (recipe.soundSegmentStartMs ?? 0).clamp(0, 3600000),
            endMs: recipe.soundSegmentEndMs,
          );
        }
      } catch (e, st) {
        debugPrint('GPU timeline audio: $e\n$st');
      }
    }

    return GpuTimelineArgs(
      width: size.width.round(),
      height: size.height.round(),
      fps: fps,
      bitrate: quality.bitrate,
      clips: clips,
      audio: audio,
      colorMatrix: _colorMatrixForRecipe(recipe),
      overlays: _stickerOverlays(recipe),
    );
  }

  static List<double>? _colorMatrixForRecipe(VideoTemplateRecipeEntity recipe) {
    TemplateFilterEntity? first;
    for (final slot in recipe.slots) {
      if (slot.filters.isNotEmpty) {
        first = slot.filters.first;
        break;
      }
    }
    for (final clip in recipe.clips) {
      if (first != null) break;
      if (clip.filters.isNotEmpty) {
        first = clip.filters.first;
        break;
      }
    }
    if (first == null) return null;
    final name = first.filterName.trim();
    if (name.isEmpty || name.toLowerCase() == 'none') return null;
    final matrix = TemplateFilterMatrices.forName(
      name,
      intensity: first.intensity,
    );
    if (identical(matrix, TemplateFilterMatrices.identity)) return null;
    if (matrix.length < 20) return null;
    return matrix.take(20).toList(growable: false);
  }

  /// Stickers/overlays with resolvable local asset paths (Phase C).
  static List<TemplateExportNativeOverlay> _stickerOverlays(
    VideoTemplateRecipeEntity recipe,
  ) {
    final out = <TemplateExportNativeOverlay>[];
    for (final sticker in recipe.stickers) {
      final url = sticker.assetUrl?.trim();
      if (url == null || url.isEmpty || !url.startsWith('/')) continue;
      if (!File(url).existsSync()) continue;
      out.add(
        TemplateExportNativeOverlay(
          path: url,
          startMs: (sticker.startTime * 1000).round(),
          endMs: sticker.endTime > 0
              ? (sticker.endTime * 1000).round()
              : null,
          opacity: sticker.opacity.clamp(0.0, 1.0),
        ),
      );
    }
    for (final overlay in recipe.overlays) {
      final url = overlay.assetUrl?.trim();
      if (url == null || url.isEmpty || !url.startsWith('/')) continue;
      if (!File(url).existsSync()) continue;
      out.add(
        TemplateExportNativeOverlay(
          path: url,
          startMs: (overlay.startTime * 1000).round(),
          endMs: overlay.endTime > 0
              ? (overlay.endTime * 1000).round()
              : null,
          opacity: overlay.opacity.clamp(0.0, 1.0),
        ),
      );
    }
    return out;
  }
}

class GpuTimelineArgs {
  const GpuTimelineArgs({
    required this.width,
    required this.height,
    required this.fps,
    required this.bitrate,
    required this.clips,
    this.audio,
    this.colorMatrix,
    this.overlays = const [],
  });

  final int width;
  final int height;
  final int fps;
  final int bitrate;
  final List<TemplateExportNativeClip> clips;
  final TemplateExportNativeAudio? audio;
  final List<double>? colorMatrix;
  final List<TemplateExportNativeOverlay> overlays;
}
