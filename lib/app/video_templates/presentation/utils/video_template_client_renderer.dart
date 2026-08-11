import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_file.dart';
import 'package:bimobondapp/app/video_templates/composition/image_media_source.dart';
import 'package:bimobondapp/app/video_templates/composition/media_source.dart';
import 'package:bimobondapp/app/video_templates/composition/video_media_source.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/timeline/timeline_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_export_native.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_look_baker.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/template_gpu_preview.dart';
import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// On-device encode quality. `draft` = fast Next; `standard` = publish.
class TemplateClientExportQuality {
  const TemplateClientExportQuality._({
    required this.id,
    required this.maxLongEdge,
    required this.bitrate,
    required this.maxFps,
    required this.applyVideoColorGrade,
  });

  static const draft = TemplateClientExportQuality._(
    id: 'draft',
    maxLongEdge: 720,
    bitrate: 5 * 1000 * 1000,
    maxFps: 24,
    applyVideoColorGrade: false,
  );

  /// Soft editor preview — long edge 960 → 540×960 on a 9:16 recipe canvas.
  static const preview = TemplateClientExportQuality._(
    id: 'preview',
    maxLongEdge: 960,
    bitrate: 3 * 1000 * 1000,
    maxFps: 30,
    applyVideoColorGrade: false,
  );

  static const standard = TemplateClientExportQuality._(
    id: 'standard',
    maxLongEdge: 1080,
    bitrate: 12 * 1000 * 1000,
    maxFps: 60,
    applyVideoColorGrade: true,
  );

  final String id;
  final int maxLongEdge;
  final int bitrate;
  final int maxFps;
  final bool applyVideoColorGrade;

  bool get isDraft => id == draft.id;
  bool get isPreview => id == preview.id;
  bool get isStandard => id == standard.id;

  static TemplateClientExportQuality parse(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == draft.id) return draft;
    if (s == preview.id) return preview;
    return standard;
  }

  ui.Size outputSize({
    required int recipeWidth,
    required int recipeHeight,
  }) {
    final w = (recipeWidth > 0 ? recipeWidth : 1080).toDouble();
    final h = (recipeHeight > 0 ? recipeHeight : 1920).toDouble();
    final longEdge = math.max(w, h);
    final scale = longEdge > maxLongEdge ? maxLongEdge / longEdge : 1.0;
    return ui.Size(_even(w * scale), _even(h * scale));
  }

  double outputFps(num recipeFps) {
    final base = (recipeFps > 0 ? recipeFps : 30).toDouble();
    return base.clamp(15, maxFps).toDouble();
  }

  static double _even(double v) {
    final n = v.round();
    return (n.isEven ? n : n + 1).toDouble();
  }
}

/// Client-side template composition → single MP4 (timeline path).
///
/// IMAGE slots are [ImageMediaSource] holds on the same timeline as VIDEO —
/// not a separate ImageTemplateEngine. Export:
/// ```
/// MediaSource (image texture / video decode)
/// → timeline (crop/scale/filter/effect/overlay)
/// → Android: Media3 Transformer / MediaCodec (native channel)
/// → iOS / fallback: ProVideoEditor hardware encoder
/// → MP4
/// ```
///
/// Images are **never** turned into a temporary MP4 and then re-processed.
/// One still → one [StopMotionFrame] with [StopMotionFrame.duration]; the
/// encoder emits N frames at [recipe.fps] from that texture.
class VideoTemplateClientRenderer {
  VideoTemplateClientRenderer._();

  static Future<File?> render({
    required VideoTemplateRecipeEntity recipe,
    required List<File> localFiles,
    TemplateClientExportQuality quality = TemplateClientExportQuality.standard,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb || localFiles.isEmpty) return null;

    final count = recipe.applySlotCount;
    if (count <= 0) return null;

    final engine = SlotEngine(recipe: recipe);
    final fills = engine.applyBeatSyncTrims(engine.fillsFromFiles(localFiles));
    return renderComposition(
      recipe: recipe,
      fills: fills,
      quality: quality,
      onProgress: onProgress,
    );
  }

