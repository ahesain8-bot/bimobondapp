import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/project/local_project_store.dart';
import 'package:bimobondapp/app/video_templates/project/models/user_template_project_draft.dart';
import 'package:bimobondapp/app/video_templates/project/project_media_manager.dart';
import 'package:flutter/foundation.dart';

/// Owns the editable [UserTemplateProjectDraft] and debounced local persistence.
///
/// Preview/export should read from [draft] + template recipe — never from a
/// baked MP4 as source of truth.
class TemplateProjectController extends ChangeNotifier {
  TemplateProjectController({
    required LocalProjectStore store,
    required ProjectMediaManager mediaManager,
    Duration autosaveDelay = const Duration(milliseconds: 750),
  })  : _store = store,
        _media = mediaManager,
        _autosaveDelay = autosaveDelay;

  final LocalProjectStore _store;
  final ProjectMediaManager _media;
  final Duration _autosaveDelay;

  UserTemplateProjectDraft? _draft;
  VideoTemplateRecipeEntity? _recipe;
  Timer? _debounce;
  bool _dirty = false;
  bool _saving = false;

  UserTemplateProjectDraft? get draft => _draft;
  VideoTemplateRecipeEntity? get recipe => _recipe;
  String? get projectId => _draft?.id;
  /// Server UUID only (`POST /video-templates/projects`). Never `local_*`.
  String? get backendProjectId => _draft?.effectiveBackendId;
  bool get hasDraft => _draft != null;
  bool get isDirty => _dirty;

  /// Create or resume a local draft for [selection] / [recipe].
  ///
  /// Pins [VideoTemplateRecipeEntity.version] so later template updates do not
  /// silently change this project.
  ///
  /// Pass only a server UUID in [backendProjectId]. Client `local_*` ids are
  /// ignored so slot PATCH never hits `/projects/local_…`.
  Future<UserTemplateProjectDraft> openOrCreate({
    required VideoTemplateRecipeEntity recipe,
    String? backendProjectId,
    String? title,
  }) async {
    _recipe = recipe;
    final serverId = VideoTemplateProjectIds.normalizeServerId(backendProjectId);
    if (serverId != null) {
      final existing = await _store.getById(serverId);
      if (existing != null) {
        _draft = existing.copyWith(
          backendProjectId: serverId,
          updatedAt: DateTime.now().toUtc(),
        );
        _dirty = false;
        notifyListeners();
        return _draft!;
      }
    }

    final id = serverId ?? _localProjectId();
    final created = UserTemplateProjectDraft.fromRecipe(
      projectId: id,
      recipe: recipe,
      backendProjectId: serverId,
      title: title,
    );
    _draft = created;
    await saveDraftNow();
    notifyListeners();
    return created;
  }

  /// Bind a server project UUID after `POST /video-templates/projects`.
  Future<void> bindServerProjectId(String serverProjectId) async {
    final draft = _draft;
    final serverId = VideoTemplateProjectIds.normalizeServerId(serverProjectId);
    if (draft == null || serverId == null) return;
    _draft = draft.copyWith(
      backendProjectId: serverId,
      updatedAt: DateTime.now().toUtc(),
    );
    await saveDraftNow();
    notifyListeners();
  }

  Future<UserTemplateProjectDraft?> load(String projectId) async {
    final loaded = await _store.getById(projectId);
    if (loaded == null) return null;
    _draft = loaded;
    _dirty = false;
    notifyListeners();
    return loaded;
  }

  /// Import picker/camera files into project storage and bind to slots.
  ///
  /// Identical source paths are imported once and reused across slots so a
  /// single still is not copied N times for an N-slot template.
  Future<void> assignSlotFiles(
    List<File> files, {
    List<bool>? isVideoHints,
  }) async {
    final draft = _draft;
    if (draft == null || files.isEmpty) return;

    final slots = List<UserProjectSlotDraft>.from(draft.slots);
    if (slots.isEmpty) return;

    final importedByPath = <String, ProjectMediaRecord>{};
    for (var i = 0; i < slots.length; i++) {
      final fileIndex = i % files.length;
      final file = files[fileIndex];
      final key = file.absolute.path;
      var record = importedByPath[key];
      if (record == null) {
        final hintedVideo = isVideoHints != null &&
            fileIndex < isVideoHints.length &&
            isVideoHints[fileIndex];
        record = await _media.importFile(
          projectId: draft.id,
          source: file,
          // Detect from file; VIDEO hint for extension-less camera clips.
          // Never force IMAGE from recipe slot type.
          mediaType: hintedVideo ? 'VIDEO' : null,
        );
        importedByPath[key] = record;
      }
      slots[i] = slots[i].copyWith(
        mediaId: record.mediaId,
        mediaType: record.mediaType,
      );
    }

    _draft = draft.copyWith(
      slots: slots,
      updatedAt: DateTime.now().toUtc(),
    );
    _markDirtyAndSchedule();
    notifyListeners();
  }

  Future<void> updateSlot({
    required int slotIndex,
    File? file,
    double? trimStart,
    double? trimEnd,
    double? duration,
    double? speed,
    double? volume,
    double? positionX,
    double? positionY,
    double? scale,
    double? rotation,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
  }) async {
    final draft = _draft;
    if (draft == null) return;
    final i = draft.slots.indexWhere((s) => s.slotIndex == slotIndex);
    if (i < 0) return;

    var slot = draft.slots[i];
    if (file != null) {
      final record = await _media.importFile(
        projectId: draft.id,
        source: file,
        // Detect from file — do not force recipe IMAGE over a video clip.
        mediaType: null,
      );
      slot = slot.copyWith(mediaId: record.mediaId, mediaType: record.mediaType);
    }
    slot = slot.copyWith(
      trimStart: trimStart,
      trimEnd: trimEnd,
      duration: duration,
      speed: speed,
      volume: volume,
      positionX: positionX,
      positionY: positionY,
      scale: scale,
      rotation: rotation,
      cropLeft: cropLeft,
      cropTop: cropTop,
      cropRight: cropRight,
      cropBottom: cropBottom,
    );
    final slots = List<UserProjectSlotDraft>.from(draft.slots);
    slots[i] = slot;
    _draft = draft.copyWith(slots: slots, updatedAt: DateTime.now().toUtc());
    _markDirtyAndSchedule();
    notifyListeners();
  }

