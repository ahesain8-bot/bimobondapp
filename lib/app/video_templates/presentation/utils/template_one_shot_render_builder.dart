import 'dart:math' as math;



import 'package:bimobondapp/app/video_templates/composition/composition_session.dart';

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';

import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';

import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';

import 'package:bimobondapp/core/utils/media_utils.dart';



/// Builds the JSON body for `POST /video-templates/render` from editor state.

abstract final class TemplateOneShotRenderBuilder {
  /// Remove catalog keys so edited/gallery renders never merge recipe defaults.
  static void stripCatalogTemplateKeys(Map<String, dynamic> body) {
    body.remove('templateId');
    body.remove('videoTemplateId');
    body.remove('catalogTemplateId');
    body.remove('video_template_id');
    body.remove('template_id');
  }

  static Map<String, dynamic> build({

    required CompositionSession session,

    required Map<String, String> slotIdToUploadedUrl,

    String? catalogTemplateId,

    String? title,

    String? exportQuality,

    String? resolution,

    double? fps,

    List<TemplatePresetItem> filterPresets = const [],

    List<TemplatePresetItem> effectPresets = const [],

    bool includeCatalogTemplateId = false,

    /// Gallery / edited export — send exactly what the editor preview shows;

    /// never rely on catalog recipe merge on the server.

    bool explicitEditedExport = false,

  }) {

    final recipe = session.recipe;

    final body = <String, dynamic>{};



    final templateId = includeCatalogTemplateId

        ? VideoTemplateProjectIds.normalizeServerId(catalogTemplateId)

        : null;

    if (templateId != null) {

      body['templateId'] = templateId;

    }

    final galleryMode =

        explicitEditedExport || !includeCatalogTemplateId || templateId == null;



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



      final filtersOwned = session.slotUsesUserFilters(slot.id);

      final effectsOwned = session.slotUsesUserEffects(slot.id);

      final transitionsOwned = session.slotUsesUserTransitions(slot.id);

      final slotFilters = galleryMode

          ? session.previewFiltersForSlot(slot.id)

          : filtersOwned

              ? session.filtersForSlot(slot.id)

              : const <UserEditorFilterTrack>[];

      final slotEffects = galleryMode

          ? session.previewEffectsForSlot(slot.id)

          : effectsOwned

              ? session.effectsForSlot(slot.id)

              : const <UserEditorEffectTrack>[];

      final slotTransition = galleryMode

          ? session

              .previewTransitions()

              .where((t) => t.slotId == slot.id)

              .firstOrNull

          : transitionsOwned

              ? session.transitionForSlot(slot.id)

              : null;

      final slotPatch = _buildSlotPatch(

        slotIndex: slot.slotIndex >= 0 ? slot.slotIndex : i,

        fill: fill,

        slot: slot,

        filters: slotFilters,

        effects: slotEffects,

        transition: slotTransition,

        filtersOwned: filtersOwned,

        effectsOwned: effectsOwned,

        transitionsOwned: transitionsOwned,

        includeFilters: galleryMode || filtersOwned,

        includeEffects: galleryMode || effectsOwned,

        includeTransitions: galleryMode || transitionsOwned,

        filterPresets: filterPresets,

        effectPresets: effectPresets,

        forceInclude: galleryMode,

      );

      if (slotPatch != null) slots.add(slotPatch);

    }



    if (media.isNotEmpty) {

      body['media'] = media;

    }



    if (slots.isNotEmpty) {

      body['slots'] = slots;

    }



    final exportTransitions = <Map<String, dynamic>>[];