  /// Mixed IMAGE + VIDEO composition from the shared timeline.
  static Future<File?> renderComposition({
    required VideoTemplateRecipeEntity recipe,
    required Map<String, SlotFillEntry> fills,
    Map<String, MediaSource>? sources,
    TemplateTimeline? timeline,
    TemplateClientExportQuality quality = TemplateClientExportQuality.standard,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) return null;

    final slotEngine = SlotEngine(recipe: recipe);
    final slots = slotEngine.slots;
    if (slots.isEmpty) return null;

    final resolvedTimeline =
        timeline ?? const TimelineEngine().build(recipe: recipe, fills: fills);

    onProgress?.call(0.05);

    try {
      final clips = await _buildTimelineClips(
        recipe: recipe,
        slots: slots,
        fills: fills,
        sources: sources,
        timeline: resolvedTimeline,
      );
      if (clips.isEmpty) return null;
      onProgress?.call(0.35);

      // Android: one-pass native Media3 / MediaCodec (includes template audio).
      final native = await _encodeTimelineNative(
        recipe: recipe,
        clips: clips,
        quality: quality,
      );
      if (native != null && await native.exists()) {
        onProgress?.call(0.95);
        debugPrint(
          'Template export: native Media3 path (${quality.id})',
        );
        if (!quality.applyVideoColorGrade) return native;
        return TemplateLookBaker.bakeVideoColorGrade(
          input: native,
          recipe: recipe,
        );
      }

      // iOS / native failure → ProVideoEditor multi-pass.
      final silent = await _encodeTimeline(
        recipe: recipe,
        clips: clips,
        quality: quality,
      );
      onProgress?.call(0.75);
      if (silent == null || !await silent.exists()) return null;

      final withAudio = await _muxTemplateAudio(recipe, silent);
      onProgress?.call(0.95);
      final composed = withAudio ?? silent;
      if (!quality.applyVideoColorGrade) return composed;
      return TemplateLookBaker.bakeVideoColorGrade(
        input: composed,
        recipe: recipe,
      );
    } catch (e, st) {
      debugPrint('renderComposition failed: $e\n$st');
      return null;
    }
  }

  /// Android GPU composer (OpenGL → MediaCodec), Media3 fallback inside plugin.
  static Future<File?> _encodeTimelineNative({
    required VideoTemplateRecipeEntity recipe,
    required List<_TimelineClip> clips,
    required TemplateClientExportQuality quality,
  }) async {
    if (!TemplateExportNative.supported) return null;
    final files = <File>[];
    for (final clip in clips) {
      final f = clip.source.file;
      if (await f.exists()) files.add(f);
    }
    if (files.isEmpty) return null;

    final args = await TemplateGpuTimelineBuilder.build(
      recipe: recipe,
      localFiles: files,
      quality: quality,
    );
    if (args == null) return null;

    return TemplateExportNative.composeTimeline(
      width: args.width,
      height: args.height,
      fps: args.fps,
      bitrate: args.bitrate,
      clips: args.clips,
      audio: args.audio,
      colorMatrix: args.colorMatrix,
      overlays: args.overlays,
    );
  }

  static Future<List<_TimelineClip>> _buildTimelineClips({
    required VideoTemplateRecipeEntity recipe,
    required List<VideoTemplateSlotEntity> slots,
    required Map<String, SlotFillEntry> fills,
    required Map<String, MediaSource>? sources,
    required TemplateTimeline timeline,
  }) async {
    final mediaItems =
        timeline.items
            .where(
              (i) =>
                  i.kind == TimelineLayerKind.imageClip ||
                  i.kind == TimelineLayerKind.videoClip,
            )
            .toList(growable: false)
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final clips = <_TimelineClip>[];
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

      var source = sources?[slotId];
      if (source == null) {
        source = MediaSource.fromFill(slot: slot, fill: fill, file: file);
        try {
          await source.prepare();
        } catch (e, st) {
          debugPrint('Timeline source prepare $slotId: $e\n$st');
        }
      } else if (!source.isPrepared) {
        try {
          await source.prepare();
        } catch (_) {}
      }

      final hold = Duration(
        milliseconds: (item.duration * 1000).round().clamp(200, 30000),
      );
      final isImage =
          item.kind == TimelineLayerKind.imageClip ||
          source.kind == MediaSourceKinds.image ||
          !VideoThumbnailUtils.isVideoFile(source.file);

      clips.add(
        _TimelineClip(
          slot: slot,
          fill: fill,
          source: source,
          duration: hold,
          isImage: isImage,
        ),
      );
    }

