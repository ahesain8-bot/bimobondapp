import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:bimobondapp/app/video_templates/domain/entities/template_schema_enums.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/timeline/timeline_engine.dart';

/// Phase 7 — filter resolution (GPU/LUT ready descriptors).
class FilterEngine {
  const FilterEngine();

  List<TimelineItem> filtersAt(TemplateTimeline timeline, double time) {
    return timeline
        .activeAt(time)
        .where((i) => i.filterName != null && i.filterName!.isNotEmpty)
        .toList(growable: false);
  }

  ResolvedFilter? resolve(TimelineItem item) {
    final name = item.filterName;
    if (name == null || name.isEmpty || name == 'none') return null;
    return ResolvedFilter(
      filterName: name,
      intensity: (item.filterIntensity ?? 1).clamp(0, 1),
      lutAssetId: item.lutAssetId,
    );
  }
}

class ResolvedFilter {
  const ResolvedFilter({
    required this.filterName,
    required this.intensity,
    this.lutAssetId,
  });

  final String filterName;
  final double intensity;
  final String? lutAssetId;
}

/// Phase 8 — time-aware effects.
class EffectEngine {
  const EffectEngine();

  static double progress(double t, double start, double end) {
    if (end <= start) return 1;
    return ((t - start) / (end - start)).clamp(0.0, 1.0);
  }

  List<ResolvedEffect> activeEffects(TemplateTimeline timeline, double time) {
    final out = <ResolvedEffect>[];
    for (final item in timeline.activeAt(time)) {
      final type = item.effectType;
      if (type == null || type.isEmpty) continue;
      out.add(
        ResolvedEffect(
          effectType: type,
          startTime: item.startTime,
          endTime: item.endTime,
          parameters: item.parameters,
          progress: progress(time, item.startTime, item.endTime),
        ),
      );
    }
    return out;
  }
}

class ResolvedEffect {
  const ResolvedEffect({
    required this.effectType,
    required this.startTime,
    required this.endTime,
    required this.parameters,
    required this.progress,
  });

  final String effectType;
  final double startTime;
  final double endTime;
  final Map<String, dynamic> parameters;
  final double progress;
}

/// Phase 9 — transitions (fade/flash/zoom/slide/blur/crossfade + unknown passthrough).
class TransitionEngine {
  const TransitionEngine();

  static const known = {
    'fade',
    'flash',
    'zoom',
    'zoom_in',
    'zoom_out',
    'slide',
    'slide_left',
    'slide_right',
    'blur',
    'crossfade',
    'glitch',
    'cut',
    'push_left',
    'push_right',
    'push_up',
    'push_down',
    'zoom_blur',
    'film_burn',
    'match_cut_flash',
  };

  List<ResolvedTransition> activeAt(TemplateTimeline timeline, double time) {
    return timeline
        .activeAt(time)
        .where((i) => i.kind == TimelineLayerKind.transition)
        .map(
          (i) => ResolvedTransition(
            type: i.transitionType ?? 'cut',
            startTime: i.startTime,
            endTime: itemEnd(i),
            progress: EffectEngine.progress(time, i.startTime, i.endTime),
            parameters: i.parameters,
            isKnown: known.contains((i.transitionType ?? '').toLowerCase()),
          ),
        )
        .toList(growable: false);
  }

  static double itemEnd(TimelineItem i) => i.endTime;
}

class ResolvedTransition {
  const ResolvedTransition({
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.progress,
    required this.parameters,
    required this.isKnown,
  });

  final String type;
  final double startTime;
  final double endTime;
  final double progress;
  final Map<String, dynamic> parameters;
  final bool isKnown;
}

/// Phase 10 — keyframe interpolation.
class KeyframeEngine {
  const KeyframeEngine();

  double interpolate({
    required List<TemplateKeyframeEntity> keyframes,
    required String property,
    required double time,
    double fallback = 0,
  }) {
    final frames = keyframes
        .where((k) => k.property == property)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (frames.isEmpty) return fallback;
    if (time <= frames.first.time) {
      return frames.first.valueAsDouble ?? fallback;
    }
    if (time >= frames.last.time) {
      return frames.last.valueAsDouble ?? fallback;
    }
    for (var i = 0; i < frames.length - 1; i++) {
      final a = frames[i];
      final b = frames[i + 1];
      if (time >= a.time && time <= b.time) {
        final av = a.valueAsDouble ?? fallback;
        final bv = b.valueAsDouble ?? fallback;
        final span = b.time - a.time;
        final t = span <= 0 ? 1.0 : (time - a.time) / span;
        final eased = _ease(t, a.easing ?? b.easing);
        return av + (bv - av) * eased;
      }
    }
    return fallback;
  }

