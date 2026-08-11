import 'dart:io';

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/layers/layer_engines.dart';
import 'package:bimobondapp/app/video_templates/engine/render/render_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/timeline/timeline_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/validation/template_validator.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/video_template_client_renderer.dart';

export 'package:bimobondapp/app/video_templates/engine/layers/layer_engines.dart';
export 'package:bimobondapp/app/video_templates/engine/render/render_engine.dart';
export 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
export 'package:bimobondapp/app/video_templates/engine/timeline/timeline_engine.dart';
export 'package:bimobondapp/app/video_templates/engine/validation/template_validator.dart';

/// Generic Template Engine facade.
///
/// Prefer [TemplateCompositionEngine] for IMAGE/VIDEO/mixed composition.
/// This facade remains for existing use cases and DI.
class TemplateEngine {
  TemplateEngine({
    TimelineEngine? timelineEngine,
    RenderEngine? renderEngine,
    TemplateValidator? validator,
    FilterEngine? filterEngine,
    EffectEngine? effectEngine,
    TransitionEngine? transitionEngine,
    KeyframeEngine? keyframeEngine,
    TextEngine? textEngine,
    StickerEngine? stickerEngine,
    OverlayEngine? overlayEngine,
    AudioEngine? audioEngine,
    TrackEngine? trackEngine,
    ClipEngine? clipEngine,
  })  : timelineEngine = timelineEngine ?? const TimelineEngine(),
        renderEngine = renderEngine ?? const RenderEngine(),
        validator = validator ?? const TemplateValidator(),
        filterEngine = filterEngine ?? const FilterEngine(),
        effectEngine = effectEngine ?? const EffectEngine(),
        transitionEngine = transitionEngine ?? const TransitionEngine(),
        keyframeEngine = keyframeEngine ?? const KeyframeEngine(),
        textEngine = textEngine ?? const TextEngine(),
        stickerEngine = stickerEngine ?? const StickerEngine(),
        overlayEngine = overlayEngine ?? const OverlayEngine(),
        audioEngine = audioEngine ?? const AudioEngine(),
        trackEngine = trackEngine ?? const TrackEngine(),
        clipEngine = clipEngine ?? const ClipEngine();

  final TimelineEngine timelineEngine;
  final RenderEngine renderEngine;
  final TemplateValidator validator;
  final FilterEngine filterEngine;
  final EffectEngine effectEngine;
  final TransitionEngine transitionEngine;
  final KeyframeEngine keyframeEngine;
  final TextEngine textEngine;
  final StickerEngine stickerEngine;
  final OverlayEngine overlayEngine;
  final AudioEngine audioEngine;
  final TrackEngine trackEngine;
  final ClipEngine clipEngine;

  SlotEngine slotsFor(VideoTemplateRecipeEntity recipe) =>
      SlotEngine(recipe: recipe);

  TemplateProjectSession openSession(VideoTemplateRecipeEntity recipe) =>
      TemplateProjectSession.fromRecipe(recipe);

  TemplateTimeline buildTimeline({
    required VideoTemplateRecipeEntity recipe,
    required Map<String, SlotFillEntry> fills,
  }) {
    return timelineEngine.build(recipe: recipe, fills: fills);
  }

  PreviewEngine preview(TemplateTimeline timeline) => PreviewEngine(
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

  TemplateValidationReport validate({
    required VideoTemplateRecipeEntity recipe,
    required Map<String, SlotFillEntry> fills,
  }) {
    return validator.validate(recipe: recipe, fills: fills);
  }

  Future<File?> export({
    required VideoTemplateRecipeEntity recipe,
    required Map<String, SlotFillEntry> fills,
    TemplateClientExportQuality quality = TemplateClientExportQuality.standard,
    void Function(double progress)? onProgress,
  }) async {
    final report = validate(recipe: recipe, fills: fills);
    if (!report.canExport) return null;
    final plan = await renderEngine.plan(
      recipe: recipe,
      fills: fills,
      timeline: report.timeline,
    );
    return renderEngine.export(
      plan,
      quality: quality,
      onProgress: onProgress,
    );
  }
}
