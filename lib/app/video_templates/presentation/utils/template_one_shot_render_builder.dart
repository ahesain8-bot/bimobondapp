import 'dart:math' as math;

import 'package:bimobondapp/app/video_templates/composition/composition_session.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/foundation.dart';

/// Builds the JSON body for `POST /video-templates/render` from editor state.
abstract final class TemplateOneShotRenderBuilder {
  static Map<String, dynamic> build({
    required CompositionSession session,
    required Map<String, String> slotIdToUploadedUrl,
    String? catalogTemplateId,
    String? title,
    String? exportQuality,
    String? resolution,
    double? fps,
  }) {
    final recipe = session.recipe;
    final body = <String, dynamic>{};

    final templateId = VideoTemplateProjectIds.normalizeServerId(
      catalogTemplateId,
    );
    if (templateId != null) {
      body['templateId'] = templateId;
    }

    final media = <Map<String, dynamic>>[];
    final slots = <Map<String, dynamic>>[];
    final orderedSlots = session.slots;

    for (var i = 0; i < orderedSlots.length; i++) {
      final slot = orderedSlots[i];
      final fill = session.fills[slot.id];
      final url =
          slotIdToUploadedUrl[slot.id] ??
          (fill?.userAssetUrl != null
              ? MediaUtils.toServerUploadPath(fill!.userAssetUrl!)
              : null);
      if (url == null || url.isEmpty) continue;

      media.add({
        'url': url,
        'type': _mediaType(slot: slot, fill: fill, url: url),
      });

      final slotPatch = _buildSlotPatch(
        slotIndex: slot.slotIndex >= 0 ? slot.slotIndex : i,
        fill: fill,
        slot: slot,
        filter: session.slotFilterOverrides[slot.id],
        effect: session.slotEffectOverrides[slot.id],
      );
      if (slotPatch != null) slots.add(slotPatch);
    }

    if (media.isNotEmpty) {
      body['media'] = media;
    }

    if (slots.isNotEmpty) {
      body['slots'] = slots;
    }

    // Gallery / free edit — explicit duration helps server align overlays + audio.
    if (templateId == null) {
      final durationSeconds = _resolveGalleryDurationSeconds(session);
      if (durationSeconds > 0) {
        body['durationSeconds'] = durationSeconds;
      }
    }

    final texts = session.userTexts
        .where((t) => t.text.trim().isNotEmpty)
        .map(_buildText)
        .toList(growable: false);

    final audioTracks = session.resolvedAudioTracks;
    if (audioTracks.isNotEmpty) {
      body['audios'] = audioTracks
          .map(_buildAudioTrack)
          .toList(growable: false);
      _applyLegacySoundFields(body, audioTracks.first);
    } else if (!session.userSoundCleared) {
      final soundSegmentId = VideoTemplateProjectIds.normalizeServerId(
        session.userSoundSegmentId ?? recipe.soundSegmentId,
      );
      if (soundSegmentId != null) {
        body['soundSegmentId'] = soundSegmentId;
      } else {
        final sound = session.userSound ?? recipe.effectivePreviewSound;
        final soundId = VideoTemplateProjectIds.normalizeServerId(sound?.id);
        if (soundId != null) {
          body['soundId'] = soundId;
          final startMs =
              session.userSoundSegmentStartMs ?? recipe.soundSegmentStartMs;
          final endMs =
              session.userSoundSegmentEndMs ?? recipe.soundSegmentEndMs;
          if (startMs != null) body['soundStartMs'] = startMs;
          if (endMs != null) body['soundEndMs'] = endMs;
        }
      }
    }

    // Captions + music/effect windows as timed text (name · start–end).
    final scheduleTexts = _buildScheduleTexts(session);
    final allTexts = [...texts, ...scheduleTexts];
    if (allTexts.isNotEmpty) {
      body['texts'] = allTexts;
    }

    final stickers = session.userStickers
        .map(_buildSticker)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (stickers.isNotEmpty) {
      body['stickers'] = stickers;
    }

    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
      body['title'] = trimmedTitle.length > 120
          ? trimmedTitle.substring(0, 120)
          : trimmedTitle;
    }

