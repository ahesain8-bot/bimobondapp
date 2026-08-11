import 'dart:math' as math;

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:equatable/equatable.dart';

/// Deterministic timeline layer kinds.
enum TimelineLayerKind {
  videoClip,
  imageClip,
  text,
  sticker,
  overlay,
  transition,
  audio,
}

/// One resolved item on the composition timeline.
class TimelineItem extends Equatable {
  const TimelineItem({
    required this.id,
    required this.kind,
    required this.startTime,
    required this.endTime,
    required this.layerOrder,
    this.slotId,
    this.clipId,
    this.trackId,
    this.speed = 1,
    this.volume = 1,
    this.rotation = 0,
    this.scale = 1,
    this.positionX = 0,
    this.positionY = 0,
    this.opacity = 1,
    this.blendMode,
    this.effectType,
    this.filterName,
    this.filterIntensity,
    this.lutAssetId,
    this.transitionType,
    this.text,
    this.fontSize,
    this.color,
    this.alignment,
    this.animationIn,
    this.animationOut,
    this.assetUrl,
    this.userMediaPath,
    this.trimStart,
    this.trimEnd,
    this.parameters = const {},
    this.keyframes = const [],
  });

  final String id;
  final TimelineLayerKind kind;
  final double startTime;
  final double endTime;
  final int layerOrder;
  final String? slotId;
  final String? clipId;
  final String? trackId;
  final double speed;
  final double volume;
  final double rotation;
  final double scale;
  final double positionX;
  final double positionY;
  final double opacity;
  final String? blendMode;
  final String? effectType;
  final String? filterName;
  final double? filterIntensity;
  final String? lutAssetId;
  final String? transitionType;
  final String? text;
  final double? fontSize;
  final String? color;
  final String? alignment;
  final String? animationIn;
  final String? animationOut;
  final String? assetUrl;
  final String? userMediaPath;
  final double? trimStart;
  final double? trimEnd;
  final Map<String, dynamic> parameters;
  final List<TemplateKeyframeEntity> keyframes;

  double get duration => math.max(0, endTime - startTime);

  bool containsTime(double t) => t >= startTime && t < endTime;

  @override
  List<Object?> get props => [
        id,
        kind,
        startTime,
        endTime,
        layerOrder,
        slotId,
        clipId,
        trackId,
        speed,
        volume,
        rotation,
        scale,
        positionX,
        positionY,
        opacity,
        blendMode,
        effectType,
        filterName,
        filterIntensity,
        lutAssetId,
        transitionType,
        text,
        assetUrl,
        userMediaPath,
        trimStart,
        trimEnd,
        parameters,
        keyframes,
      ];
}

/// Full deterministic composition plan.
class TemplateTimeline extends Equatable {
  const TemplateTimeline({
    required this.items,
    required this.totalDuration,
    required this.width,
    required this.height,
    required this.fps,
    this.audioUrl,
    this.audioStartMs,
    this.audioEndMs,
    this.beatMap = const TemplateBeatMapEntity(),
  });

  final List<TimelineItem> items;
  final double totalDuration;
  final int width;
  final int height;
  final double fps;
  final String? audioUrl;
  final int? audioStartMs;
  final int? audioEndMs;
  final TemplateBeatMapEntity beatMap;

  List<TimelineItem> activeAt(double time) {
    final active = items.where((i) => i.containsTime(time)).toList()
      ..sort((a, b) => a.layerOrder.compareTo(b.layerOrder));
    return active;
  }

  /// Items whose range intersects [from, to) — for preview windowing.
  List<TimelineItem> intersecting(double from, double to) {
    return items
        .where((i) => i.endTime > from && i.startTime < to)
        .toList(growable: false);
  }

  @override
  List<Object?> get props => [
        items,
        totalDuration,
        width,
        height,
        fps,
        audioUrl,
        audioStartMs,
        audioEndMs,
        beatMap,
      ];
}

/// Phase 5 — builds a deterministic timeline from recipe + user fills.
class TimelineEngine {
  const TimelineEngine();