  void setAudio(UserProjectAudioDraft? audio) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(
      audio: audio,
      clearAudio: audio == null,
      updatedAt: DateTime.now().toUtc(),
    );
    _markDirtyAndSchedule();
    notifyListeners();
  }

  void setFilters(List<UserProjectFilterDraft> filters) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(
      filters: filters,
      updatedAt: DateTime.now().toUtc(),
    );
    _markDirtyAndSchedule();
    notifyListeners();
  }

  void setEffects(List<UserProjectEffectDraft> effects) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(
      effects: effects,
      updatedAt: DateTime.now().toUtc(),
    );
    _markDirtyAndSchedule();
    notifyListeners();
  }

  void setTexts(List<UserProjectTextDraft> texts) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(texts: texts, updatedAt: DateTime.now().toUtc());
    _markDirtyAndSchedule();
    notifyListeners();
  }

  void setStickers(List<UserProjectStickerDraft> stickers) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(
      stickers: stickers,
      updatedAt: DateTime.now().toUtc(),
    );
    _markDirtyAndSchedule();
    notifyListeners();
  }

  void setOverlays(List<UserProjectOverlayDraft> overlays) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(
      overlays: overlays,
      updatedAt: DateTime.now().toUtc(),
    );
    _markDirtyAndSchedule();
    notifyListeners();
  }

  void setKeyframes(List<UserProjectKeyframeDraft> keyframes) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(
      keyframes: keyframes,
      updatedAt: DateTime.now().toUtc(),
    );
    _markDirtyAndSchedule();
    notifyListeners();
  }

  void setUserModifications(Map<String, dynamic> mods) {
    final draft = _draft;
    if (draft == null) return;
    _draft = draft.copyWith(
      userModifications: mods,
      updatedAt: DateTime.now().toUtc(),
    );
    _markDirtyAndSchedule();
    notifyListeners();
  }

  /// Resolve durable slot files for preview / export (order by slotIndex).
  Future<List<File>> resolveSlotFiles() async {
    final draft = _draft;
    if (draft == null) return const [];
    final ordered = List<UserProjectSlotDraft>.from(draft.slots)
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final files = <File>[];
    for (final slot in ordered) {
      final id = slot.mediaId;
      if (id == null || id.isEmpty) continue;
      final file = await _media.resolveFile(id);
      if (file != null) files.add(file);
    }
    return files;
  }

  /// Map draft slots → [SlotFillEntry] for composition engine.
  Future<Map<String, SlotFillEntry>> buildFills() async {
    final draft = _draft;
    final recipe = _recipe;
    if (draft == null || recipe == null) return {};
    final fills = <String, SlotFillEntry>{};
    for (final slot in draft.slots) {
      final templateSlotId = slot.templateSlotId;
      if (templateSlotId == null || templateSlotId.isEmpty) continue;
      File? file;
      if (slot.mediaId != null) {
        file = await _media.resolveFile(slot.mediaId!);
      }
      fills[templateSlotId] = SlotFillEntry(
        slotId: templateSlotId,
        slotIndex: slot.slotIndex,
        localFile: file,
        userAssetUrl: slot.uploadedUrl,
        mediaKind: slot.mediaType,
        trimStart: slot.trimStart,
        trimEnd: slot.trimEnd,
        speed: slot.speed,
        rotation: slot.rotation,
        scale: slot.scale,
        volume: slot.volume,
      );
    }
    return fills;
  }

  void _markDirtyAndSchedule() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(_autosaveDelay, () {
      unawaited(saveDraftNow());
    });
  }

  /// Persist immediately (app background, navigate away, before export).
  Future<void> saveDraftNow() async {
    _debounce?.cancel();
    final draft = _draft;
    if (draft == null) return;
    if (_saving) {
      _dirty = true;
      return;
    }
    _saving = true;
    try {
      final toSave = draft.copyWith(updatedAt: DateTime.now().toUtc());
      await _store.saveDraft(toSave);
      _draft = toSave;
      _dirty = false;

      final refs = <String>{
        for (final s in toSave.slots)
          if (s.mediaId != null && s.mediaId!.isNotEmpty) s.mediaId!,
        if (toSave.audio?.mediaId != null &&
            toSave.audio!.mediaId!.isNotEmpty)
          toSave.audio!.mediaId!,
      };
      await _media.deleteUnused(
        projectId: toSave.id,
        referencedMediaIds: refs,
      );
    } catch (e, st) {
      debugPrint('TemplateProjectController.saveDraftNow: $e\n$st');
      _dirty = true;
    } finally {
      _saving = false;
      if (_dirty) {
        _debounce?.cancel();
        _debounce = Timer(_autosaveDelay, () {
          unawaited(saveDraftNow());
        });
      }
    }
  }

  Future<void> discard() async {
    _debounce?.cancel();
    final id = _draft?.id;
    _draft = null;
    _recipe = null;
    _dirty = false;
    if (id != null) {
      await _store.deleteProject(id);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty) {
      // Best-effort sync flush — callers should await [saveDraftNow] first.
      unawaited(saveDraftNow());
    }
    super.dispose();
  }

  static String _localProjectId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'local_$ms$r';
  }
}
