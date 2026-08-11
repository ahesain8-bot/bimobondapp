import 'dart:io';

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/layers/layer_engines.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/timeline/timeline_engine.dart';
import 'package:path_provider/path_provider.dart';

/// Phase 20 — pre-export validation (never crash on bad template data).
class TemplateValidator {
  const TemplateValidator();

  TemplateValidationReport validate({
    required VideoTemplateRecipeEntity recipe,
    required Map<String, SlotFillEntry> fills,
    TemplateTimeline? timeline,
    int? minFreeStorageBytes,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    if (recipe.id.isEmpty) {
      errors.add('Template id missing');
    }
    if (recipe.version <= 0) {
      warnings.add('Template version missing — using default');
    }

    final slotEngine = SlotEngine(recipe: recipe);
    final slotResult = slotEngine.validate(fills);
    if (slotResult.missingRequiredSlotIds.isNotEmpty) {
      errors.add('Required slots not filled');
    }
    if (slotResult.durationIssueSlotIds.isNotEmpty) {
      errors.add('Invalid slot duration / trim');
    }
    if (slotResult.typeMismatchSlotIds.isNotEmpty) {
      warnings.add('Some slots have media type mismatches');
    }

    for (final slot in slotEngine.slots) {
      final fill = fills[slot.id];
      final file = fill?.localFile;
      if (file != null && !file.existsSync()) {
        errors.add('Media missing for ${SlotEngine.slotTitle(slot)}');
      }
    }

    final built = timeline ??
        const TimelineEngine().build(recipe: recipe, fills: fills);
    if (built.totalDuration <= 0) {
      errors.add('Timeline duration invalid');
    }
    if (built.width <= 0 || built.height <= 0) {
      errors.add('Unsupported resolution');
    }

    // Unsupported effect types → warning, not hard fail.
    const supportedFx = {
      'rgb_split',
      'flash_frame',
      'flash',
      'beat_zoom',
      'zoom_pulse',
      'zoom_punch',
      'ken_burns',
      'parallax_layers',
      'whip_pan',
      'vhs',
      'light_leak',
      'duotone',
      'glitch',
      'zoom',
      'shake',
      'blur_in',
      'blur_out',
      'spin',
      'mirror',
      'pip_layout',
      'mirror_stack',
      'grid_triple',
      'lyric_sandwich',
      'duo_split',
      'quad_grid',
      'circle_pip',
      'film_strip',
      'diagonal_split',
      'side_by_side_mirror',
      'shaped_cutout',
      'none',
    };
    for (final item in built.items) {
      final fx = item.effectType;
      if (fx != null &&
          fx.isNotEmpty &&
          !supportedFx.contains(fx.toLowerCase())) {
        warnings.add('Unsupported effect "$fx" will be skipped');
      }
      final tr = item.transitionType;
      if (tr != null &&
          tr.isNotEmpty &&
          !TransitionEngine.known.contains(tr.toLowerCase())) {
        warnings.add('Unsupported transition "$tr" — using cut');
      }
    }

    final audio = const AudioEngine().plan(built);
    if (recipe.soundId != null && !audio.hasAudio) {
      warnings.add('Template sound URL missing');
    }

    if (minFreeStorageBytes != null && minFreeStorageBytes > 0) {
      // Best-effort; skip if we cannot query disk.
      try {
        // No portable free-space API — leave as soft check for callers.
      } catch (_) {}
    }

    return TemplateValidationReport(
      errors: errors,
      warnings: warnings,
      slotResult: slotResult,
      timeline: built,
    );
  }
}

class TemplateValidationReport {
  const TemplateValidationReport({
    required this.errors,
    required this.warnings,
    required this.slotResult,
    required this.timeline,
  });

  final List<String> errors;
  final List<String> warnings;
  final SlotValidationResult slotResult;
  final TemplateTimeline timeline;

  bool get isValid => errors.isEmpty;
  bool get canExport => isValid && slotResult.canExport;

