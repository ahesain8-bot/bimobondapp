import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_file.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_pick_result.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_sheet.dart';
import 'package:bimobondapp/app/video_templates/composition/composition_preview_controller.dart';
import 'package:bimobondapp/app/video_templates/composition/composition_session.dart';
import 'package:bimobondapp/app/video_templates/composition/template_composition_engine.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/repositories/video_templates_repository.dart';
import 'package:bimobondapp/app/video_templates/domain/usecases/video_templates_usecases.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as vt_di;
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_font_cache.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_playback_bar.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_preset_sheet.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_sticker_placer_sheet.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_text_sheet.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_timeline.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_toolbar.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_user_sticker_gesture_layer.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_user_text_gesture_layer.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/video_template_composed_preview.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

/// TikTok-style template editor: preview, timeline, edit sheet, export.
class VideoTemplateEditorScreen extends StatefulWidget {
  const VideoTemplateEditorScreen({
    super.key,
    required this.recipe,
    this.card,
    this.initialSelection,
    this.initialFills,
    this.projectId,
    this.editable,
    /// Catalog shelf UUID only — omit for gallery / free edit (media[] flow).
    this.catalogTemplateId,
  });

  final VideoTemplateRecipeEntity recipe;
  final VideoTemplateCardEntity? card;
  final VideoTemplateSelection? initialSelection;
  final Map<String, SlotFillEntry>? initialFills;
  final String? projectId;
  final TemplateEditableFlags? editable;
  final String? catalogTemplateId;

  @override
  State<VideoTemplateEditorScreen> createState() =>
      _VideoTemplateEditorScreenState();
}

class _VideoTemplateEditorScreenState extends State<VideoTemplateEditorScreen> {
  late final TemplateCompositionEngine _engine;
  late final VideoTemplatesRepository _repository;
  late CompositionSession _session;
  CompositionPreviewController? _preview;
  late TemplateEditableFlags _editable;

  bool _busy = false;
  String? _error;
  double _exportProgress = 0;
  String _exportLabel = 'Rendering…';
  int _selectedSlotIndex = 0;
  TemplateEditorPanel? _activePanel;
  String? _serverProjectId;
  /// Maps recipe slot id → server `slots[].slotId` for PATCH / filters / effects.
  final Map<String, String> _serverSlotIdsByRecipeSlot = {};

  /// After backend export completes, preview the rendered MP4 before Next.
  bool _showRenderedPreview = false;
  File? _renderedPreviewFile;
  String? _renderedExportUrl;
  VideoPlayerController? _renderedPlayer;
  VideoTemplateSelection? _pendingFinishSelection;