    // Fallback when timeline has no media items yet (empty paths).
    if (clips.isEmpty) {
      for (final slot in slots) {
        final fill = fills[slot.id];
        final file = fill?.localFile;
        if (fill == null || file == null || !await file.exists()) continue;
        final source =
            sources?[slot.id] ??
            MediaSource.fromFill(slot: slot, fill: fill, file: file);
        if (!source.isPrepared) {
          try {
            await source.prepare();
          } catch (_) {}
        }
        final hold = await source.getDuration();
        clips.add(
          _TimelineClip(
            slot: slot,
            fill: fill,
            source: source,
            duration: hold,
            isImage:
                source.kind == MediaSourceKinds.image ||
                !VideoThumbnailUtils.isVideoFile(source.file),
          ),
        );
      }
    }
    return clips;
  }

  /// Encode the timeline in one hardware pass when possible.
  static Future<File?> _encodeTimeline({
    required VideoTemplateRecipeEntity recipe,
    required List<_TimelineClip> clips,
    required TemplateClientExportQuality quality,
  }) async {
    final allImages = clips.every((c) => c.isImage);
    if (allImages) {
      return _encodeImageTimeline(
        recipe: recipe,
        clips: clips,
        quality: quality,
      );
    }

    // Mixed / video: image holds use Media3 image-duration encode (one texture
    // → hold → MP4 segment). Video uses trim. Segments are then concat once.
    // Image segments are NOT re-opened for a second filter pass.
    final prepared = <File>[];
    for (final clip in clips) {
      final file = clip.isImage
          ? await _encodeImageHoldClip(
              recipe: recipe,
              clip: clip,
              quality: quality,
            )
          : await _encodeVideoClip(clip: clip, quality: quality);
      if (file != null) prepared.add(file);
    }
    if (prepared.isEmpty) return null;
    if (prepared.length == 1) return prepared.first;
    return _stitchClips(recipe: recipe, clips: prepared, quality: quality);
  }

  /// All-image timeline: one stop-motion encode.
  /// Each slot = one [StopMotionFrame] with hold duration (not N JPEG copies).
  static Future<File?> _encodeImageTimeline({
    required VideoTemplateRecipeEntity recipe,
    required List<_TimelineClip> clips,
    required TemplateClientExportQuality quality,
  }) async {
    final frames = <StopMotionFrame>[];
    final allFiles = clips.map((c) => c.source.file).toList(growable: false);

    for (final clip in clips) {
      final texture = await _imageTextureBytes(
        recipe: recipe,
        clip: clip,
        allSources: allFiles,
      );
      if (texture == null || texture.isEmpty) {
        debugPrint('Image texture missing for slot ${clip.slot.id}');
        return null;
      }
      frames.add(
        StopMotionFrame(
          image: EditorLayerImage.memory(texture),
          duration: clip.duration,
        ),
      );
    }
    if (frames.isEmpty) return null;

    final fps = quality.outputFps(recipe.fps);
    final size = quality.outputSize(
      recipeWidth: recipe.width,
      recipeHeight: recipe.height,
    );
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/tpl_img_tl_${quality.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final resultPath = await ProVideoEditor.instance.renderStopMotionToFile(
        outPath,
        StopMotionRenderData(
          frames: frames,
          frameRate: fps,
          resolution: size,
          fit: StopMotionFit.cover,
          outputFormat: VideoOutputFormat.mp4,
          bitrate: quality.bitrate,
        ),
      );
      final out = File(resultPath);
      if (!await out.exists() || await out.length() == 0) return null;
      return out;
    } catch (e, st) {
      debugPrint('Image timeline encode failed: $e\n$st');
      return null;
    }
  }

  /// Single image hold → Media3 image MediaItem with duration (not img→vid→edit).
  static Future<File?> _encodeImageHoldClip({
    required VideoTemplateRecipeEntity recipe,
    required _TimelineClip clip,
    required TemplateClientExportQuality quality,
  }) async {
    final texture = await _imageTextureBytes(
      recipe: recipe,
      clip: clip,
      allSources: [clip.source.file],
    );
    if (texture == null || texture.isEmpty) return null;

    final fps = quality.outputFps(recipe.fps);
    final size = quality.outputSize(
      recipeWidth: recipe.width,
      recipeHeight: recipe.height,
    );
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/tpl_img_hold_${quality.id}_${clip.slot.slotIndex}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final resultPath = await ProVideoEditor.instance.renderStopMotionToFile(
        outPath,
        StopMotionRenderData(
          frames: [
            StopMotionFrame(
              image: EditorLayerImage.memory(texture),
              duration: clip.duration,
            ),
          ],
          frameRate: fps,
          resolution: size,
          fit: StopMotionFit.cover,
          outputFormat: VideoOutputFormat.mp4,
          bitrate: quality.bitrate,
        ),
      );
      final out = File(resultPath);
      if (!await out.exists() || await out.length() == 0) return null;
      return out;
    } catch (e, st) {
      debugPrint('Image hold encode failed: $e\n$st');
      return null;
    }
  }

  /// Bake look layers onto the still **once** (texture), then encoder holds it.
  static Future<Uint8List?> _imageTextureBytes({
    required VideoTemplateRecipeEntity recipe,
    required _TimelineClip clip,
    required List<File> allSources,
  }) async {
    // Prefer look-baked still (filters/text/stickers) — still a single texture.
    final looked = await TemplateLookBaker.bakeImageFile(
      input: clip.source.file,
      recipe: recipe,
      slot: clip.slot,
      allSources: allSources,
    );
    if (looked != null && await looked.exists()) {
      return looked.readAsBytes();
    }
    final imageSource = clip.source;
    if (imageSource is ImageMediaSource && imageSource.imageBytes != null) {
      return imageSource.imageBytes;
    }
    try {
      return await clip.source.file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<File?> _encodeVideoClip({
    required _TimelineClip clip,
    required TemplateClientExportQuality quality,
  }) async {
    final video = clip.source is VideoMediaSource
        ? clip.source as VideoMediaSource
        : null;
    final fill = clip.fill;
    final startSec = video?.sourceTrimStartSeconds ?? (fill.trimStart ?? 0);
    final endSec =
        video?.sourceTrimEndSeconds ??
        (fill.trimEnd ??
            (startSec +
                (clip.duration.inMilliseconds / 1000.0).clamp(0.2, 30)));

    final start = Duration(milliseconds: (startSec * 1000).round());
    final end = Duration(milliseconds: (endSec * 1000).round());
    if (end <= start) return clip.source.file;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/tpl_vid_${quality.id}_${clip.slot.slotIndex}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    try {
      final resultPath = await ProVideoEditor.instance.renderVideoToFile(
        outPath,
        VideoRenderData(
          qualityConfig: VideoQualityConfig.custom(bitrate: quality.bitrate),
          bitrate: quality.bitrate,
          shouldOptimizeForNetworkUse: true,
          videoSegments: [
            VideoSegment(
              video: EditorVideo.file(clip.source.file),
              startTime: start,
              endTime: end,
              volume: fill.volume.clamp(0.0, 1.0),
              playbackSpeed: fill.speed > 0 ? fill.speed : null,
            ),
          ],
          outputFormat: VideoOutputFormat.mp4,
          enableAudio: true,
        ),
      );
      final out = File(resultPath);
      if (await out.exists() && await out.length() > 0) return out;
    } catch (e, st) {
      debugPrint('Video clip encode: $e\n$st');
    }
    return clip.source.file;
  }

  static Future<File?> _stitchClips({
    required VideoTemplateRecipeEntity recipe,
    required List<File> clips,
    required TemplateClientExportQuality quality,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/tpl_stitch_${quality.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final size = quality.outputSize(
      recipeWidth: recipe.width,
      recipeHeight: recipe.height,
    );

    try {
      final segments = clips
          .map((f) => VideoSegment(video: EditorVideo.file(f), volume: 0))
          .toList(growable: false);

      final resultPath = await ProVideoEditor.instance.renderVideoToFile(
        outPath,
        VideoRenderData(
          qualityConfig: VideoQualityConfig.custom(bitrate: quality.bitrate),
          bitrate: quality.bitrate,
          shouldOptimizeForNetworkUse: true,
          videoSegments: segments,
          outputFormat: VideoOutputFormat.mp4,
          enableAudio: true,
          transform: ExportTransform(
            width: size.width.round(),
            height: size.height.round(),
          ),
        ),
      );
      final out = File(resultPath);
      if (await out.exists() && await out.length() > 0) return out;
    } catch (e, st) {
      debugPrint('Multi-clip stitch failed: $e\n$st');
    }
    return clips.first;
  }

  static Future<File?> _muxTemplateAudio(
    VideoTemplateRecipeEntity recipe,
    File silent,
  ) async {
    final sound = recipe.sound;
    if (sound == null) return silent;
    try {
      final audio = await SoundLocalFile.resolve(sound.resolvedAudioUrl);
      if (audio == null) return silent;

      final startMs = recipe.soundSegmentStartMs ?? 0;
      final endMs = recipe.soundSegmentEndMs;
      final start = Duration(milliseconds: startMs.clamp(0, 3600000));
      Duration? end;
      if (endMs != null && endMs > startMs) {
        end = Duration(milliseconds: endMs);
      }

      return await NativeVideoProcessor.muxAudioIntoVideo(
            silent,
            audio: audio,
            startOffset: start,
            audioEnd: end,
            musicVolume: 1,
            keepOriginalAudio: false,
          ) ??
          silent;
    } catch (e, st) {
      debugPrint('Template audio mux failed: $e\n$st');
      return silent;
    }
  }
}

class _TimelineClip {
  const _TimelineClip({
    required this.slot,
    required this.fill,
    required this.source,
    required this.duration,
    required this.isImage,
  });

  final VideoTemplateSlotEntity slot;
  final SlotFillEntry fill;
  final MediaSource source;
  final Duration duration;
  final bool isImage;
}
