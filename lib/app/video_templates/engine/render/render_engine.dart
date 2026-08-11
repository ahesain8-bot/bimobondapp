import 'dart:io';

import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_file.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/layers/layer_engines.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/timeline/timeline_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/video_template_client_renderer.dart';
import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Phase 6 — scrubbing / playhead query over a [TemplateTimeline].
///
/// Full GPU→Texture preview lands on the native RenderEngine path; this engine
/// exposes deterministic active layers for Flutter Texture hosts and scrub UI.
class PreviewEngine {
  PreviewEngine({
    required this.timeline,
    FilterEngine? filterEngine,
    EffectEngine? effectEngine,
    TransitionEngine? transitionEngine,
    KeyframeEngine? keyframeEngine,
    TextEngine? textEngine,
    StickerEngine? stickerEngine,
    OverlayEngine? overlayEngine,
    AudioEngine? audioEngine,
  })  : filterEngine = filterEngine ?? const FilterEngine(),
        effectEngine = effectEngine ?? const EffectEngine(),
        transitionEngine = transitionEngine ?? const TransitionEngine(),
        keyframeEngine = keyframeEngine ?? const KeyframeEngine(),
        textEngine = textEngine ?? const TextEngine(),
        stickerEngine = stickerEngine ?? const StickerEngine(),
        overlayEngine = overlayEngine ?? const OverlayEngine(),
        audioEngine = audioEngine ?? const AudioEngine();

  final TemplateTimeline timeline;
  final FilterEngine filterEngine;
  final EffectEngine effectEngine;
  final TransitionEngine transitionEngine;
  final KeyframeEngine keyframeEngine;
  final TextEngine textEngine;
  final StickerEngine stickerEngine;
  final OverlayEngine overlayEngine;
  final AudioEngine audioEngine;

  double _playhead = 0;

  double get playhead => _playhead;

  double get duration => timeline.totalDuration;

  void seek(double seconds) {
    _playhead = seconds.clamp(0.0, timeline.totalDuration);
  }

  /// Prepare only media intersecting [window] around the playhead (perf).
  List<TimelineItem> windowedItems({double lookBehind = 1.5, double lookAhead = 3}) {
    final from = (_playhead - lookBehind).clamp(0.0, timeline.totalDuration);
    final to = (_playhead + lookAhead).clamp(0.0, timeline.totalDuration);
    return timeline.intersecting(from, to);
  }

  PreviewFrame sample([double? at]) {
    final t = (at ?? _playhead).clamp(0.0, timeline.totalDuration);
    final media = timeline
        .activeAt(t)
        .where(
          (i) =>
              i.kind == TimelineLayerKind.videoClip ||
              i.kind == TimelineLayerKind.imageClip,
        )
        .where((i) => i.userMediaPath != null || i.assetUrl != null)
        .toList();

    final transforms = <String, TransformSample>{};
    for (final m in media) {
      transforms[m.id] = keyframeEngine.sampleTransform(item: m, time: t);
    }

    return PreviewFrame(
      time: t,
      media: media,
      transforms: transforms,
      filters: filterEngine
          .filtersAt(timeline, t)
          .map(filterEngine.resolve)
          .whereType<ResolvedFilter>()
          .toList(growable: false),
      effects: effectEngine.activeEffects(timeline, t),
      transitions: transitionEngine.activeAt(timeline, t),
      texts: textEngine.textsAt(timeline, t),
      stickers: stickerEngine.stickersAt(timeline, t),
      overlays: overlayEngine.overlaysAt(timeline, t),
      audio: audioEngine.plan(timeline),
    );
  }
}

class PreviewFrame {
  const PreviewFrame({
    required this.time,
    required this.media,
    required this.transforms,
    required this.filters,
    required this.effects,
    required this.transitions,
    required this.texts,
    required this.stickers,
    required this.overlays,
    required this.audio,
  });

  final double time;
  final List<TimelineItem> media;
  final Map<String, TransformSample> transforms;
  final List<ResolvedFilter> filters;
  final List<ResolvedEffect> effects;
  final List<ResolvedTransition> transitions;
  final List<TimelineItem> texts;
  final List<TimelineItem> stickers;
  final List<TimelineItem> overlays;
  final AudioPlan audio;
}

/// Phase 14–15 — sequential export to MP4 (1080×1920 H.264 target).
///
/// Delegates to [VideoTemplateClientRenderer.renderComposition] so IMAGE and
/// VIDEO slots share one encode path (held stills + trimmed clips → stitch →
/// template audio). Layer descriptors stay on the plan for GPU FX upgrades.
class RenderEngine {
  const RenderEngine();

  Future<TemplateRenderPlan> plan({
    required VideoTemplateRecipeEntity recipe,
    required Map<String, SlotFillEntry> fills,
    TemplateTimeline? timeline,
  }) async {
    final built = timeline ??
        const TimelineEngine().build(recipe: recipe, fills: fills);
    return TemplateRenderPlan(
      timeline: built,
      recipe: recipe,
      fills: fills,
      targetWidth: built.width,
      targetHeight: built.height,
      targetFps: built.fps.clamp(15, 60),
    );
  }

  /// Hardware-friendly sequential export. Does not screenshot Flutter widgets.
  Future<File?> export(
    TemplateRenderPlan plan, {
    TemplateClientExportQuality quality = TemplateClientExportQuality.standard,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) return null;
    onProgress?.call(0.05);

    final hasMedia = plan.fills.values.any(
      (f) => f.localFile != null && f.localFile!.path.isNotEmpty,
    );
    if (!hasMedia) return null;
    onProgress?.call(0.1);

    final silent = await VideoTemplateClientRenderer.renderComposition(
      recipe: plan.recipe,
      fills: plan.fills,
      quality: quality,
      onProgress: (p) => onProgress?.call(0.1 + p * 0.6),
    );
    onProgress?.call(0.75);
    if (silent == null || !await silent.exists()) return null;

    File out = silent;
    final audio = const AudioEngine().plan(plan.timeline);
    if (audio.hasAudio && plan.recipe.sound == null && plan.recipe.music != null) {
      try {
        final local = await SoundLocalFile.resolve(audio.audioUrl!);
        if (local != null) {
          final muxed = await NativeVideoProcessor.muxAudioIntoVideo(
            silent,
            audio: local,
            startOffset: Duration(milliseconds: audio.startMs),
            audioEnd: audio.endMs != null
                ? Duration(milliseconds: audio.endMs!)
                : null,
            musicVolume: 1,
            keepOriginalAudio: false,
          );
          if (muxed != null) out = muxed;
        }
      } catch (e, st) {
        debugPrint('RenderEngine audio mux: $e\n$st');
      }
    }

    onProgress?.call(0.9);

    try {
      final dir = await getTemporaryDirectory();
      final dest = File(
        '${dir.path}/tpl_engine_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      if (out.path != dest.path) {
        await out.copy(dest.path);
        out = dest;
      }
    } catch (_) {}

    onProgress?.call(1);
    return out;
  }
}

class TemplateRenderPlan {
  const TemplateRenderPlan({
    required this.timeline,
    required this.recipe,
    required this.fills,
    required this.targetWidth,
    required this.targetHeight,
    required this.targetFps,
  });

  final TemplateTimeline timeline;
  final VideoTemplateRecipeEntity recipe;
  final Map<String, SlotFillEntry> fills;
  final int targetWidth;
  final int targetHeight;
  final double targetFps;
}
