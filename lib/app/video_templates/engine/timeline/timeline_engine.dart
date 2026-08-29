import 'dart:math' as math;

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
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
    fontSize,
    color,
    alignment,
    animationIn,
    animationOut,
    positionX,
    positionY,
    opacity,
    scale,
    rotation,
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
    List<UserEditorFilterTrack> userFilters = const [],
    List<UserEditorEffectTrack> userEffects = const [],
    List<UserEditorTransitionTrack> userTransitions = const [],
    List<UserEditorTextOverlay> userTexts = const [],
    List<UserEditorStickerOverlay> userStickers = const [],
    List<UserEditorAudioTrack> userAudios = const [],
    UserEditorAudioTiming? userAudioTiming,
    SoundEntity? userSound,
    bool clearRecipeSound = false,
    int? userSoundSegmentStartMs,
    int? userSoundSegmentEndMs,
    Set<String> userOwnedFilterSlots = const {},
    Set<String> userOwnedEffectSlots = const {},
    Set<String> userOwnedTransitionSlots = const {},
    bool userTextsLayerOwned = false,
    bool userStickersLayerOwned = false,
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

      final fileIsVideo =
          fill?.isLocalVideo == true ||
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

      // Slot-level effects / filters — user layers replace admin slot FX.
      final slotUserEffects = userEffects.where((e) => e.slotId == slot.id).toList();
      final useUserEffects =
          userOwnedEffectSlots.contains(slot.id) || slotUserEffects.isNotEmpty;
      if (useUserEffects) {
        for (var e = 0; e < slotUserEffects.length; e++) {
          final userFx = slotUserEffects[e];
          if (userFx.effectType.isEmpty || userFx.effectType == 'none') continue;
          final fxStart = start + userFx.startTime.clamp(0.0, dur);
          final fxEndRel = (userFx.endTime ?? dur).clamp(0.0, dur);
          final fxEnd = fxEndRel >= dur - 0.001 ? end + 0.001 : start + fxEndRel;
          items.add(
            TimelineItem(
              id: 'user_fx_${userFx.id}',
              kind: TimelineLayerKind.videoClip,
              startTime: fxStart,
              endTime: fxEnd > fxStart ? fxEnd : fxStart + 0.05,
              layerOrder: 1000 + e,
              slotId: slot.id,
              effectType: userFx.effectType,
              parameters: userFx.parameters,
            ),
          );
        }
      } else {
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
      }

      final slotUserFilters =
          userFilters.where((f) => f.slotId == slot.id).toList();
      final useUserFilters =
          userOwnedFilterSlots.contains(slot.id) || slotUserFilters.isNotEmpty;
      if (useUserFilters) {
        for (var f = 0; f < slotUserFilters.length; f++) {
          final userFilter = slotUserFilters[f];
          if (userFilter.filterName.isEmpty ||
              userFilter.filterName == 'none') {
            continue;
          }
          final filterStart = start + userFilter.startTime.clamp(0.0, dur);
          final filterEndRel = (userFilter.endTime ?? dur).clamp(0.0, dur);
          final filterEnd = filterEndRel >= dur - 0.001
              ? end + 0.001
              : start + filterEndRel;
          items.add(
            TimelineItem(
              id: 'user_filter_${userFilter.id}',
              kind: TimelineLayerKind.videoClip,
              startTime: filterStart,
              endTime: filterEnd > filterStart ? filterEnd : filterStart + 0.05,
              layerOrder: 900 + f,
              slotId: slot.id,
              filterName: userFilter.filterName,
              filterIntensity: userFilter.intensity,
            ),
          );
        }
      } else {
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
      }

      // Transition after this slot.
      final useUserTransition = userOwnedTransitionSlots.contains(slot.id) ||
          userTransitions.any((t) => t.slotId == slot.id);
      if (useUserTransition) {
        final userTr = userTransitions
            .where((t) => t.slotId == slot.id)
            .firstOrNull;
        if (userTr != null &&
            i < slots.length - 1 &&
            userTr.transitionType.isNotEmpty &&
            userTr.transitionType != 'none' &&
            userTr.transitionType != 'cut') {
          final td = userTr.durationSeconds.clamp(0.05, 2.0);
          items.add(
            TimelineItem(
              id: 'user_tr_${userTr.id}',
              kind: TimelineLayerKind.transition,
              startTime: math.max(0, end - td / 2),
              endTime: end + td / 2,
              layerOrder: 2000 + i,
              slotId: slot.id,
              transitionType: userTr.transitionType,
              parameters: userTr.parameters,
            ),
          );
        }
      } else {
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
              slotId: slot.id,
              transitionType: tr.type,
              parameters: tr.parameters ?? const {},
            ),
          );
        }
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
      // When the user owns that slot's look (incl. cleared), do not re-apply
      // recipe clip FX — otherwise deleted filters/effects stay in preview.
      final clipSlotId = clip.slotId;
      final skipClipEffects = clipSlotId != null
          ? userOwnedEffectSlots.contains(clipSlotId)
          : userOwnedEffectSlots.isNotEmpty;
      final skipClipFilters = clipSlotId != null
          ? userOwnedFilterSlots.contains(clipSlotId)
          : userOwnedFilterSlots.isNotEmpty;
      if (!skipClipEffects) {
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
      }
      if (!skipClipFilters) {
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
      }
      if (end > total) total = end;
    }

    if (!userTextsLayerOwned) {
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
            assetUrl: t.fontAssetUrl ?? t.fontAsset?.url,
            parameters: {if (t.fontAssetId != null) 'fontAssetId': t.fontAssetId},
          ),
        );
        if (t.endTime > total) total = t.endTime;
      }
    }

    for (var i = 0; i < userTexts.length; i++) {
      final t = userTexts[i];
      final end = t.endTime > t.startTime ? t.endTime : t.startTime + 1;
      items.add(
        TimelineItem(
          id: 'user_text_${t.id}',
          kind: TimelineLayerKind.text,
          startTime: t.startTime,
          endTime: end,
          layerOrder: 3100 + i,
          text: t.text,
          fontSize: t.fontSize,
          color: t.color,
          animationIn: t.animationIn,
          animationOut: t.animationOut,
          positionX: t.positionX,
          positionY: t.positionY,
          assetUrl: t.fontAssetUrl,
          parameters: {
            if (t.fontAssetId != null) 'fontAssetId': t.fontAssetId,
            if (t.fontLabel != null) 'fontLabel': t.fontLabel,
          },
        ),
      );
      if (end > total) total = end;
    }

    if (!userStickersLayerOwned) {
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
    }

    for (var i = 0; i < userStickers.length; i++) {
      final s = userStickers[i];
      final end = s.endTime ?? total;
      items.add(
        TimelineItem(
          id: 'user_sticker_${s.id}',
          kind: TimelineLayerKind.sticker,
          startTime: s.startTime,
          endTime: end > s.startTime ? end : s.startTime + 1,
          layerOrder: 3150 + i,
          positionX: s.positionX,
          positionY: s.positionY,
          scale: s.scale,
          opacity: s.opacity,
          assetUrl: s.assetUrl,
          parameters: {
            if (s.label != null && s.label!.isNotEmpty) 'label': s.label,
            if (s.presetId != null) 'presetId': s.presetId,
          },
        ),
      );
      if (end > total) total = end;
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

    final audioUrl = clearRecipeSound
        ? null
        : (userAudios.isNotEmpty
              ? userAudios.first.sound.resolvedAudioUrl
              : (userSound?.resolvedAudioUrl ??
                    recipe.sound?.resolvedAudioUrl ??
                    recipe.music?.audioUrl));

    if (userAudios.isNotEmpty) {
      for (var i = 0; i < userAudios.length; i++) {
        final track = userAudios[i];
        final url = track.sound.resolvedAudioUrl;
        if (url.isEmpty) continue;
        final audioStart = track.startTime.clamp(0.0, total);
        final audioEnd = (track.endTime ?? total).clamp(
          audioStart + 0.05,
          total,
        );
        items.add(
          TimelineItem(
            id: 'audio_${track.id}',
            kind: TimelineLayerKind.audio,
            startTime: audioStart,
            endTime: audioEnd,
            layerOrder: -100 - i,
            assetUrl: url,
            volume: 1,
          ),
        );
        if (audioEnd > total) total = audioEnd;
      }
    } else if (audioUrl != null && audioUrl.isNotEmpty) {
      final audioStart = userAudioTiming?.startTime ?? 0.0;
      final audioEnd = userAudioTiming?.endTime ?? total;
      items.add(
        TimelineItem(
          id: 'audio_main',
          kind: TimelineLayerKind.audio,
          startTime: audioStart.clamp(0.0, total),
          endTime: audioEnd > audioStart
              ? audioEnd.clamp(0.0, total)
              : audioStart + 0.05,
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
      audioStartMs: userSoundSegmentStartMs ?? recipe.soundSegmentStartMs,
      audioEndMs: userSoundSegmentEndMs ?? recipe.soundSegmentEndMs,
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
