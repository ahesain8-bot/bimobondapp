import 'dart:io';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/video_templates/composition/image_media_source.dart';
import 'package:bimobondapp/app/video_templates/composition/media_source.dart';
import 'package:bimobondapp/app/video_templates/composition/video_media_source.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/timeline/timeline_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/validation/template_validator.dart';
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/foundation.dart';

/// Mutable editor session: recipe is immutable; only fills / sources change.
class CompositionSession {
  CompositionSession({
    required this.recipe,
    required this.slotEngine,
    Map<String, SlotFillEntry>? fills,
    this.projectId,
  }) : fills = fills ?? slotEngine.emptyFills();

  final VideoTemplateRecipeEntity recipe;
  final SlotEngine slotEngine;
  Map<String, SlotFillEntry> fills;
  String? projectId;

  /// User overrides — replace admin slot FX in merged preview (guide §5).
  Map<String, UserSlotFilterOverride> slotFilterOverrides = {};
  Map<String, UserSlotEffectOverride> slotEffectOverrides = {};
  List<UserEditorTextOverlay> userTexts = [];
  List<UserEditorStickerOverlay> userStickers = [];
  List<UserEditorAudioTrack> userAudios = [];

  /// Legacy single-track fields — kept in sync with [userAudios.first] for older paths.
  UserEditorAudioTiming? userAudioTiming;
  SoundEntity? userSound;
  bool userSoundCleared = false;
  String? userSoundSegmentId;
  int? userSoundSegmentStartMs;
  int? userSoundSegmentEndMs;

  final Map<String, MediaSource> _sources = {};
  final List<CompositionSession> _undo = [];
  final List<CompositionSession> _redo = [];

  TemplateTimeline? _cachedTimeline;

  List<VideoTemplateSlotEntity> get slots => slotEngine.slots;

  /// Sound used for timeline / export preview (user picks → recipe fallback).
  SoundEntity? get effectiveSound {
    if (userSoundCleared) return null;
    if (userAudios.isNotEmpty) return userAudios.first.sound;
    return userSound ?? recipe.effectivePreviewSound;
  }

  String? get effectiveAudioLabel {
    if (userAudios.isNotEmpty) {
      return userAudios.first.name;
    }
    final sound = effectiveSound;
    if (sound == null) return null;
    final name = sound.name.trim();
    if (name.isNotEmpty) return name;
    return recipe.music?.title;
  }

  /// Tracks for preview + one-shot export (user layers, else recipe default).
  List<UserEditorAudioTrack> get resolvedAudioTracks {
    if (userSoundCleared) return const [];
    if (userAudios.isNotEmpty) return List.unmodifiable(userAudios);
    final sound = recipe.effectivePreviewSound;
    if (sound == null) return const [];
    final dur = timeline.totalDuration;
    return [
      UserEditorAudioTrack(
        id: 'audio_recipe',
        sound: sound,
        soundSegmentId: recipe.soundSegmentId,
        segmentStartMs: recipe.soundSegmentStartMs ?? 0,
        segmentEndMs: recipe.soundSegmentEndMs,
        startTime: userAudioTiming?.startTime ?? 0,
        endTime: userAudioTiming?.endTime ?? dur,
      ),
    ];
  }

  void _syncLegacyAudioFields() {
    if (userAudios.isEmpty) {
      userSound = null;
      userSoundSegmentId = null;
      userSoundSegmentStartMs = null;
      userSoundSegmentEndMs = null;
      userAudioTiming = null;
      return;
    }
    final first = userAudios.first;
    userSound = first.sound;
    userSoundSegmentId = first.soundSegmentId;
    userSoundSegmentStartMs = first.segmentStartMs;
    userSoundSegmentEndMs = first.segmentEndMs;
    userAudioTiming = UserEditorAudioTiming(
      startTime: first.startTime,
      endTime: first.endTime,
    );
  }

  TemplateTimeline get timeline {
    return _cachedTimeline ??= const TimelineEngine().build(
      recipe: recipe,
      fills: fills,
      slotFilterOverrides: slotFilterOverrides,
      slotEffectOverrides: slotEffectOverrides,
      userTexts: userTexts,
      userStickers: userStickers,
      userAudios: userAudios,
      userAudioTiming: userAudioTiming,
      userSound: userSoundCleared ? null : userSound,
      clearRecipeSound: userSoundCleared,
      userSoundSegmentStartMs: userSoundSegmentStartMs,
      userSoundSegmentEndMs: userSoundSegmentEndMs,
    );
  }