  List<TemplatePresetItem> _filterPresets = kFallbackFilterPresets;
  List<TemplatePresetItem> _effectPresets = kFallbackEffectPresets;
  List<TemplateFontItem> _fonts = const [];
  Timer? _lookTimingSyncTimer;
  bool _fontsLoading = false;
  List<TemplatePresetItem> _stickerPresets = const [
    TemplatePresetItem(
      id: 'heart',
      name: '❤️',
      kind: TemplatePresetKind.sticker,
      assetUrl: null,
    ),
    TemplatePresetItem(
      id: 'star',
      name: '⭐',
      kind: TemplatePresetKind.sticker,
      assetUrl: null,
    ),
    TemplatePresetItem(
      id: 'fire',
      name: '🔥',
      kind: TemplatePresetKind.sticker,
      assetUrl: null,
    ),
    TemplatePresetItem(
      id: 'sparkle',
      name: '✨',
      kind: TemplatePresetKind.sticker,
      assetUrl: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _engine = vt_di.sl<TemplateCompositionEngine>();
    _repository = vt_di.sl<VideoTemplatesRepository>();
    _editable = widget.editable ?? const TemplateEditableFlags();
    _serverProjectId = _catalogTemplateIdForRender != null
        ? VideoTemplateProjectIds.normalizeServerId(
            widget.projectId ?? widget.initialSelection?.projectId,
          )
        : null;
    _session = _engine.open(widget.recipe, projectId: _serverProjectId);
    if (widget.initialFills != null) {
      _session.fills = Map<String, SlotFillEntry>.from(widget.initialFills!);
    }
    _bootstrap();
    unawaited(_loadPresets());
    unawaited(_loadFonts());
  }

  Future<void> _bootstrap() async {
    await _session.prepareSources();
    final preview = CompositionPreviewController(
      engine: _engine,
      session: _session,
    );
    await preview.attach();
    if (!mounted) {
      preview.dispose();
      return;
    }
    setState(() => _preview = preview);
    if (_session.effectiveSound != null && _session.userAudioTiming == null) {
      final total = max(preview.duration, 0.01);
      _session.patchUserAudioTimingLegacy(startTime: 0, endTime: total);
    }
  }

  void _applyServerProject(VideoTemplateProjectEntity project) {
    _serverProjectId = project.id;
    _session.projectId = project.id;
    _serverSlotIdsByRecipeSlot.clear();
    final recipeSlots = _session.slots;
    for (final ps in project.slots) {
      final patchId = ps.patchSlotId;
      if (!VideoTemplateProjectIds.isServerId(patchId)) continue;
      final idx = ps.slotIndex;
      if (idx >= 0 && idx < recipeSlots.length) {
        _serverSlotIdsByRecipeSlot[recipeSlots[idx].id] = patchId;
      }
    }
    if (project.editable != null) {
      _editable = project.editable!;
    }
  }

  String? _serverSlotIdFor(String recipeSlotId) {
    final mapped = _serverSlotIdsByRecipeSlot[recipeSlotId];
    if (mapped != null && VideoTemplateProjectIds.isServerId(mapped)) {
      return mapped;
    }
    if (VideoTemplateProjectIds.isServerId(recipeSlotId)) return recipeSlotId;
    return null;
  }

  /// Catalog shelf UUID from [catalogTemplateId] only — never recipe/selection/card.
  String? get _catalogTemplateIdForRender {
    return VideoTemplateProjectIds.normalizeServerId(widget.catalogTemplateId);
  }

  Future<void> _loadFonts() async {
    if (mounted) setState(() => _fontsLoading = true);
    final result = await _repository.listFonts();
    if (!mounted) return;
    result.fold(
      (_) {
        setState(() => _fontsLoading = false);
      },
      (list) {
        setState(() {
          _fonts = list;
          _fontsLoading = false;
        });
        for (final font in list) {
          unawaited(
            TemplateFontCache.load(fontAssetId: font.id, url: font.url),
          );
        }
      },
    );
  }

  Future<void> _loadPresets() async {
    final projectId = _serverProjectId;
    final filters = await _repository.listPresets(
      kind: 'FILTER',
      projectId: projectId,
    );
    final effects = await _repository.listPresets(
      kind: 'EFFECT',
      projectId: projectId,
    );
    final stickers = await _repository.listPresets(
      kind: 'STICKER',
      projectId: projectId,
    );
    if (!mounted) return;
    setState(() {
      filters.fold((_) {}, (list) {
        if (list.isNotEmpty) _filterPresets = list;
      });
      effects.fold((_) {}, (list) {
        if (list.isNotEmpty) _effectPresets = list;
      });
      stickers.fold((_) {}, (list) {
        if (list.isNotEmpty) _stickerPresets = list;
      });
    });
  }

  @override
  void dispose() {
    _lookTimingSyncTimer?.cancel();
    unawaited(SoundAudioPreview.stop());
    unawaited(_renderedPlayer?.dispose());
    _preview?.dispose();
    _session.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    _preview?.pause();
    await SoundAudioPreview.stop();
    if (!mounted) return;

    SoundPickResult? picked;
    try {
      picked = await SoundPickerSheet.show(
        context,
        initialSelection: _session.effectiveSound,
        initialOffset: Duration(
          milliseconds:
              _session.userSoundSegmentStartMs ??
              widget.recipe.soundSegmentStartMs ??
              0,
        ),
        allowMuteOnTrim: true,
      );
    } catch (_) {
      picked = null;
    }
    if (!mounted) return;
    await SoundAudioPreview.stop();

    if (picked == null) {
      setState(() => _activePanel = null);
      return;
    }

    if (picked.cleared) {
      _session.clearUserAudios();
      await _refreshPreview();
      setState(() => _activePanel = null);
      return;
    }

    final sound = picked.sound;
    if (sound == null) {
      setState(() => _activePanel = null);
      return;
    }

    final total = max(_preview?.duration ?? widget.recipe.duration ?? 5, 0.01);
    final playhead = (_preview?.playhead ?? 0).clamp(0.0, total);
    final clip = picked.clipRangeMs;
    _session.addUserAudio(
      UserEditorAudioTrack(
        id: 'audio_${DateTime.now().microsecondsSinceEpoch}',
        sound: sound,
        soundSegmentId: picked.soundSegmentId,
        segmentStartMs: clip?.startMs ?? picked.offset.inMilliseconds,
        segmentEndMs:
            clip?.endMs ?? (picked.offset + picked.window).inMilliseconds,
        startTime: playhead,
        endTime: total,
      ),
    );

    final url = sound.resolvedAudioUrl;
    if (url.isNotEmpty) {
      unawaited(SoundLocalFile.resolve(url));
    }

    await _refreshPreview();
    setState(() => _activePanel = null);
  }

  VideoTemplateRecipeEntity _recipeWithEditorSound() {
    final base = widget.recipe;
    if (_session.userSoundCleared) {
      return VideoTemplateRecipeEntity(
        id: base.id,
        name: base.name,
        templateKind: base.templateKind,
        primarySlotType: base.primarySlotType,
        allowedOutputs: base.allowedOutputs,
        slotCount: base.slotCount,
        coverUrl: base.coverUrl,
        previewVideoUrl: base.previewVideoUrl,
        duration: base.duration,
        width: base.width,
        height: base.height,
        fps: base.fps,
        version: base.version,
        versionInfo: base.versionInfo,
        useCount: base.useCount,
        categoryId: base.categoryId,
        category: base.category,
        musicId: null,
        music: null,
        soundId: null,
        sound: null,
        soundSegmentId: null,
        soundSegmentStartMs: null,
        soundSegmentEndMs: null,
        slots: base.slots,
        beatMap: base.beatMap,
        transitions: base.transitions,
        tracks: base.tracks,
        clips: base.clips,
        texts: base.texts,
        stickers: base.stickers,
        overlays: base.overlays,
        assets: base.assets,
        keyframes: base.keyframes,
        renderHints: base.renderHints,
      );
    }
    final sound = _session.userSound;
    if (sound == null) return base;
    return VideoTemplateRecipeEntity(
      id: base.id,
      name: base.name,
      templateKind: base.templateKind,
      primarySlotType: base.primarySlotType,
      allowedOutputs: base.allowedOutputs,
      slotCount: base.slotCount,
      coverUrl: base.coverUrl,
      previewVideoUrl: base.previewVideoUrl,
      duration: base.duration,
      width: base.width,
      height: base.height,
      fps: base.fps,
      version: base.version,
      versionInfo: base.versionInfo,
      useCount: base.useCount,
      categoryId: base.categoryId,
      category: base.category,
      musicId: base.musicId,
      music: base.music,
      soundId: sound.id,
      sound: sound,
      soundSegmentId: _session.userSoundSegmentId,
      soundSegmentStartMs: _session.userSoundSegmentStartMs,
      soundSegmentEndMs: _session.userSoundSegmentEndMs,
      slots: base.slots,
      beatMap: base.beatMap,
      transitions: base.transitions,
      tracks: base.tracks,
      clips: base.clips,
      texts: base.texts,
      stickers: base.stickers,
      overlays: base.overlays,
      assets: base.assets,
      keyframes: base.keyframes,
      renderHints: base.renderHints,
    );
  }

  VideoTemplateSlotEntity get _selectedSlot {
    final slots = _session.slots;
    final i = _selectedSlotIndex.clamp(0, slots.length - 1);
    return slots[i];
  }

  String? get _selectedFilterId {
    final override = _session.slotFilterOverrides[_selectedSlot.id];
    return override?.presetId ?? override?.filterName;
  }

  String? get _selectedEffectId {
    final override = _session.slotEffectOverrides[_selectedSlot.id];
    return override?.presetId ?? override?.effectType;
  }

  UserSlotFilterOverride? _filterOverrideForPreview(
    CompositionPreviewController preview,
  ) {
    final slotId = preview.activeSlotId ?? _selectedSlot.id;
    return _session.slotFilterOverrides[slotId];
  }

  bool _isFilterActiveAtPlayhead(
    CompositionPreviewController preview,
    String slotId,
  ) {
    final filter = _session.slotFilterOverrides[slotId];
    if (filter == null ||
        filter.filterName.isEmpty ||
        filter.filterName == 'none') {
      return false;
    }
    final local = preview.playhead - _slotStartOnTimeline(slotId);
    return SlotLocalTiming.containsLocalTime(
      slotDuration: _slotDuration(slotId),
      localTime: local,
      startTime: filter.startTime,
      endTime: filter.endTime,
    );
  }

  bool _isEffectActiveAtPlayhead(
    CompositionPreviewController preview,
    String slotId,
  ) {
    final effect = _session.slotEffectOverrides[slotId];
    if (effect == null ||
        effect.effectType.isEmpty ||
        effect.effectType == 'none') {
      return false;
    }
    final local = preview.playhead - _slotStartOnTimeline(slotId);
    return SlotLocalTiming.containsLocalTime(
      slotDuration: _slotDuration(slotId),
      localTime: local,
      startTime: effect.startTime,
      endTime: effect.endTime,
    );
  }

  Widget _buildComposedPreview({
    required CompositionPreviewController preview,
    required num canvasW,
    required num canvasH,
    bool showTexts = true,
  }) {
    final slotId = preview.activeSlotId ?? _selectedSlot.id;
    final filterOverride = _filterOverrideForPreview(preview);
    final filterActive =
        filterOverride != null && _isFilterActiveAtPlayhead(preview, slotId);
    return VideoTemplateComposedPreview(
      canvasWidth: canvasW.round(),
      canvasHeight: canvasH.round(),
      frame: preview.frame,
      videoController: preview.videoController,
      imageFile: preview.imageFile,
      decodedImage: preview.decodedImage,
      isVideoMedia: preview.activeSlotIsVideo || preview.hasVideoSurface,
      videoLookStill: preview.videoLookStill,
      useVideoLookStill: _shouldUseVideoLookStill(preview),
      fallbackFilterName: filterActive ? filterOverride!.filterName : null,
      fallbackFilterIntensity: filterOverride?.intensity ?? 1,
      showTexts: showTexts,
    );
  }

  bool _shouldUseVideoLookStill(CompositionPreviewController preview) {
    if (!preview.activeSlotIsVideo && !preview.hasVideoSurface) return false;
    final slotId = preview.activeSlotId ?? _selectedSlot.id;
    return _isFilterActiveAtPlayhead(preview, slotId) ||
        _isEffectActiveAtPlayhead(preview, slotId);
  }

  Future<void> _refreshPreview({bool reattachMedia = false}) async {
    final preview = _preview;
    if (preview == null) return;
    if (reattachMedia) {
      await preview.attach();
    } else {
      preview.reloadTimeline();
      await preview.seek(preview.playhead);
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickMediaForSlot(int slotIndex) async {
    final slot = _session.slots[slotIndex];
    final acceptsVideo = slot.acceptsVideo;
    final acceptsImage = slot.acceptsImage;

    final file = await _pickSingleMedia(
      acceptsVideo: acceptsVideo,
      acceptsImage: acceptsImage,
    );
    if (!mounted || file == null) return;

    setState(() => _selectedSlotIndex = slotIndex);
    await _session.assignFile(slot.id, file.file, mediaKind: file.type);
    await _refreshPreview(reattachMedia: true);
  }

  Future<GalleryMediaItem?> _pickSingleMedia({
    required bool acceptsVideo,
    required bool acceptsImage,
  }) async {
    List<GalleryMediaItem> items;
    if (acceptsVideo && acceptsImage) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: TemplateEditorTheme.panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.image, color: Colors.white),
                title: const Text(
                  'Photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(ctx, 'image'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.video, color: Colors.white),
                title: const Text(
                  'Video',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(ctx, 'video'),
              ),
            ],
          ),
        ),
      );
      if (choice == null) return null;
      items = choice == 'video'
          ? await MediaGalleryPicker.pickVideos(limit: 1)
          : await MediaGalleryPicker.pickImages(limit: 1);
    } else if (acceptsVideo) {
      items = await MediaGalleryPicker.pickVideos(limit: 1);
    } else {
      items = await MediaGalleryPicker.pickImages(limit: 1);
    }
    if (items.isEmpty) return null;
    return items.first;
  }

  void _togglePanel(TemplateEditorPanel panel) {
    setState(() {
      _activePanel = _activePanel == panel ? null : panel;
    });
  }

  Future<void> _applyFilter(TemplatePresetItem preset) async {
    final slot = _selectedSlot;
    if (preset.isClear) {
      _session.setSlotFilter(slot.id, null);
    } else {
      final slotDur = _slotDuration(slot.id);
      _session.setSlotFilter(
        slot.id,
        UserSlotFilterOverride(
          presetId: VideoTemplateProjectIds.normalizeServerId(preset.id),
          filterName: preset.previewFilterKey,
          startTime: 0,
          endTime: slotDur,
        ),
      );
    }
    _commitLookPreview(slot.id, seekForEffect: false);
    unawaited(_syncFilter(slot.id, preset));
  }

  Future<void> _applyEffect(TemplatePresetItem preset) async {
    final slot = _selectedSlot;
    if (preset.isClear) {
      _session.setSlotEffect(slot.id, null);
    } else {
      final slotDur = _slotDuration(slot.id);
      _session.setSlotEffect(
        slot.id,
        UserSlotEffectOverride(
          presetId: VideoTemplateProjectIds.normalizeServerId(preset.id),
          effectType: preset.previewEffectKey,
          startTime: 0,
          endTime: slotDur,
        ),
      );
    }
    _commitLookPreview(slot.id, seekForEffect: !preset.isClear);
    unawaited(_syncEffect(slot.id, preset));
  }

  /// Instant local preview after filter/effect pick (no server round-trip).
  void _commitLookPreview(String slotId, {required bool seekForEffect}) {
    if (!mounted) return;
    final preview = _preview;
    if (preview == null) return;
    final slotStart = _slotStartOnTimeline(slotId);
    final slotDur = _slotDuration(slotId);
    final total = max(preview.duration, 0.01);
    final target = seekForEffect
        ? (slotStart + slotDur * 0.45).clamp(0.0, total)
        : _playheadInsideSlot(slotId, preview.playhead)
            ? preview.playhead
            : (slotStart + 0.01).clamp(0.0, total);
    unawaited(
      preview.applyLookPreview(slotId: slotId, targetTime: target).then((_) {
        if (mounted) setState(() {});
      }),
    );
    setState(() {});
  }

  bool _playheadInsideSlot(String slotId, double playhead) {
    final slotStart = _slotStartOnTimeline(slotId);
    final slotEnd = slotStart + _slotDuration(slotId);
    return playhead >= slotStart && playhead < slotEnd;
  }

  Future<void> _syncFilter(String slotId, TemplatePresetItem preset) async {
    final projectId = _serverProjectId;
    final serverSlotId = _serverSlotIdFor(slotId);
    if (projectId == null || serverSlotId == null) return;
    final presetId = VideoTemplateProjectIds.normalizeServerId(preset.id);
    final slotDur = _slotDuration(slotId);
    final override = _session.slotFilterOverrides[slotId];
    if (preset.isClear) {
      await _repository.putSlotFilter(
        projectId: projectId,
        slotId: serverSlotId,
        presetId: null,
        intensity: 1,
      );
      return;
    }
    if (presetId == null) return;
    final window = SlotLocalTiming.normalize(
      slotDuration: slotDur,
      startTime: override?.startTime ?? 0,
      endTime: override?.endTime,
    );
    await _repository.putSlotFilter(
      projectId: projectId,
      slotId: serverSlotId,
      presetId: presetId,
      intensity: (override?.intensity ?? 1).clamp(0.0, 1.0),
      startTime: window.start,
      endTime: window.end,
    );
  }

  Future<void> _syncEffect(String slotId, TemplatePresetItem preset) async {
    final projectId = _serverProjectId;
    final serverSlotId = _serverSlotIdFor(slotId);
    if (projectId == null || serverSlotId == null) return;
    final presetId = VideoTemplateProjectIds.normalizeServerId(preset.id);
    final slotDur = _slotDuration(slotId);
    final override = _session.slotEffectOverrides[slotId];
    if (preset.isClear) {
      await _repository.putSlotEffect(
        projectId: projectId,
        slotId: serverSlotId,
        presetId: null,
      );
      return;
    }
    if (presetId == null) return;
    final window = SlotLocalTiming.normalize(
      slotDuration: slotDur,
      startTime: override?.startTime ?? 0,
      endTime: override?.endTime,
    );
    await _repository.putSlotEffect(
      projectId: projectId,
      slotId: serverSlotId,
      presetId: presetId,
      startTime: window.start,
      endTime: window.end,
    );
  }

  void _debounceLookTimingSync(TemplateEditorOverlayKind kind, String slotId) {
    _lookTimingSyncTimer?.cancel();
    _lookTimingSyncTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_syncSlotLookTiming(kind, slotId));
    });
  }

  /// Push dragged filter/effect window to server (clip-local seconds).
  Future<void> _syncSlotLookTiming(
    TemplateEditorOverlayKind kind,
    String slotId,
  ) async {
    final projectId = _serverProjectId;
    final serverSlotId = _serverSlotIdFor(slotId);
    if (projectId == null || serverSlotId == null) return;
    final slotDur = _slotDuration(slotId);

    switch (kind) {
      case TemplateEditorOverlayKind.filter:
        final override = _session.slotFilterOverrides[slotId];
        if (override == null ||
            override.filterName.isEmpty ||
            override.filterName == 'none') {
          return;
        }
        final presetId = VideoTemplateProjectIds.normalizeServerId(
          override.presetId,
        );
        if (presetId == null) return;
        final window = SlotLocalTiming.normalize(
          slotDuration: slotDur,
          startTime: override.startTime,
          endTime: override.endTime,
        );
        await _repository.putSlotFilter(
          projectId: projectId,
          slotId: serverSlotId,
          presetId: presetId,
          intensity: override.intensity.clamp(0.0, 1.0),
          startTime: window.start,
          endTime: window.end,
        );
      case TemplateEditorOverlayKind.effect:
        final override = _session.slotEffectOverrides[slotId];
        if (override == null ||
            override.effectType.isEmpty ||
            override.effectType == 'none') {
          return;
        }
        final presetId = VideoTemplateProjectIds.normalizeServerId(
          override.presetId,
        );
        if (presetId == null) return;
        final window = SlotLocalTiming.normalize(
          slotDuration: slotDur,
          startTime: override.startTime,
          endTime: override.endTime,
        );
        await _repository.putSlotEffect(
          projectId: projectId,
          slotId: serverSlotId,
          presetId: presetId,
          startTime: window.start,
          endTime: window.end,
        );
      case TemplateEditorOverlayKind.text:
      case TemplateEditorOverlayKind.sticker:
      case TemplateEditorOverlayKind.audio:
        return;
    }
  }

  Future<void> _addTextOverlay() async {
    final recipe = widget.recipe;
    final preview = _preview;
    final canvasW = recipe.width > 0 ? recipe.width : 1080;
    final canvasH = recipe.height > 0 ? recipe.height : 1920;
    final Widget? media = preview == null
        ? null
        : ListenableBuilder(
            listenable: preview,
            builder: (context, _) {
              return _buildComposedPreview(
                preview: preview,
                canvasW: canvasW,
                canvasH: canvasH,
                showTexts: false,
              );
            },
          );

    final draft = await TemplateEditorTextSheet.show(
      context,
      fonts: _fonts,
      loadingFonts: _fontsLoading,
      canvasWidth: canvasW,
      canvasHeight: canvasH,
      media: media,
    );
    if (draft == null || draft.text.isEmpty) return;

    final font = draft.font;
    if (font != null) {
      await TemplateFontCache.load(fontAssetId: font.id, url: font.url);
    }

    final duration = _preview?.duration ?? widget.recipe.duration ?? 5;
    final overlay = UserEditorTextOverlay(
      id: 'text_${DateTime.now().millisecondsSinceEpoch}',
      text: draft.text,
      fontSize: draft.fontSize,
      color: draft.color,
      positionX: draft.positionX,
      positionY: draft.positionY,
      endTime: duration,
      fontAssetId: font?.id,
      fontAssetUrl: font?.url,
      fontLabel: font?.label,
    );
    final next = [..._session.userTexts, overlay];
    _session.setUserTexts(next);
    if (mounted) setState(() {});
    await _refreshPreview();

    final projectId = _serverProjectId;
    if (projectId != null) {
      unawaited(
        _repository.createProjectText(
          projectId: projectId,
          text: draft.text,
          fontSize: draft.fontSize,
          color: draft.color,
          positionX: draft.positionX,
          positionY: draft.positionY,
          endTime: duration,
          fontAssetId: font?.id,
        ),
      );
    }
  }

  Future<void> _addStickerOverlay() async {
    final recipe = widget.recipe;
    final preview = _preview;
    final canvasW = recipe.width > 0 ? recipe.width : 1080;
    final canvasH = recipe.height > 0 ? recipe.height : 1920;
    final Widget? media = preview == null
        ? null
        : ListenableBuilder(
            listenable: preview,
            builder: (context, _) {
              return _buildComposedPreview(
                preview: preview,
                canvasW: canvasW,
                canvasH: canvasH,
              );
            },
          );

    final draft = await TemplateEditorStickerPlacerSheet.show(
      context,
      presets: _stickerPresets,
      canvasWidth: canvasW,
      canvasHeight: canvasH,
      media: media,
    );
    if (draft == null) return;

    final duration = _preview?.duration ?? widget.recipe.duration ?? 5;
    final overlay = UserEditorStickerOverlay(
      id: 'stk_${DateTime.now().millisecondsSinceEpoch}',
      presetId: draft.preset.id,
      assetUrl: draft.preset.assetUrl,
      label: draft.preset.name,
      positionX: draft.positionX,
      positionY: draft.positionY,
      scale: draft.scale,
      endTime: duration,
    );
    final next = [..._session.userStickers, overlay];
    _session.setUserStickers(next);
    if (mounted) setState(() {});
    await _refreshPreview();

    final projectId = _serverProjectId;
    if (projectId != null) {
      unawaited(
        _repository.createProjectSticker(
          projectId: projectId,
          presetId: draft.preset.id,
          assetUrl: draft.preset.assetUrl,
          positionX: draft.positionX,
          positionY: draft.positionY,
          scale: draft.scale,
          endTime: duration,
        ),
      );
    }
  }

  Future<void> _initRenderedPreview({File? file, String? url}) async {
    await _renderedPlayer?.dispose();
    _renderedPlayer = null;

    VideoPlayerController? controller;
    if (file != null && await file.exists()) {
      controller = VideoPlayerController.file(file);
    } else if (url != null && url.trim().isNotEmpty) {
      controller = VideoPlayerController.networkUrl(Uri.parse(url.trim()));
    }
    if (controller == null) return;

    await controller.initialize();
    controller.setLooping(true);
    await controller.play();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _renderedPlayer = controller);
  }

  Future<void> _dismissRenderedPreview() async {
    await _renderedPlayer?.pause();
    await _renderedPlayer?.dispose();
    if (!mounted) return;
    setState(() {
      _showRenderedPreview = false;
      _renderedPreviewFile = null;
      _renderedExportUrl = null;
      _renderedPlayer = null;
      _pendingFinishSelection = null;
      _exportProgress = 0;
      _exportLabel = 'Rendering…';
    });
  }

  void _confirmRenderedPreview() {
    final selection = _pendingFinishSelection;
    if (selection == null) return;
    Navigator.of(context).pop(
      VideoTemplateEditorFinishResult(
        selection: selection.copyWith(projectId: _serverProjectId),
        renderedFile: _renderedPreviewFile,
        serverExportUrl: _renderedExportUrl,
        proceedToNext: true,
      ),
    );
  }

  Future<void> _exportAndFinish() async {
    if (_busy) return;
    if (_showRenderedPreview) {
      _confirmRenderedPreview();
      return;
    }

    _preview?.pause();
    await SoundAudioPreview.stop();

    setState(() {
      _busy = true;
      _error = null;
      _exportProgress = 0;
      _exportLabel = 'Preparing export…';
    });

    try {
      if (!mounted) return;
      setState(() {
        _exportProgress = 0.05;
        _exportLabel = 'Uploading…';
      });

      final recipe = _recipeWithEditorSound();
      var selection = VideoTemplateSelection.fromRecipe(recipe).copyWith(
        projectId: VideoTemplateProjectIds.normalizeServerId(
          _serverProjectId ?? _session.projectId,
        ),
      );

      File? rendered;
      String? exportUrl;
      Failure? serverFailure;

      final templateId = _catalogTemplateIdForRender;

      final hasMedia = _session.slots.any((slot) {
        final fill = _session.fills[slot.id];
        return fill != null &&
            ((fill.localFile?.path.isNotEmpty ?? false) ||
                (fill.userAssetUrl?.trim().isNotEmpty ?? false));
      });

      if (hasMedia) {
        final apply = await vt_di.sl<OneShotRenderVideoTemplateUseCase>()(
          session: _session,
          selection: selection,
          catalogTemplateId: templateId,
          exportQuality: 'standard',
          resolution: recipe.width > 0 && recipe.height > 0
              ? '${recipe.width}x${recipe.height}'
              : '1080x1920',
          fps: recipe.fps > 0 ? recipe.fps.toDouble() : 30,
          onProgress: (p, {label}) {
            if (!mounted) return;
            setState(() {
              _exportProgress = (0.05 + p * 0.9).clamp(0.0, 0.95);
              if (label != null && label.isNotEmpty) {
                _exportLabel = label;
              }
            });
          },
        );
        apply.fold((f) => serverFailure = f, (r) {
          exportUrl = r.serverExportUrl;
          rendered = r.renderedVideo;
          _serverProjectId = r.projectId;
          selection = r.selection;
        });
        if (_serverProjectId != null) {
          final got = await _repository.getProject(_serverProjectId!);
          got.fold((_) {}, _applyServerProject);
        }
        final url = exportUrl?.trim();
        if (url != null &&
            url.isNotEmpty &&
            (rendered == null || !(await rendered!.exists()))) {
          if (mounted) {
            setState(() {
              _exportProgress = 0.92;
              _exportLabel = 'Downloading…';
            });
          }
          try {
            rendered = await AppMediaCacheManager.downloadVideoFile(url);
          } catch (_) {}
        }
        final projectId = _serverProjectId;
        if (projectId != null &&
            ((exportUrl != null && exportUrl!.isNotEmpty) ||
                (rendered != null && await rendered!.exists()))) {
          unawaited(_repository.completeProject(projectId));
        }
      } else {
        serverFailure = ServerFailure(
          'Add media to all slots before rendering.',
        );
      }

      if (!mounted) return;

      final outFile = rendered;
      final hasFile = outFile != null && await outFile.exists();
      final hasUrl = exportUrl != null && exportUrl!.trim().isNotEmpty;
      if (!hasFile && !hasUrl) {
        setState(() {
          _busy = false;
          _error = serverFailure?.message ?? 'Could not render on server';
          _exportLabel = 'Export failed';
        });
        return;
      }

      await _initRenderedPreview(
        file: hasFile ? outFile : null,
        url: hasUrl ? exportUrl : null,
      );
      if (!mounted) return;

      setState(() {
        _busy = false;
        _exportProgress = 1;
        _exportLabel = 'Preview ready';
        _showRenderedPreview = true;
        _renderedPreviewFile = hasFile ? outFile : null;
        _renderedExportUrl = hasUrl ? exportUrl : null;
        _pendingFinishSelection = selection;
        _activePanel = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Export failed';
        _exportLabel = 'Export failed';
      });
    }
  }

  void _popWithoutNext() {
    final recipe = _recipeWithEditorSound();
    final selection = VideoTemplateSelection.fromRecipe(recipe).copyWith(
      projectId: VideoTemplateProjectIds.normalizeServerId(_session.projectId),
    );
    Navigator.of(context).pop(
      VideoTemplateEditorFinishResult(
        selection: selection,
        proceedToNext: false,
      ),
    );
  }

  void _onSeek(double seconds) {
    _preview?.seek(seconds);
    final slots = _session.slots;
    var cursor = 0.0;
    for (var i = 0; i < slots.length; i++) {
      final dur = UserProjectSlotMapper.resolveSlotDuration(
        slots[i],
        _session.fills[slots[i].id],
      );
      if (seconds < cursor + dur) {
        setState(() => _selectedSlotIndex = i);
        break;
      }
      cursor += dur;
    }
  }

  /// Timed bars for filters / effects / text / stickers (TikTok-style tracks).
  List<TemplateEditorOverlaySegment> _buildOverlaySegments(double total) {
    final segments = <TemplateEditorOverlaySegment>[];
    final slots = _session.slots;
    var cursor = 0.0;

    for (final slot in slots) {
      final dur = UserProjectSlotMapper.resolveSlotDuration(
        slot,
        _session.fills[slot.id],
      );
      final slotStart = cursor;
      final slotEnd = cursor + dur;

      final filter = _session.slotFilterOverrides[slot.id];
      if (filter != null &&
          filter.filterName.isNotEmpty &&
          filter.filterName != 'none') {
        final window = SlotLocalTiming.normalize(
          slotDuration: dur,
          startTime: filter.startTime,
          endTime: filter.endTime,
        );
        segments.add(
          TemplateEditorOverlaySegment(
            id: slot.id,
            kind: TemplateEditorOverlayKind.filter,
            start: slotStart + window.start,
            end: slotStart + window.end,
            label: filter.filterName,
            color: TemplateEditorTheme.filterTrack,
            icon: LucideIcons.blend,
          ),
        );
      }

      final effect = _session.slotEffectOverrides[slot.id];
      if (effect != null &&
          effect.effectType.isNotEmpty &&
          effect.effectType != 'none') {
        final window = SlotLocalTiming.normalize(
          slotDuration: dur,
          startTime: effect.startTime,
          endTime: effect.endTime,
        );
        segments.add(
          TemplateEditorOverlaySegment(
            id: slot.id,
            kind: TemplateEditorOverlayKind.effect,
            start: slotStart + window.start,
            end: slotStart + window.end,
            label: effect.effectType,
            color: TemplateEditorTheme.effectTrack,
            icon: LucideIcons.sparkles,
          ),
        );
      }

      cursor = slotEnd;
    }

    for (final t in _session.userTexts) {
      final end = t.endTime > t.startTime
          ? t.endTime
          : min(t.startTime + 5, total);
      segments.add(
        TemplateEditorOverlaySegment(
          id: t.id,
          kind: TemplateEditorOverlayKind.text,
          start: t.startTime.clamp(0, total),
          end: end.clamp(0, total),
          label: t.text,
          color: TemplateEditorTheme.textTrack,
          icon: LucideIcons.type,
        ),
      );
    }

    for (final s in _session.userStickers) {
      final end = (s.endTime ?? total).clamp(0.0, total);
      final start = s.startTime.clamp(0.0, total);
      segments.add(
        TemplateEditorOverlaySegment(
          id: s.id,
          kind: TemplateEditorOverlayKind.sticker,
          start: start,
          end: end > start ? end : min(start + 5, total),
          label: s.presetId ?? 'Sticker',
          color: TemplateEditorTheme.stickerTrack,
          icon: LucideIcons.sticker,
        ),
      );
    }

    final audioTracks = _session.resolvedAudioTracks;
    final audioSegments = <TemplateEditorOverlaySegment>[];
    for (var i = 0; i < audioTracks.length; i++) {
      final track = audioTracks[i];
      final start = track.startTime.clamp(0.0, total);
      final end = (track.endTime ?? total).clamp(start + 0.2, total);
      audioSegments.add(
        TemplateEditorOverlaySegment(
          id: track.id,
          kind: TemplateEditorOverlayKind.audio,
          start: start.toDouble(),
          end: end.toDouble(),
          label: track.timelineLabel(totalDuration: total),
          color: TemplateEditorTheme.audioTrack,
          icon: LucideIcons.music,
          showVolumeIcon: i == 0,
          editable: true,
        ),
      );
    }
    if (audioSegments.isNotEmpty) {
      segments.insertAll(0, audioSegments);
    }

    return segments;
  }

  double _slotStartOnTimeline(String slotId) {
    var cursor = 0.0;
    for (final slot in _session.slots) {
      if (slot.id == slotId) return cursor;
      cursor += UserProjectSlotMapper.resolveSlotDuration(
        slot,
        _session.fills[slot.id],
      );
    }
    return 0;
  }

  double _slotDuration(String slotId) {
    for (final slot in _session.slots) {
      if (slot.id == slotId) {
        return UserProjectSlotMapper.resolveSlotDuration(
          slot,
          _session.fills[slot.id],
        );
      }
    }
    return 0;
  }

  void _onOverlayRangeChanged(
    TemplateEditorOverlayKind kind,
    String id,
    double start,
    double end,
  ) {
    final total = max(_preview?.duration ?? 0, 0.01);
    start = start.clamp(0.0, total);
    end = end.clamp(start + 0.2, total);

    switch (kind) {
      case TemplateEditorOverlayKind.filter:
        final slotStart = _slotStartOnTimeline(id);
        final slotDur = _slotDuration(id);
        final window = SlotLocalTiming.normalize(
          slotDuration: slotDur,
          startTime: (start - slotStart).clamp(0.0, slotDur),
          endTime: (end - slotStart).clamp(0.05, slotDur),
        );
        _session.patchSlotFilterTiming(
          id,
          startTime: window.start,
          endTime: window.end,
        );
        _debounceLookTimingSync(kind, id);
      case TemplateEditorOverlayKind.effect:
        final slotStart = _slotStartOnTimeline(id);
        final slotDur = _slotDuration(id);
        final window = SlotLocalTiming.normalize(
          slotDuration: slotDur,
          startTime: (start - slotStart).clamp(0.0, slotDur),
          endTime: (end - slotStart).clamp(0.05, slotDur),
        );
        _session.patchSlotEffectTiming(
          id,
          startTime: window.start,
          endTime: window.end,
        );
        _debounceLookTimingSync(kind, id);
      case TemplateEditorOverlayKind.text:
        _session.patchUserTextTiming(id, startTime: start, endTime: end);
      case TemplateEditorOverlayKind.sticker:
        _session.patchUserStickerTiming(id, startTime: start, endTime: end);
      case TemplateEditorOverlayKind.audio:
        _session.patchUserAudioTiming(
          id: id,
          startTime: start,
          endTime: end,
        );
    }
    _preview?.reloadTimeline();
    if (kind == TemplateEditorOverlayKind.filter ||
        kind == TemplateEditorOverlayKind.effect) {
      final preview = _preview;
      if (preview != null) {
        unawaited(
          preview.applyLookPreview(
            slotId: id,
            targetTime: preview.playhead,
          ).then((_) {
            if (mounted) setState(() {});
          }),
        );
      }
    } else {
      unawaited(_refreshPreview());
    }
    if (mounted) setState(() {});
  }

  Widget _buildTopBar() {
    final previewMode = _showRenderedPreview;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _CircleNavButton(
            icon: LucideIcons.chevronLeft,
            color: TemplateEditorTheme.accent,
            onPressed: _busy
                ? null
                : previewMode
                ? _dismissRenderedPreview
                : _popWithoutNext,
          ),
          const Spacer(),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _exportLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            )
          else if (previewMode)
            const Text(
              'Server preview',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          _CircleNavButton(
            icon: previewMode ? LucideIcons.arrowRight : LucideIcons.check,
            color: TemplateEditorTheme.accent,
            onPressed: _busy ? null : _exportAndFinish,
          ),
        ],
      ),
    );
  }

  Widget _buildRenderedPreview() {
    final player = _renderedPlayer;
    if (player == null || !player.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: player.value.size.width,
        height: player.value.size.height,
        child: VideoPlayer(player),
      ),
    );
  }

  Widget _buildPreview() {
    final preview = _preview;
    final recipe = widget.recipe;
    final canvasW = recipe.width > 0 ? recipe.width : 1080;
    final canvasH = recipe.height > 0 ? recipe.height : 1920;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: AspectRatio(
        aspectRatio: canvasW / canvasH,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _showRenderedPreview
              ? _buildRenderedPreview()
              : preview == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : ListenableBuilder(
                  listenable: preview,
                  builder: (context, _) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildComposedPreview(
                          preview: preview,
                          canvasW: canvasW,
                          canvasH: canvasH,
                        ),
                        TemplateUserTextGestureLayer(
                          texts: _session.userTexts,
                          canvasWidth: canvasW,
                          canvasHeight: canvasH,
                          onInteractionStart: () => preview.pause(),
                          onChanged: (updated) {
                            _session.patchUserTextLayout(
                              updated.id,
                              positionX: updated.positionX,
                              positionY: updated.positionY,
                              fontSize: updated.fontSize,
                            );
                            preview.reloadTimeline();
                          },
                        ),
                        TemplateUserStickerGestureLayer(
                          stickers: _session.userStickers,
                          canvasWidth: canvasW,
                          canvasHeight: canvasH,
                          onInteractionStart: () => preview.pause(),
                          onChanged: (updated) {
                            _session.patchUserStickerLayout(
                              updated.id,
                              positionX: updated.positionX,
                              positionY: updated.positionY,
                              scale: updated.scale,
                            );
                            preview.reloadTimeline();
                          },
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget? _buildActiveSheet() {
    switch (_activePanel) {
      case TemplateEditorPanel.filters:
        return TemplateEditorPresetSheet(
          title: 'Filters · clip ${_selectedSlotIndex + 1}',
          presets: _filterPresets,
          selectedId: _selectedFilterId,
          onSelected: _applyFilter,
          onClear: () => _applyFilter(kFallbackFilterPresets.first),
          onClose: () => setState(() => _activePanel = null),
        );
      case TemplateEditorPanel.effects:
        return TemplateEditorPresetSheet(
          title: 'Effects · clip ${_selectedSlotIndex + 1}',
          presets: _effectPresets,
          selectedId: _selectedEffectId,
          onSelected: _applyEffect,
          onClear: () => _applyEffect(kFallbackEffectPresets.first),
          onClose: () => setState(() => _activePanel = null),
        );
      case TemplateEditorPanel.stickers:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_activePanel == TemplateEditorPanel.stickers) {
            setState(() => _activePanel = null);
            unawaited(_addStickerOverlay());
          }
        });
        return null;
      case TemplateEditorPanel.text:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_activePanel == TemplateEditorPanel.text) {
            setState(() => _activePanel = null);
            unawaited(_addTextOverlay());
          }
        });
        return null;
      case TemplateEditorPanel.audio:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_activePanel == TemplateEditorPanel.audio) {
            setState(() => _activePanel = null);
            unawaited(_pickAudio());
          }
        });
        return null;
      case TemplateEditorPanel.edit:
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final activeSheet = _buildActiveSheet();

    return Scaffold(
      backgroundColor: TemplateEditorTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (_busy)
              LinearProgressIndicator(
                value: _exportProgress <= 0 ? null : _exportProgress,
                backgroundColor: Colors.white12,
                color: Colors.white,
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(child: _buildPreview()),
            if (!_showRenderedPreview && preview != null)
              ListenableBuilder(
                listenable: preview,
                builder: (context, _) {
                  final total = max(preview.duration, 0.01);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TemplateEditorPlaybackBar(
                        isPlaying: preview.isPlaying,
                        currentTime: preview.playhead,
                        totalTime: total,
                        canUndo: _session.canUndo,
                        canRedo: _session.canRedo,
                        onPlayPause: () {
                          if (preview.isPlaying) {
                            preview.pause();
                          } else {
                            preview.play();
                          }
                        },
                        onUndo: () async {
                          _session.undo();
                          await _refreshPreview();
                        },
                        onRedo: () async {
                          _session.redo();
                          await _refreshPreview();
                        },
                      ),
                      TemplateEditorTimeline(
                        slots: _session.slots,
                        fills: _session.fills,
                        playhead: preview.playhead,
                        totalDuration: total,
                        selectedSlotIndex: _selectedSlotIndex,
                        overlaySegments: _buildOverlaySegments(total),
                        onSlotTap: _busy ? null : _pickMediaForSlot,
                        onAddMedia: _busy
                            ? null
                            : () => _pickMediaForSlot(_selectedSlotIndex),
                        onSeek: _onSeek,
                        onOverlayRangeChanged: _busy
                            ? null
                            : _onOverlayRangeChanged,
                      ),
                    ],
                  );
                },
              )
            else if (!_showRenderedPreview)
              TemplateEditorTimeline(
                slots: _session.slots,
                fills: _session.fills,
                playhead: 0,
                totalDuration: max(widget.recipe.duration ?? 5, 0.01),
                selectedSlotIndex: _selectedSlotIndex,
                overlaySegments: _buildOverlaySegments(
                  max(widget.recipe.duration ?? 5, 0.01),
                ),
                onSlotTap: _busy ? null : _pickMediaForSlot,
                onAddMedia: _busy
                    ? null
                    : () => _pickMediaForSlot(_selectedSlotIndex),
              ),
            if (!_showRenderedPreview)
              TemplateEditorToolbar(
                editable: _editable,
                activePanel: _activePanel,
                onPanelSelected: (panel) {
                  if (panel == TemplateEditorPanel.edit) {
                    unawaited(_pickMediaForSlot(_selectedSlotIndex));
                    return;
                  }
                  _togglePanel(panel);
                },
              ),
            if (_showRenderedPreview && _renderedPlayer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _renderedPlayer!,
                  builder: (context, value, _) {
                    return Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            value.isPlaying
                                ? LucideIcons.pause
                                : LucideIcons.play,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (value.isPlaying) {
                              _renderedPlayer!.pause();
                            } else {
                              _renderedPlayer!.play();
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            'Tap → to continue with this render',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            if (activeSheet != null && !_showRenderedPreview) activeSheet,
          ],
        ),
      ),
    );
  }
}

class _CircleNavButton extends StatelessWidget {
  const _CircleNavButton({
    required this.icon,
    required this.color,
    this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