    body['export'] = _buildExport(
      quality: exportQuality,
      resolution: resolution,
      fps: fps,
      recipe: recipe,
    );

    return body;
  }

  static Map<String, dynamic> _buildExport({
    String? quality,
    String? resolution,
    double? fps,
    required VideoTemplateRecipeEntity recipe,
  }) {
    final q = (quality ?? 'standard').trim().toLowerCase();
    final normalized = q == 'draft' ? 'draft' : 'standard';
    final export = <String, dynamic>{'quality': normalized};
    final res = resolution?.trim();
    if (res != null && res.isNotEmpty) {
      export['resolution'] = res;
    } else if (recipe.width > 0 && recipe.height > 0) {
      export['resolution'] = '${recipe.width}x${recipe.height}';
    }
    final effectiveFps = fps ?? (recipe.fps > 0 ? recipe.fps.toDouble() : null);
    if (effectiveFps != null && effectiveFps >= 1 && effectiveFps <= 60) {
      export['fps'] = effectiveFps.round();
    }
    return export;
  }

  static String _mediaType({
    required VideoTemplateSlotEntity slot,
    required SlotFillEntry? fill,
    required String url,
  }) {
    final kind = fill?.mediaKind?.trim().toUpperCase();
    if (kind == 'VIDEO' || kind == 'IMAGE') return kind!;
    if (_looksLikeVideo(url)) return 'VIDEO';
    if (slot.isVideoOnly || (slot.acceptsVideo && !slot.isImageOnly)) {
      return _looksLikeVideo(url) ? 'VIDEO' : 'IMAGE';
    }
    return 'IMAGE';
  }

  static bool _looksLikeVideo(String url) {
    final p = url.toLowerCase();
    return p.contains('.mp4') ||
        p.contains('.mov') ||
        p.contains('.m4v') ||
        p.contains('.webm') ||
        p.contains('.mkv') ||
        p.contains('video');
  }

  static Map<String, dynamic>? _buildSlotPatch({
    required int slotIndex,
    required SlotFillEntry? fill,
    required VideoTemplateSlotEntity slot,
    UserSlotFilterOverride? filter,
    UserSlotEffectOverride? effect,
  }) {
    final map = <String, dynamic>{'slotIndex': slotIndex};
    var hasOverride = false;
    final slotDur = UserProjectSlotMapper.resolveSlotDuration(slot, fill);
    final isImageSlot =
        slot.isImageOnly || (!slot.acceptsVideo && slot.acceptsImage);

    if (fill != null) {
      if (!isImageSlot && fill.trimStart != null) {
        map['trimStart'] = fill.trimStart;
        hasOverride = true;
      }
      if (!isImageSlot && fill.trimEnd != null) {
        map['trimEnd'] = fill.trimEnd;
        hasOverride = true;
      }
      if (!isImageSlot && fill.speed != 1) {
        map['speed'] = fill.speed;
        hasOverride = true;
      }
      if (fill.rotation != 0) {
        map['rotation'] = fill.rotation;
        hasOverride = true;
      }
      if (fill.scale != 1) {
        map['scale'] = fill.scale;
        hasOverride = true;
      }
      if (!isImageSlot && fill.volume != 1) {
        map['volume'] = fill.volume;
        hasOverride = true;
      }
    }

    final filterPresetId = VideoTemplateProjectIds.normalizeServerId(
      filter?.presetId,
    );
    if (filterPresetId != null) {
      map['filterPresetId'] = filterPresetId;
      map['filterIntensity'] = filter!.intensity.clamp(0.0, 1.0);
      final window = SlotLocalTiming.normalize(
        slotDuration: slotDur,
        startTime: filter.startTime,
        endTime: filter.endTime,
      );
      map['filterStartTime'] = window.start;
      map['filterEndTime'] = window.end;
      hasOverride = true;
    } else if (filter != null &&
        filter.filterName.isNotEmpty &&
        filter.filterName != 'none') {
      // Local fallback presets — preview only; server needs UUID catalog ids.
      debugPrint(
        'OneShotRender: skip non-UUID filter preset '
        '"${filter.presetId}" (${filter.filterName})',
      );
    }

    final effectPresetId = VideoTemplateProjectIds.normalizeServerId(
      effect?.presetId,
    );
    if (effectPresetId != null) {
      map['effectPresetId'] = effectPresetId;
      final window = SlotLocalTiming.normalize(
        slotDuration: slotDur,
        startTime: effect!.startTime,
        endTime: effect.endTime,
      );
      map['effectStartTime'] = window.start;
      map['effectEndTime'] = window.end;
      hasOverride = true;
    } else if (effect != null &&
        effect.effectType.isNotEmpty &&
        effect.effectType != 'none') {
      debugPrint(
        'OneShotRender: skip non-UUID effect preset '
        '"${effect.presetId}" (${effect.effectType})',
      );
    }

    return hasOverride ? map : null;
  }

  /// Global export length for gallery one-shot (texts/stickers/audio vs timeline).
  static double _resolveGalleryDurationSeconds(CompositionSession session) {
    var maxEnd = session.timeline.totalDuration;
    for (final t in session.userTexts) {
      maxEnd = math.max(maxEnd, t.endTime);
    }
    for (final s in session.userStickers) {
      maxEnd = math.max(maxEnd, s.endTime ?? maxEnd);
    }
    for (final a in session.resolvedAudioTracks) {
      maxEnd = math.max(maxEnd, a.endTime ?? maxEnd);
    }
    final audio = session.userAudioTiming;
    if (audio?.endTime != null) {
      maxEnd = math.max(maxEnd, audio!.endTime!);
    }
    return maxEnd > 0 ? maxEnd : 5.0;
  }

  static Map<String, dynamic> _buildText(UserEditorTextOverlay t) {
    return {
      'text': t.text.trim(),
      'fontSize': t.fontSize.clamp(12, 120),
      'color': t.color,
      'positionX': t.positionX,
      'positionY': t.positionY,
      'startTime': t.startTime,
      'endTime': t.endTime,
      if (t.animationIn != null && t.animationIn!.isNotEmpty)
        'animationIn': t.animationIn,
      if (t.animationOut != null && t.animationOut!.isNotEmpty)
        'animationOut': t.animationOut,
      if (VideoTemplateProjectIds.normalizeServerId(t.fontAssetId) != null)
        'fontAssetId': VideoTemplateProjectIds.normalizeServerId(t.fontAssetId),
    };
  }

  /// Music + effect/filter start/end mirrored into `texts[]` for server scheduling.
  static List<Map<String, dynamic>> _buildScheduleTexts(
    CompositionSession session,
  ) {
    final total = session.timeline.totalDuration;
    final out = <Map<String, dynamic>>[];

    for (final track in session.resolvedAudioTracks) {
      final end = track.endTime ?? total;
      out.add(
        _scheduleAsText(
          label: track.timelineLabel(totalDuration: total),
          startTime: track.startTime,
          endTime: end,
          kind: 'music',
        ),
      );
    }

    var cursor = 0.0;
    for (final slot in session.slots) {
      final fill = session.fills[slot.id];
      final slotDur = UserProjectSlotMapper.resolveSlotDuration(slot, fill);
      final slotStart = cursor;

      final filter = session.slotFilterOverrides[slot.id];
      if (filter != null &&
          filter.filterName.isNotEmpty &&
          filter.filterName != 'none') {
        final window = SlotLocalTiming.normalize(
          slotDuration: slotDur,
          startTime: filter.startTime,
          endTime: filter.endTime,
        );
        final globalStart = slotStart + window.start;
        final globalEnd = slotStart + window.end;
        out.add(
          _scheduleAsText(
            label:
                '${filter.filterName} · ${formatEditorSeconds(globalStart)}–${formatEditorSeconds(globalEnd)}',
            startTime: globalStart,
            endTime: globalEnd,
            kind: 'filter',
          ),
        );
      }

      final effect = session.slotEffectOverrides[slot.id];
      if (effect != null &&
          effect.effectType.isNotEmpty &&
          effect.effectType != 'none') {
        final window = SlotLocalTiming.normalize(
          slotDuration: slotDur,
          startTime: effect.startTime,
          endTime: effect.endTime,
        );
        final globalStart = slotStart + window.start;
        final globalEnd = slotStart + window.end;
        out.add(
          _scheduleAsText(
            label:
                '${effect.effectType} · ${formatEditorSeconds(globalStart)}–${formatEditorSeconds(globalEnd)}',
            startTime: globalStart,
            endTime: globalEnd,
            kind: 'effect',
          ),
        );
      }
      cursor += slotDur;
    }

    return out;
  }

  static Map<String, dynamic> _scheduleAsText({
    required String label,
    required double startTime,
    required double endTime,
    required String kind,
  }) {
    final prefix = switch (kind) {
      'music' => '🎵 ',
      'filter' => '🎨 ',
      _ => '✨ ',
    };
    return {
      'text': '$prefix$label',
      'fontSize': 12,
      'color': '#FFFFFF',
      'positionX': 0,
      'positionY': 920,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  static Map<String, dynamic> _buildAudioTrack(UserEditorAudioTrack track) {
    final map = <String, dynamic>{
      'startTime': track.startTime,
      if (track.endTime != null) 'endTime': track.endTime,
    };
    final segmentId = VideoTemplateProjectIds.normalizeServerId(
      track.soundSegmentId,
    );
    if (segmentId != null) {
      map['soundSegmentId'] = segmentId;
    } else {
      final soundId = VideoTemplateProjectIds.normalizeServerId(track.sound.id);
      if (soundId != null) {
        map['soundId'] = soundId;
        map['soundStartMs'] = track.segmentStartMs;
        if (track.segmentEndMs != null) {
          map['soundEndMs'] = track.segmentEndMs;
        }
      }
    }
    return map;
  }

  static void _applyLegacySoundFields(
    Map<String, dynamic> body,
    UserEditorAudioTrack first,
  ) {
    final segmentId = VideoTemplateProjectIds.normalizeServerId(
      first.soundSegmentId,
    );
    if (segmentId != null) {
      body['soundSegmentId'] = segmentId;
      return;
    }
    final soundId = VideoTemplateProjectIds.normalizeServerId(first.sound.id);
    if (soundId == null) return;
    body['soundId'] = soundId;
    body['soundStartMs'] = first.segmentStartMs;
    if (first.segmentEndMs != null) {
      body['soundEndMs'] = first.segmentEndMs;
    }
  }

  static Map<String, dynamic>? _buildSticker(UserEditorStickerOverlay s) {
    final presetId = VideoTemplateProjectIds.normalizeServerId(s.presetId);
    final assetUrl = s.assetUrl?.trim();
    if (presetId == null && (assetUrl == null || assetUrl.isEmpty)) {
      return null;
    }
    return {
      if (presetId != null) 'presetId': presetId,
      if (assetUrl != null && assetUrl.isNotEmpty)
        'assetUrl': MediaUtils.toServerUploadPath(assetUrl),
      'positionX': s.positionX,
      'positionY': s.positionY,
      'scale': s.scale,
      'rotation': 0,
      'opacity': s.opacity.clamp(0.0, 1.0),
      'startTime': s.startTime,
      if (s.endTime != null) 'endTime': s.endTime,
    };
  }
}