    for (var i = 0; i < session.slots.length - 1; i++) {

      final slot = session.slots[i];

      final owned = session.slotUsesUserTransitions(slot.id);

      if (!galleryMode && !owned) continue;

      final track = galleryMode

          ? session

              .previewTransitions()

              .where((t) => t.slotId == slot.id)

              .firstOrNull

          : session.transitionForSlot(slot.id);

      final slotIndex = slot.slotIndex >= 0 ? slot.slotIndex : i;

      if (track == null ||

          track.transitionType.isEmpty ||

          track.transitionType == 'none' ||

          track.transitionType == 'cut') {

        if (owned) {

          exportTransitions.add({

            'afterSlotIndex': slotIndex,

            'transitionType': 'cut',

            'durationSeconds': 0,

          });

        }

        continue;

      }

      exportTransitions.add({

        'afterSlotIndex': slotIndex,

        'transitionType': track.transitionType,

        'durationSeconds': track.durationSeconds.clamp(0.05, 2.0),

        if (track.parameters.isNotEmpty) 'parameters': track.parameters,

      });

    }

    if (galleryMode || exportTransitions.isNotEmpty) {

      body['transitions'] = exportTransitions;

    }



    if (galleryMode) {

      final durationSeconds = _resolveGalleryDurationSeconds(session);

      if (durationSeconds > 0) {

        body['durationSeconds'] = durationSeconds;

      }

    }



    final texts = session.userTexts

        .where((t) => t.text.trim().isNotEmpty)

        .map(_buildText)

        .toList(growable: false);



    final stickers = session.userStickers

        .map(_buildSticker)

        .whereType<Map<String, dynamic>>()

        .toList(growable: false);