  TransformSample sampleTransform({
    required TimelineItem item,
    required double time,
  }) {
    final kfs = item.keyframes;
    if (kfs.isEmpty) {
      return TransformSample(
        positionX: item.positionX,
        positionY: item.positionY,
        scale: item.scale,
        rotation: item.rotation,
        opacity: item.opacity,
        volume: item.volume,
      );
    }
    final localT = time - item.startTime;
    return TransformSample(
      positionX: interpolate(
        keyframes: kfs,
        property: 'positionX',
        time: localT,
        fallback: item.positionX,
      ),
      positionY: interpolate(
        keyframes: kfs,
        property: 'positionY',
        time: localT,
        fallback: item.positionY,
      ),
      scale: interpolate(
        keyframes: kfs,
        property: 'scale',
        time: localT,
        fallback: item.scale,
      ),
      rotation: interpolate(
        keyframes: kfs,
        property: 'rotation',
        time: localT,
        fallback: item.rotation,
      ),
      opacity: interpolate(
        keyframes: kfs,
        property: 'opacity',
        time: localT,
        fallback: item.opacity,
      ),
      volume: interpolate(
        keyframes: kfs,
        property: 'volume',
        time: localT,
        fallback: item.volume,
      ),
    );
  }

  static double _ease(double t, String? easing) {
    final e = (easing ?? TemplateKeyframeEasings.linear).trim();
    switch (e) {
      case TemplateKeyframeEasings.easeIn:
        return t * t;
      case TemplateKeyframeEasings.easeOut:
        return 1 - (1 - t) * (1 - t);
      case TemplateKeyframeEasings.easeInOut:
        return t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
      default:
        return t; // unknown → linear
    }
  }
}

class TransformSample {
  const TransformSample({
    required this.positionX,
    required this.positionY,
    required this.scale,
    required this.rotation,
    required this.opacity,
    required this.volume,
  });

  final double positionX;
  final double positionY;
  final double scale;
  final double rotation;
  final double opacity;
  final double volume;
}

/// Phase 11 — text layers.
class TextEngine {
  const TextEngine();

  List<TimelineItem> textsAt(TemplateTimeline timeline, double time) =>
      timeline
          .activeAt(time)
          .where((i) => i.kind == TimelineLayerKind.text)
          .toList(growable: false);

  Color? parseColor(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var s = raw.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
  }
}

/// Phase 12 — stickers + overlays.
class StickerEngine {
  const StickerEngine();

  List<TimelineItem> stickersAt(TemplateTimeline timeline, double time) =>
      timeline
          .activeAt(time)
          .where((i) => i.kind == TimelineLayerKind.sticker)
          .toList(growable: false);
}

class OverlayEngine {
  const OverlayEngine();

  List<TimelineItem> overlaysAt(TemplateTimeline timeline, double time) =>
      timeline
          .activeAt(time)
          .where((i) => i.kind == TimelineLayerKind.overlay)
          .toList(growable: false);
}

/// Phase 13 — audio / beat sync helpers.
class AudioEngine {
  const AudioEngine();

  double? beatAt(TemplateBeatMapEntity beatMap, int beatIndex) {
    if (beatIndex < 0 || beatIndex >= beatMap.beats.length) return null;
    return beatMap.beats[beatIndex];
  }

  /// Snap [time] to nearest beat within [tolerance] seconds.
  double snapToBeat(
    TemplateBeatMapEntity beatMap,
    double time, {
    double tolerance = 0.12,
  }) {
    if (beatMap.beats.isEmpty) return time;
    double best = beatMap.beats.first;
    var bestDist = (time - best).abs();
    for (final b in beatMap.beats) {
      final d = (time - b).abs();
      if (d < bestDist) {
        bestDist = d;
        best = b;
      }
    }
    return bestDist <= tolerance ? best : time;
  }

  AudioPlan plan(TemplateTimeline timeline) {
    return AudioPlan(
      audioUrl: timeline.audioUrl,
      startMs: timeline.audioStartMs ?? 0,
      endMs: timeline.audioEndMs,
      durationSeconds: timeline.totalDuration,
      beatMap: timeline.beatMap,
    );
  }
}

class AudioPlan {
  const AudioPlan({
    required this.durationSeconds,
    required this.beatMap,
    this.audioUrl,
    this.startMs = 0,
    this.endMs,
  });

  final String? audioUrl;
  final int startMs;
  final int? endMs;
  final double durationSeconds;
  final TemplateBeatMapEntity beatMap;

  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;
}

/// Track / clip helpers (Phase 5 supporting).
class TrackEngine {
  const TrackEngine();

  List<TemplateTrackEntity> sorted(List<TemplateTrackEntity> tracks) {
    return List<TemplateTrackEntity>.from(tracks)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
}

class ClipEngine {
  const ClipEngine();

  List<TemplateClipEntity> forTrack(
    List<TemplateClipEntity> clips,
    String trackId,
  ) {
    return clips.where((c) => c.trackId == trackId).toList(growable: false)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}