  void _invalidateTimeline() => _cachedTimeline = null;

  MediaSource? sourceFor(String slotId) => _sources[slotId];

  Map<String, MediaSource> get sources => Map.unmodifiable(_sources);

  /// Snapshot for undo (fills only — MediaSources rebuilt on restore).
  CompositionSession _cloneFills() {
    return CompositionSession(
        recipe: recipe,
        slotEngine: slotEngine,
        fills: Map<String, SlotFillEntry>.from(
          fills.map((k, v) => MapEntry(k, v)),
        ),
        projectId: projectId,
      )
      ..slotFilterOverrides = Map<String, UserSlotFilterOverride>.from(
        slotFilterOverrides,
      )
      ..slotEffectOverrides = Map<String, UserSlotEffectOverride>.from(
        slotEffectOverrides,
      )
      ..userTexts = List<UserEditorTextOverlay>.from(userTexts)
      ..userStickers = List<UserEditorStickerOverlay>.from(userStickers)
      ..userAudios = List<UserEditorAudioTrack>.from(userAudios)
      ..userAudioTiming = userAudioTiming
      ..userSound = userSound
      ..userSoundCleared = userSoundCleared
      ..userSoundSegmentId = userSoundSegmentId
      ..userSoundSegmentStartMs = userSoundSegmentStartMs
      ..userSoundSegmentEndMs = userSoundSegmentEndMs;
  }

  void addUserAudio(UserEditorAudioTrack track) {
    _pushUndo();
    userSoundCleared = false;
    userAudios = [...userAudios, track];
    _syncLegacyAudioFields();
    _invalidateTimeline();
  }

  void removeUserAudio(String id) {
    final i = userAudios.indexWhere((a) => a.id == id);
    if (i < 0) return;
    _pushUndo();
    userAudios = List<UserEditorAudioTrack>.from(userAudios)..removeAt(i);
    if (userAudios.isEmpty) {
      userSoundCleared = false;
    }
    _syncLegacyAudioFields();
    _invalidateTimeline();
  }

  void clearUserAudios() {
    _pushUndo();
    userAudios = [];
    userSoundCleared = true;
    userSound = null;
    userSoundSegmentId = null;
    userSoundSegmentStartMs = null;
    userSoundSegmentEndMs = null;
    userAudioTiming = null;
    _invalidateTimeline();
  }

  void setUserSound(
    SoundEntity? sound, {
    String? soundSegmentId,
    int? segmentStartMs,
    int? segmentEndMs,
    double? timelineStart,
    double? timelineEnd,
  }) {
    if (sound == null) {
      clearUserAudios();
      return;
    }
    addUserAudio(
      UserEditorAudioTrack(
        id: 'audio_${DateTime.now().microsecondsSinceEpoch}',
        sound: sound,
        soundSegmentId: soundSegmentId,
        segmentStartMs: segmentStartMs ?? 0,
        segmentEndMs: segmentEndMs,
        startTime: timelineStart ?? 0,
        endTime: timelineEnd,
      ),
    );
  }

  void patchUserAudioTiming({
    required String id,
    required double startTime,
    required double endTime,
  }) {
    final i = userAudios.indexWhere((a) => a.id == id);
    if (i < 0) {
      // Legacy single-track bar (`audio_main`) before any explicit add.
      userAudioTiming = UserEditorAudioTiming(
        startTime: startTime,
        endTime: endTime,
      );
      _invalidateTimeline();
      return;
    }
    userAudios[i] = userAudios[i].copyWith(
      startTime: startTime,
      endTime: endTime,
    );
    _syncLegacyAudioFields();
    _invalidateTimeline();
  }

  void patchUserAudioTimingLegacy({
    required double startTime,
    required double endTime,
  }) {
    patchUserAudioTiming(
      id: userAudios.isNotEmpty ? userAudios.first.id : 'audio_main',
      startTime: startTime,
      endTime: endTime,
    );
  }

  void setSlotFilter(String slotId, UserSlotFilterOverride? override) {
    _pushUndo();
    if (override == null || override.filterName == 'none') {
      slotFilterOverrides.remove(slotId);
    } else {
      slotFilterOverrides[slotId] = override;
    }
    _invalidateTimeline();
  }

