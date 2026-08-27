import 'dart:io';

import 'package:bimobondapp/app/video_templates/composition/composition_errors.dart';
import 'package:bimobondapp/app/video_templates/composition/composition_session.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/template_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/video_template_client_renderer.dart';
import 'package:flutter/foundation.dart';

/// Single composition path for IMAGE + VIDEO + mixed slots (Phases 5–16).
///
/// Does **not** split into ImageTemplateEngine / VideoTemplateEngine.
/// Pipeline: Recipe → Session/MediaSource → Timeline → Layer engines → Export.
class TemplateCompositionEngine {
  TemplateCompositionEngine({
    TemplateEngine? templateEngine,
    TimelineEngine? timelineEngine,
    RenderEngine? renderEngine,
    FilterEngine? filterEngine,
    EffectEngine? effectEngine,
    TransitionEngine? transitionEngine,
    KeyframeEngine? keyframeEngine,
    TextEngine? textEngine,
    StickerEngine? stickerEngine,
    OverlayEngine? overlayEngine,
    AudioEngine? audioEngine,
  }) : templateEngine = templateEngine ?? TemplateEngine(),
       timelineEngine = timelineEngine ?? const TimelineEngine(),
       renderEngine = renderEngine ?? const RenderEngine(),
       filterEngine = filterEngine ?? const FilterEngine(),
       effectEngine = effectEngine ?? const EffectEngine(),
       transitionEngine = transitionEngine ?? const TransitionEngine(),
       keyframeEngine = keyframeEngine ?? const KeyframeEngine(),
       textEngine = textEngine ?? const TextEngine(),
       stickerEngine = stickerEngine ?? const StickerEngine(),
       overlayEngine = overlayEngine ?? const OverlayEngine(),
       audioEngine = audioEngine ?? const AudioEngine();

  final TemplateEngine templateEngine;
  final TimelineEngine timelineEngine;
  final RenderEngine renderEngine;
  final FilterEngine filterEngine;
  final EffectEngine effectEngine;
  final TransitionEngine transitionEngine;
  final KeyframeEngine keyframeEngine;
  final TextEngine textEngine;
  final StickerEngine stickerEngine;
  final OverlayEngine overlayEngine;
  final AudioEngine audioEngine;

  CompositionSession open(
    VideoTemplateRecipeEntity recipe, {
    String? projectId,
  }) {
    final slots = templateEngine.slotsFor(recipe);
    return CompositionSession(
      recipe: recipe,
      slotEngine: slots,
      projectId: projectId,
    );
  }

  TemplateTimeline buildTimeline(CompositionSession session) {
    return timelineEngine.build(
      recipe: session.recipe,
      fills: session.fills,
      userFilters: session.userFilters,
      userEffects: session.userEffects,
      userTexts: session.userTexts,
      userStickers: session.userStickers,
      userAudios: session.userAudios,
      userAudioTiming: session.userAudioTiming,
      userSound: session.userSoundCleared ? null : session.userSound,
      clearRecipeSound: session.userSoundCleared,
      userSoundSegmentStartMs: session.userSoundSegmentStartMs,
      userSoundSegmentEndMs: session.userSoundSegmentEndMs,
    );
  }

  PreviewEngine preview(CompositionSession session) {
    final timeline = buildTimeline(session);
    return PreviewEngine(
      timeline: timeline,
      filterEngine: filterEngine,
      effectEngine: effectEngine,
      transitionEngine: transitionEngine,
      keyframeEngine: keyframeEngine,
      textEngine: textEngine,
      stickerEngine: stickerEngine,
      overlayEngine: overlayEngine,
      audioEngine: audioEngine,
    );
  }

  /// Sample active layers at [time] (filters / effects / transitions / overlays).
  PreviewFrame sample(CompositionSession session, double time) {
    final engine = preview(session);
    engine.seek(time);
    return engine.sample(time);
  }

  Future<CompositionResult<File>> export(
    CompositionSession session, {
    TemplateClientExportQuality quality = TemplateClientExportQuality.standard,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final report = session.validate();
      if (!report.canExport) {
        return CompositionResult.fail(
          CompositionException(
            report.firstError ?? 'Cannot export template',
            code: CompositionErrorCode.invalidTemplate,
            technicalDetail: report.errors.join('; '),
          ),
        );
      }

      await session.prepareSources();
      onProgress?.call(0.08);

      final timeline = buildTimeline(session);
      final file = await VideoTemplateClientRenderer.renderComposition(
        recipe: session.recipe,
        fills: session.fills,
        sources: session.sources,
        timeline: timeline,
        quality: quality,
        onProgress: (p) => onProgress?.call(0.1 + p * 0.85),
      );

      if (file == null || !await file.exists()) {
        return CompositionResult.fail(
          CompositionException(
            'Export failed — try different media or free up storage',
            code: CompositionErrorCode.encodeFailed,
          ),
        );
      }
      onProgress?.call(1);
      return CompositionResult.ok(file);
    } on CompositionException catch (e) {
      return CompositionResult.fail(e);
    } catch (e, st) {
      debugPrint('TemplateCompositionEngine.export: $e\n$st');
      return CompositionResult.fail(
        CompositionException(
          'Something went wrong while exporting',
          code: CompositionErrorCode.unknown,
          technicalDetail: e.toString(),
        ),
      );
    }
  }
}