  TemplateTimeline build({
    required VideoTemplateRecipeEntity recipe,
    required Map<String, SlotFillEntry> fills,
  }) {
    final slotEngine = SlotEngine(recipe: recipe);
    final slots = slotEngine.slots;
    final items = <TimelineItem>[];

    // --- Slot-driven media timeline (primary for mobile recipe) ---
    var cursor = 0.0;
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final fill = fills[slot.id];
      final dur = UserProjectSlotMapper.resolveSlotDuration(slot, fill);
      final start = cursor;
      final end = start + dur;

      final fileIsVideo = fill?.isLocalVideo == true ||
          (fill?.localFile != null &&
              VideoThumbnailUtils.isVideoFile(fill!.localFile!));
      final kind = (fileIsVideo || slot.isVideo)
          ? TimelineLayerKind.videoClip
          : TimelineLayerKind.imageClip;

      items.add(
        TimelineItem(
          id: 'slot_${slot.id}',
          kind: kind,
          startTime: start,
          endTime: end,
          layerOrder: i,
          slotId: slot.id,
          speed: fill?.speed ?? 1,
          volume: fill?.volume ?? 1,
          rotation: fill?.rotation ?? 0,
          scale: fill?.scale ?? 1,
          userMediaPath: fill?.localFile?.path,
          assetUrl: fill?.userAssetUrl,
          trimStart: fill?.trimStart,
          trimEnd: fill?.trimEnd,
        ),
      );

      // Slot-level effects / filters as time-window markers.
      for (var e = 0; e < slot.effects.length; e++) {
        final fx = slot.effects[e];
        final fxStart = start + fx.startTime;
        final fxEnd = fx.endTime != null ? start + fx.endTime! : end;
        items.add(
          TimelineItem(
            id: 'slot_fx_${slot.id}_$e',
            kind: TimelineLayerKind.videoClip,
            startTime: fxStart.clamp(start, end),
            endTime: fxEnd.clamp(start, end),
            layerOrder: 1000 + e,
            slotId: slot.id,
            effectType: fx.effectType,
            parameters: fx.parameters,
          ),
        );
      }
      for (var f = 0; f < slot.filters.length; f++) {
        final filter = slot.filters[f];
        items.add(
          TimelineItem(
            id: 'slot_filter_${slot.id}_$f',
            kind: TimelineLayerKind.videoClip,
            startTime: start,
            endTime: end,
            layerOrder: 900 + f,
            slotId: slot.id,
            filterName: filter.filterName,
            filterIntensity: filter.intensity,
            lutAssetId: filter.lutAssetId,
          ),
        );
      }

      // Transition after this slot.
      final tr = _transitionAfter(recipe, i, slot);
      if (tr != null && i < slots.length - 1) {
        final td = tr.durationSeconds.clamp(0.05, 2.0);
        items.add(
          TimelineItem(
            id: 'tr_${slot.id}',
            kind: TimelineLayerKind.transition,
            startTime: math.max(0, end - td / 2),
            endTime: end + td / 2,
            layerOrder: 2000 + i,
            transitionType: tr.type,
            parameters: tr.parameters ?? const {},
          ),
        );
      }

      cursor = end;
    }

    // Prefer recipe.duration when longer (trailing hold).
    var total = cursor;
    if (recipe.duration != null && recipe.duration! > total) {
      total = recipe.duration!;
    }

    // --- Track clips (admin timeline) when present ---
    for (final clip in recipe.clips) {
      final start = clip.startTime;
      final end = clip.endTime ?? (start + 1);
      items.add(
        TimelineItem(
          id: 'clip_${clip.id}',
          kind: TimelineLayerKind.videoClip,
          startTime: start,
          endTime: end,
          layerOrder: 100 + clip.layerOrder,
          clipId: clip.id,
          trackId: clip.trackId,
          slotId: clip.slotId,
          speed: clip.speed,
          volume: clip.volume,
          rotation: clip.rotation,
          scale: clip.scale,
          positionX: clip.positionX,
          positionY: clip.positionY,
          opacity: clip.opacity,
          blendMode: clip.blendMode,
          assetUrl: clip.asset?.url,
          keyframes: clip.keyframes,
        ),
      );
      // Promote clip filters/effects so preview + bake share the same look.
      for (var e = 0; e < clip.effects.length; e++) {
        final fx = clip.effects[e];
        final fxStart = start + fx.startTime;
        final fxEnd = fx.endTime != null ? start + fx.endTime! : end;
        items.add(
          TimelineItem(
            id: 'clip_fx_${clip.id}_$e',
            kind: TimelineLayerKind.videoClip,
            startTime: fxStart.clamp(start, end),
            endTime: fxEnd.clamp(start, end),
            layerOrder: 1100 + e,
            clipId: clip.id,
            effectType: fx.effectType,
            parameters: fx.parameters,
          ),
        );
      }
      for (var f = 0; f < clip.filters.length; f++) {
        final filter = clip.filters[f];
        items.add(
          TimelineItem(
            id: 'clip_filter_${clip.id}_$f',
            kind: TimelineLayerKind.videoClip,
            startTime: start,
            endTime: end,
            layerOrder: 950 + f,
            clipId: clip.id,
            filterName: filter.filterName,
            filterIntensity: filter.intensity,
            lutAssetId: filter.lutAssetId,
          ),
        );
      }
      if (end > total) total = end;
    }