  void setSlotEffect(String slotId, UserSlotEffectOverride? override) {
    _pushUndo();
    if (override == null || override.effectType == 'none') {
      slotEffectOverrides.remove(slotId);
    } else {
      slotEffectOverrides[slotId] = override;
    }
    _invalidateTimeline();
  }

  void setUserTexts(List<UserEditorTextOverlay> texts) {
    _pushUndo();
    userTexts = List<UserEditorTextOverlay>.from(texts);
    _invalidateTimeline();
  }

  void setUserStickers(List<UserEditorStickerOverlay> stickers) {
    _pushUndo();
    userStickers = List<UserEditorStickerOverlay>.from(stickers);
    _invalidateTimeline();
  }

  /// Live timing tweak (no undo) — used while dragging overlay handles.
  void patchSlotFilterTiming(
    String slotId, {
    required double startTime,
    required double endTime,
  }) {
    final current = slotFilterOverrides[slotId];
    if (current == null) return;
    slotFilterOverrides[slotId] = current.copyWith(
      startTime: startTime,
      endTime: endTime,
    );
    _invalidateTimeline();
  }

  void patchSlotEffectTiming(
    String slotId, {
    required double startTime,
    required double endTime,
  }) {
    final current = slotEffectOverrides[slotId];
    if (current == null) return;
    slotEffectOverrides[slotId] = current.copyWith(
      startTime: startTime,
      endTime: endTime,
    );
    _invalidateTimeline();
  }

  void patchUserTextTiming(
    String id, {
    required double startTime,
    required double endTime,
  }) {
    final i = userTexts.indexWhere((t) => t.id == id);
    if (i < 0) return;
    userTexts[i] = userTexts[i].copyWith(
      startTime: startTime,
      endTime: endTime,
    );
    _invalidateTimeline();
  }

  /// Live layout tweak while dragging / pinching captions (no undo).
  void patchUserTextLayout(
    String id, {
    double? positionX,
    double? positionY,
    double? fontSize,
  }) {
    final i = userTexts.indexWhere((t) => t.id == id);
    if (i < 0) return;
    userTexts[i] = userTexts[i].copyWith(
      positionX: positionX,
      positionY: positionY,
      fontSize: fontSize,
    );
    _invalidateTimeline();
  }

  void patchUserStickerTiming(
    String id, {
    required double startTime,
    required double endTime,
  }) {
    final i = userStickers.indexWhere((s) => s.id == id);
    if (i < 0) return;
    userStickers[i] = userStickers[i].copyWith(
      startTime: startTime,
      endTime: endTime,
    );
    _invalidateTimeline();
  }

  /// Live layout tweak while dragging / pinching stickers (no undo).
  void patchUserStickerLayout(
    String id, {
    double? positionX,
    double? positionY,
    double? scale,
  }) {
    final i = userStickers.indexWhere((s) => s.id == id);
    if (i < 0) return;
    userStickers[i] = userStickers[i].copyWith(
      positionX: positionX,
      positionY: positionY,
      scale: scale,
    );
    _invalidateTimeline();
  }