  String? get firstError => errors.isEmpty ? null : errors.first;
}

/// Phase 16 — local editing session around UserTemplateProject (template immutable).
class TemplateProjectSession {
  TemplateProjectSession({
    required this.recipe,
    required this.fills,
    this.projectId,
    this.project,
    this.status = UserTemplateProjectStatuses.editing,
  });

  final VideoTemplateRecipeEntity recipe;
  Map<String, SlotFillEntry> fills;
  String? projectId;
  VideoTemplateProjectEntity? project;
  String status;

  SlotEngine get slotEngine => SlotEngine(recipe: recipe);

  TemplateTimeline buildTimeline() =>
      const TimelineEngine().build(recipe: recipe, fills: fills);

  void setSlotFile(String slotId, File file) {
    final prev = fills[slotId];
    if (prev == null) return;
    fills = Map<String, SlotFillEntry>.from(fills)
      ..[slotId] = prev.copyWith(localFile: file);
  }

  void setSlotUrl(String slotId, String url) {
    final prev = fills[slotId];
    if (prev == null) return;
    fills = Map<String, SlotFillEntry>.from(fills)
      ..[slotId] = prev.copyWith(userAssetUrl: url);
  }

  void attachProject(VideoTemplateProjectEntity project) {
    this.project = project;
    projectId = project.id;
    status = project.status;
    fills = UserProjectSlotMapper.mergeProjectIntoFills(
      fills: fills,
      project: project,
    );
  }

  factory TemplateProjectSession.fromRecipe(VideoTemplateRecipeEntity recipe) {
    final engine = SlotEngine(recipe: recipe);
    return TemplateProjectSession(
      recipe: recipe,
      fills: engine.emptyFills(),
    );
  }
}

/// Phase 17 — poll ProjectExport until complete / failed.
class ExportProgressController {
  ExportProgressController({
    required this.projectId,
    required this.exportId,
    required this.fetch,
  });

  final String projectId;
  final String exportId;
  final Future<VideoTemplateExportEntity?> Function({
    required String projectId,
    required String exportId,
  }) fetch;

  VideoTemplateExportEntity? last;
  bool _stopped = false;

  void stop() => _stopped = true;

  Stream<VideoTemplateExportEntity> watch({
    Duration queuedInterval = const Duration(seconds: 2),
    Duration processingInterval = const Duration(milliseconds: 500),
    int maxTicks = 240,
  }) async* {
    _stopped = false;
    for (var i = 0; i < maxTicks; i++) {
      if (_stopped) return;
      final snap = await fetch(projectId: projectId, exportId: exportId);
      if (snap == null) {
        await Future<void>.delayed(queuedInterval);
        continue;
      }
      last = snap;
      yield snap;
      if (snap.isComplete || snap.isFailed) return;
      await Future<void>.delayed(
        snap.isProcessing ? processingInterval : queuedInterval,
      );
    }
  }
}

/// Phase 18 — avoid decoding media outside the playhead window.
class TemplatePerfHints {
  const TemplatePerfHints();

  /// Suggested decode window around playhead (seconds).
  static const lookBehind = 1.5;
  static const lookAhead = 3.0;

  static Set<String> mediaPathsInWindow(
    TemplateTimeline timeline,
    double playhead,
  ) {
    final from = (playhead - lookBehind).clamp(0.0, timeline.totalDuration);
    final to = (playhead + lookAhead).clamp(0.0, timeline.totalDuration);
    final paths = <String>{};
    for (final item in timeline.intersecting(from, to)) {
      final p = item.userMediaPath;
      if (p != null && p.isNotEmpty) paths.add(p);
    }
    return paths;
  }

  static Future<int> roughTempDirBytes() async {
    try {
      final dir = await getTemporaryDirectory();
      var total = 0;
      await for (final e in dir.list(recursive: false)) {
        if (e is File) {
          total += await e.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