    for (final t in recipe.texts) {
      items.add(
        TimelineItem(
          id: 'text_${t.id}',
          kind: TimelineLayerKind.text,
          startTime: t.startTime,
          endTime: t.endTime > t.startTime ? t.endTime : t.startTime + 1,
          layerOrder: 3000,
          trackId: t.trackId,
          text: t.text,
          fontSize: t.fontSize,
          color: t.color,
          alignment: t.alignment,
          animationIn: t.animationIn,
          animationOut: t.animationOut,
          positionX: t.positionX,
          positionY: t.positionY,
          assetUrl: t.fontAsset?.url,
        ),
      );
      if (t.endTime > total) total = t.endTime;
    }

    for (final s in recipe.stickers) {
      items.add(
        TimelineItem(
          id: 'sticker_${s.id}',
          kind: TimelineLayerKind.sticker,
          startTime: s.startTime,
          endTime: s.endTime > s.startTime ? s.endTime : s.startTime + 1,
          layerOrder: 3100,
          trackId: s.trackId,
          positionX: s.positionX,
          positionY: s.positionY,
          scale: s.scale,
          rotation: s.rotation,
          opacity: s.opacity,
          assetUrl: s.assetUrl ?? s.asset?.url,
        ),
      );
      if (s.endTime > total) total = s.endTime;
    }

    for (final o in recipe.overlays) {
      items.add(
        TimelineItem(
          id: 'overlay_${o.id}',
          kind: TimelineLayerKind.overlay,
          startTime: o.startTime,
          endTime: o.endTime > o.startTime ? o.endTime : o.startTime + 1,
          layerOrder: 3200,
          trackId: o.trackId,
          opacity: o.opacity,
          blendMode: o.blendMode,
          assetUrl: o.assetUrl ?? o.asset?.url,
        ),
      );
      if (o.endTime > total) total = o.endTime;
    }

    final audioUrl =
        recipe.sound?.resolvedAudioUrl ?? recipe.music?.audioUrl;

    if (audioUrl != null && audioUrl.isNotEmpty) {
      items.add(
        TimelineItem(
          id: 'audio_main',
          kind: TimelineLayerKind.audio,
          startTime: 0,
          endTime: total,
          layerOrder: -100,
          assetUrl: audioUrl,
          volume: 1,
        ),
      );
    }

    items.sort((a, b) {
      final c = a.startTime.compareTo(b.startTime);
      if (c != 0) return c;
      return a.layerOrder.compareTo(b.layerOrder);
    });

    return TemplateTimeline(
      items: List.unmodifiable(items),
      totalDuration: math.max(total, 0.1),
      width: recipe.width > 0 ? recipe.width : 1080,
      height: recipe.height > 0 ? recipe.height : 1920,
      fps: recipe.fps > 0 ? recipe.fps : 30,
      audioUrl: audioUrl,
      audioStartMs: recipe.soundSegmentStartMs,
      audioEndMs: recipe.soundSegmentEndMs,
      beatMap: recipe.beatMap,
    );
  }

  VideoTemplateTransitionEntity? _transitionAfter(
    VideoTemplateRecipeEntity recipe,
    int slotIndex,
    VideoTemplateSlotEntity slot,
  ) {
    for (final t in recipe.transitions) {
      if (t.afterSlotIndex == slotIndex) return t;
    }
    final type = slot.transitionType ?? slot.defaultTransition;
    if (type == null || type.isEmpty || type.toLowerCase() == 'cut') {
      return null;
    }
    return VideoTemplateTransitionEntity(
      afterSlotIndex: slotIndex,
      type: type,
      durationSeconds: slot.transitionDurationSeconds ?? 0.3,
    );
  }
}