  void _pushUndo() {
    _undo.add(_cloneFills());
    if (_undo.length > 30) _undo.removeAt(0);
    _redo.clear();
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot());
    _restore(_undo.removeLast());
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot());
    _restore(_redo.removeLast());
  }

  CompositionSession _snapshot() => _cloneFills();

  void _restore(CompositionSession snap) {
    fills = snap.fills;
    slotFilterOverrides = Map<String, UserSlotFilterOverride>.from(
      snap.slotFilterOverrides,
    );
    slotEffectOverrides = Map<String, UserSlotEffectOverride>.from(
      snap.slotEffectOverrides,
    );
    userTexts = List<UserEditorTextOverlay>.from(snap.userTexts);
    userStickers = List<UserEditorStickerOverlay>.from(snap.userStickers);
    userAudios = List<UserEditorAudioTrack>.from(snap.userAudios);
    userAudioTiming = snap.userAudioTiming;
    userSound = snap.userSound;
    userSoundCleared = snap.userSoundCleared;
    userSoundSegmentId = snap.userSoundSegmentId;
    userSoundSegmentStartMs = snap.userSoundSegmentStartMs;
    userSoundSegmentEndMs = snap.userSoundSegmentEndMs;
    _invalidateTimeline();
    _rebuildSourcesSync();
  }

  Future<void> assignFile(String slotId, File file, {String? mediaKind}) async {
    VideoTemplateSlotEntity? slot;
    for (final s in slots) {
      if (s.id == slotId) {
        slot = s;
        break;
      }
    }
    if (slot == null) return;
    _pushUndo();
    final prev = fills[slotId];
    final kind =
        mediaKind?.trim().toUpperCase() ??
        (VideoThumbnailUtils.isVideoFile(file) ? 'VIDEO' : 'IMAGE');
    fills[slotId] = SlotFillEntry(
      slotId: slotId,
      slotIndex: slot.slotIndex,
      localFile: file,
      mediaKind: kind,
      userAssetUrl: prev?.userAssetUrl,
      trimStart: prev?.trimStart,
      trimEnd: prev?.trimEnd,
      speed: prev?.speed ?? 1,
      rotation: prev?.rotation ?? 0,
      scale: prev?.scale ?? 1,
      volume: prev?.volume ?? 1,
    );
    fills = slotEngine.applyBeatSyncTrims(fills);
    _invalidateTimeline();
    await _replaceSource(slot, fills[slotId]!);
  }

  Future<void> clearSlot(String slotId) async {
    _pushUndo();
    final prev = fills[slotId];
    if (prev == null) return;
    fills[slotId] = SlotFillEntry(
      slotId: prev.slotId,
      slotIndex: prev.slotIndex,
    );
    await _sources.remove(slotId)?.dispose();
    _invalidateTimeline();
  }

  Future<void> replaceAllFromFiles(List<File> files) async {
    _pushUndo();
    fills = slotEngine.fillFromFiles(files);
    fills = slotEngine.applyBeatSyncTrims(fills);
    _invalidateTimeline();
    await prepareSources();
  }

  Future<void> _replaceSource(
    VideoTemplateSlotEntity slot,
    SlotFillEntry fill,
  ) async {
    await _sources.remove(slot.id)?.dispose();
    final file = fill.localFile;
    if (file == null) return;
    final source = MediaSource.fromFill(slot: slot, fill: fill, file: file);
    try {
      await source.prepare();
      _sources[slot.id] = source;
    } catch (e, st) {
      debugPrint('CompositionSession source prepare: $e\n$st');
      await source.dispose();
      // Image decode often fails for video files mis-tagged as IMAGE — retry
      // as VideoMediaSource so preview is not blank.
      if (source is! VideoMediaSource) {
        try {
          final videoFill = fill.copyWith(mediaKind: 'VIDEO');
          final video = MediaSource.fromFill(
            slot: slot,
            fill: videoFill,
            file: file,
          );
          await video.prepare();
          _sources[slot.id] = video;
          debugPrint(
            'CompositionSession: recovered ${slot.id} as VIDEO source',
          );
        } catch (e2, st2) {
          debugPrint('CompositionSession video recovery: $e2\n$st2');
        }
      }
    }
  }

  void _rebuildSourcesSync() {
    // Dispose stale; prepare async via prepareSources().
    for (final s in _sources.values) {
      s.dispose();
    }
    _sources.clear();
  }

  Future<void> prepareSources() async {
    for (final s in _sources.values) {
      await s.dispose();
    }
    _sources.clear();

    // Decode each unique still once; clone for extra slots that share a file.
    final preparedByPath = <String, MediaSource>{};
    for (final slot in slots) {
      final fill = fills[slot.id];
      final file = fill?.localFile;
      if (fill == null || file == null) continue;

      final path = file.absolute.path;
      final cached = preparedByPath[path];
      if (cached is ImageMediaSource && cached.isPrepared) {
        final holdSeconds = UserProjectSlotMapper.resolveSlotDuration(
          slot,
          fill,
        );
        final shared = await ImageMediaSource.sharePrepared(
          cached,
          id: slot.id,
          holdDuration: Duration(
            milliseconds: (holdSeconds * 1000).round().clamp(200, 30000),
          ),
        );
        _sources[slot.id] = shared;
        continue;
      }

      await _replaceSource(slot, fill);
      final created = _sources[slot.id];
      if (created != null) preparedByPath[path] = created;
    }
  }

  TemplateValidationReport validate() {
    return const TemplateValidator().validate(recipe: recipe, fills: fills);
  }

  Future<void> dispose() async {
    for (final s in _sources.values) {
      await s.dispose();
    }
    _sources.clear();
  }
}