    if (galleryMode) {

      body['texts'] = texts;

      body['stickers'] = stickers;

      if (session.userSoundCleared) {

        body['audios'] = const [];

      } else {

        final audioTracks = session.resolvedAudioTracks;

        if (audioTracks.isNotEmpty) {

          body['audios'] = audioTracks.map(_buildAudioTrack).toList();

          _applyLegacySoundFields(body, audioTracks.first);

        } else {

          body['audios'] = const [];

        }

      }

    } else {

      if (session.userAudioLayerOwned) {

        if (session.userSoundCleared) {

          body['audios'] = const [];

        } else if (session.userAudios.isNotEmpty) {

          final primaryAudio = session.userAudios.first;

          body['audios'] = [_buildAudioTrack(primaryAudio)];

          _applyLegacySoundFields(body, primaryAudio);

        } else {

          body['audios'] = const [];

        }

      } else if (session.userSoundCleared) {

        body['audios'] = const [];

      } else {

        final audioTracks = session.resolvedAudioTracks;

        if (audioTracks.isNotEmpty) {

          final primaryAudio = audioTracks.first;

          body['audios'] = [_buildAudioTrack(primaryAudio)];

          _applyLegacySoundFields(body, primaryAudio);

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

      }



      if (session.userTextsLayerOwned || texts.isNotEmpty) {

        body['texts'] = texts;

      }



      if (session.userStickersLayerOwned || stickers.isNotEmpty) {

        body['stickers'] = stickers;

      }

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

    if (explicitEditedExport || galleryMode) {
      stripCatalogTemplateKeys(body);
    }

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

    List<UserEditorFilterTrack> filters = const [],

    List<UserEditorEffectTrack> effects = const [],

    UserEditorTransitionTrack? transition,

    bool filtersOwned = false,

    bool effectsOwned = false,

    bool transitionsOwned = false,

    bool includeFilters = false,

    bool includeEffects = false,

    bool includeTransitions = false,

    List<TemplatePresetItem> filterPresets = const [],

    List<TemplatePresetItem> effectPresets = const [],

    bool forceInclude = false,

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



    final exportFilters = <Map<String, dynamic>>[];

    for (final filter in filters) {

      if (filter.filterName.isEmpty || filter.filterName == 'none') continue;

      final presetId = _resolveFilterPresetId(filter, filterPresets);

      final window = SlotLocalTiming.normalize(

        slotDuration: slotDur,

        startTime: filter.startTime,

        endTime: filter.endTime,

      );

      final entry = <String, dynamic>{

        'intensity': filter.intensity.clamp(0.0, 1.0),

        'startTime': window.start,

        'endTime': window.end,

      };

      if (presetId != null) {

        entry['presetId'] = presetId;

      } else {

        entry['filterName'] = filter.filterName;

      }

      exportFilters.add(entry);

    }

    if (includeFilters) {

      map['filters'] = exportFilters;

      if (filtersOwned && exportFilters.isEmpty) {

        map['filterName'] = 'none';

        map['filterIntensity'] = 0;

      } else if (exportFilters.isNotEmpty) {

        final first = exportFilters.first;

        if (first['presetId'] != null) {

          map['filterPresetId'] = first['presetId'];

        } else if (first['filterName'] != null) {

          map['filterName'] = first['filterName'];

        }

        map['filterIntensity'] = first['intensity'];

        map['filterStartTime'] = first['startTime'];

        map['filterEndTime'] = first['endTime'];

      }

      hasOverride = true;

    }



    final exportEffects = <Map<String, dynamic>>[];

    for (final effect in effects) {

      if (effect.effectType.isEmpty || effect.effectType == 'none') continue;

      final presetId = _resolveEffectPresetId(effect, effectPresets);

      final window = SlotLocalTiming.normalize(

        slotDuration: slotDur,

        startTime: effect.startTime,

        endTime: effect.endTime,

      );

      final entry = <String, dynamic>{

        'startTime': window.start,

        'endTime': window.end,

      };

      if (presetId != null) {

        entry['presetId'] = presetId;

      } else {

        entry['effectType'] = effect.effectType;

        if (effect.parameters.isNotEmpty) {

          entry['parameters'] = effect.parameters;

        }

      }

      exportEffects.add(entry);

    }

    if (includeEffects) {

      map['effects'] = exportEffects;

      if (effectsOwned && exportEffects.isEmpty) {

        map['effectType'] = 'none';

      } else if (exportEffects.isNotEmpty) {

        final first = exportEffects.first;

        if (first['presetId'] != null) {

          map['effectPresetId'] = first['presetId'];

        } else if (first['effectType'] != null) {

          map['effectType'] = first['effectType'];

        }

        map['effectStartTime'] = first['startTime'];

        map['effectEndTime'] = first['endTime'];

      }

      hasOverride = true;

    }



    if (includeTransitions) {

      if (transition != null &&

          transition.transitionType.isNotEmpty &&

          transition.transitionType != 'none' &&

          transition.transitionType != 'cut') {

        map['transitionType'] = transition.transitionType;

        map['transitionDurationSeconds'] =

            transition.durationSeconds.clamp(0.05, 2.0);

      } else if (transitionsOwned) {

        map['transitionType'] = 'cut';

        map['transitionDurationSeconds'] = 0;

      }

      hasOverride = true;

    }



    if (hasOverride || forceInclude) return map;

    return null;

  }



  static String? _resolveFilterPresetId(

    UserEditorFilterTrack filter,

    List<TemplatePresetItem> presets,

  ) {

    final direct = VideoTemplateProjectIds.normalizeServerId(filter.presetId);

    if (direct != null) return direct;

    final key = TemplatePresetItem.normalizeFilterPreviewKey(filter.filterName);

    for (final preset in presets) {

      if (preset.kind != TemplatePresetKind.filter) continue;

      if (preset.previewFilterKey == key) {

        return VideoTemplateProjectIds.normalizeServerId(preset.id);

      }

    }

    return null;

  }



  static String? _resolveEffectPresetId(

    UserEditorEffectTrack effect,

    List<TemplatePresetItem> presets,

  ) {

    final direct = VideoTemplateProjectIds.normalizeServerId(effect.presetId);

    if (direct != null) return direct;

    final key = TemplatePresetItem.normalizeEffectPreviewKey(effect.effectType);

    for (final preset in presets) {

      if (preset.kind != TemplatePresetKind.effect) continue;

      if (preset.previewEffectKey == key) {

        return VideoTemplateProjectIds.normalizeServerId(preset.id);

      }

    }

    return null;

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


