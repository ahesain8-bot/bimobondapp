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
import 'package:bimobondapp/app/video_templates/engine/layers/layer_engines.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as vt_di;
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_font_cache.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_layer_toolbar.dart';
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
  TemplateEditorOverlayKind? _selectedOverlayKind;
  String? _selectedOverlayId;
  String? _replaceOverlayId;
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
    _session.seedDefaultsFromRecipe();
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
    preview.reloadTimeline();
    if (_session.userAudios.isEmpty &&
        _session.effectiveSound != null &&
        _session.userAudioTiming == null) {
      final total = max(preview.duration, 0.01);
      _session.patchUserAudioTimingLegacy(startTime: 0, endTime: total);
      preview.reloadTimeline();
    }
    // TikTok-style: image slots advance playhead + music on open (like studio).
    if (preview.duration > 0) {
      preview.play();
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

  String? _slotIdForRecipeFilterOverlay(String overlayId) {
    for (final slot in _session.slots) {
      if (overlayId.startsWith('recipe_flt_${slot.id}_')) return slot.id;
    }
    return null;
  }

  String? _slotIdForRecipeEffectOverlay(String overlayId) {
    for (final slot in _session.slots) {
      if (overlayId.startsWith('recipe_fx_${slot.id}_')) return slot.id;
    }
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

  Future<void> _pickAudio({String? replaceTrackId}) async {
    final wasPlaying = _preview?.isPlaying ?? false;
    _preview?.pause();
    await SoundAudioPreview.stop();
    if (!mounted) return;

    final existingTrack = replaceTrackId == null
        ? null
        : _session.userAudios.where((a) => a.id == replaceTrackId).firstOrNull ??
            _session.resolvedAudioTracks
                .where((a) => a.id == replaceTrackId)
                .firstOrNull;

    SoundPickResult? picked;
    try {
      picked = await SoundPickerSheet.show(
        context,
        initialSelection:
            existingTrack?.sound ?? _session.effectiveSound,
        initialOffset: Duration(
          milliseconds: existingTrack?.segmentStartMs ??
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
      if (wasPlaying) _preview?.play();
      return;
    }

    if (picked.cleared) {
      _session.clearUserAudios();
      await _refreshPreview();
      setState(() => _activePanel = null);
      if (wasPlaying) _preview?.play();
      return;
    }

    final sound = picked.sound;
    if (sound == null) {
      setState(() => _activePanel = null);
      return;
    }

    final total = max(_preview?.duration ?? widget.recipe.duration ?? 5, 0.01);
    final clip = picked.clipRangeMs;
    _session.addUserAudio(
      UserEditorAudioTrack(
        id: existingTrack?.id ??
            'audio_${DateTime.now().microsecondsSinceEpoch}',
        sound: sound,
        soundSegmentId: picked.soundSegmentId,
        segmentStartMs: clip?.startMs ?? picked.offset.inMilliseconds,
        segmentEndMs:
            clip?.endMs ?? (picked.offset + picked.window).inMilliseconds,
        startTime: existingTrack?.startTime ?? 0,
        endTime: existingTrack?.endTime ?? total,
      ),
    );

    final url = sound.resolvedAudioUrl;
    if (url.isNotEmpty) {
      unawaited(SoundLocalFile.resolve(url));
    }

    await _refreshPreview();
    _preview?.play();
    setState(() => _activePanel = null);
  }

  VideoTemplateRecipeEntity _recipeWithEditorSound() {
    final base = widget.recipe;
    final handoffTexts = _handoffRecipeTexts(base);
    final handoffStickers = _handoffRecipeStickers(base);
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
        texts: handoffTexts,
        stickers: handoffStickers,
        overlays: base.overlays,
        assets: base.assets,
        keyframes: base.keyframes,
        renderHints: base.renderHints,
      );
    }
    final sound = _session.userSound;
    if (sound == null) {
      if (handoffTexts == base.texts && handoffStickers == base.stickers) {
        return base;
      }
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
        soundId: base.soundId,
        sound: base.sound,
        soundSegmentId: base.soundSegmentId,
        soundSegmentStartMs: base.soundSegmentStartMs,
        soundSegmentEndMs: base.soundSegmentEndMs,
        slots: base.slots,
        beatMap: base.beatMap,
        transitions: base.transitions,
        tracks: base.tracks,
        clips: base.clips,
        texts: handoffTexts,
        stickers: handoffStickers,
        overlays: base.overlays,
        assets: base.assets,
        keyframes: base.keyframes,
        renderHints: base.renderHints,
      );
    }
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
      texts: handoffTexts,
      stickers: handoffStickers,
      overlays: base.overlays,
      assets: base.assets,
      keyframes: base.keyframes,
      renderHints: base.renderHints,
    );
  }

  List<TemplateTextEntity> _handoffRecipeTexts(VideoTemplateRecipeEntity base) {
    if (!_session.userTextsLayerOwned) return base.texts;
    return _session.userTexts
        .where((t) => t.text.trim().isNotEmpty)
        .map(
          (t) => TemplateTextEntity(
            id: t.id,
            text: t.text.trim(),
            fontSize: t.fontSize,
            color: t.color,
            startTime: t.startTime,
            endTime: t.endTime,
            positionX: t.positionX,
            positionY: t.positionY,
            fontAssetId: t.fontAssetId,
            fontAssetUrl: t.fontAssetUrl,
            animationIn: t.animationIn,
            animationOut: t.animationOut,
          ),
        )
        .toList(growable: false);
  }

  List<TemplateStickerEntity> _handoffRecipeStickers(
    VideoTemplateRecipeEntity base,
  ) {
    if (!_session.userStickersLayerOwned) return base.stickers;
    return _session.userStickers
        .map(
          (s) => TemplateStickerEntity(
            id: s.id,
            assetId: s.presetId,
            assetUrl: s.assetUrl,
            positionX: s.positionX,
            positionY: s.positionY,
            scale: s.scale,
            opacity: s.opacity,
            startTime: s.startTime,
            endTime: s.endTime ?? s.startTime + 1,
          ),
        )
        .toList(growable: false);
  }

  VideoTemplateSlotEntity get _selectedSlot {
    final slots = _session.slots;
    final i = _selectedSlotIndex.clamp(0, slots.length - 1);
    return slots[i];
  }

  String? get _selectedFilterId {
    if (_replaceOverlayId != null) {
      final track = _session.userFilters
          .where((f) => f.id == _replaceOverlayId)
          .firstOrNull;
      return track?.presetId ?? track?.filterName;
    }
    return null;
  }

  String? get _selectedEffectId {
    if (_replaceOverlayId != null) {
      final track = _session.userEffects
          .where((e) => e.id == _replaceOverlayId)
          .firstOrNull;
      return track?.presetId ?? track?.effectType;
    }
    return null;
  }

  String _previewSlotId(CompositionPreviewController preview) =>
      preview.activeSlotId ?? _selectedSlot.id;

  List<({String name, double intensity})> _activeFilterStackAtPlayhead(
    CompositionPreviewController preview,
    String slotId,
  ) {
    final local = preview.playhead - _slotStartOnTimeline(slotId);
    final slotDur = _slotDuration(slotId);
    final out = <({String name, double intensity})>[];
    for (final filter in _session.filtersForSlot(slotId)) {
      if (filter.filterName.isEmpty || filter.filterName == 'none') continue;
      if (!SlotLocalTiming.containsLocalTime(
        slotDuration: slotDur,
        localTime: local,
        startTime: filter.startTime,
        endTime: filter.endTime,
      )) {
        continue;
      }
      out.add((name: filter.filterName, intensity: filter.intensity));
    }
    return out;
  }

  List<({String type, double progress, Map<String, dynamic> params})>
  _activeEffectsAtPlayhead(
    CompositionPreviewController preview,
    String slotId,
  ) {
    final local = preview.playhead - _slotStartOnTimeline(slotId);
    final slotDur = _slotDuration(slotId);
    final out =
        <({String type, double progress, Map<String, dynamic> params})>[];
    for (final effect in _session.effectsForSlot(slotId)) {
      if (effect.effectType.isEmpty || effect.effectType == 'none') continue;
      if (!SlotLocalTiming.containsLocalTime(
        slotDuration: slotDur,
        localTime: local,
        startTime: effect.startTime,
        endTime: effect.endTime,
      )) {
        continue;
      }
      final window = SlotLocalTiming.normalize(
        slotDuration: slotDur,
        startTime: effect.startTime,
        endTime: effect.endTime,
      );
      out.add((
        type: effect.effectType,
        progress: EffectEngine.progress(local, window.start, window.end),
        params: effect.parameters,
      ));
    }
    return out;
  }

  bool _isFilterActiveAtPlayhead(
    CompositionPreviewController preview,
    String slotId,
  ) {
    return _activeFilterStackAtPlayhead(preview, slotId).isNotEmpty;
  }

  bool _isEffectActiveAtPlayhead(
    CompositionPreviewController preview,
    String slotId,
  ) {
    final local = preview.playhead - _slotStartOnTimeline(slotId);
    final slotDur = _slotDuration(slotId);
    for (final effect in _session.effectsForSlot(slotId)) {
      if (effect.effectType.isEmpty || effect.effectType == 'none') continue;
      if (SlotLocalTiming.containsLocalTime(
        slotDuration: slotDur,
        localTime: local,
        startTime: effect.startTime,
        endTime: effect.endTime,
      )) {
        return true;
      }
    }
    return false;
  }

  Widget _buildComposedPreview({
    required CompositionPreviewController preview,
    required num canvasW,
    required num canvasH,
    bool showTexts = true,
  }) {
    final slotId = _previewSlotId(preview);
    final filterStack = _activeFilterStackAtPlayhead(preview, slotId);
    final effectStack = _activeEffectsAtPlayhead(preview, slotId);
    final filterActive = filterStack.isNotEmpty;
    final primaryFilter = filterActive ? filterStack.first : null;
    return VideoTemplateComposedPreview(
      canvasWidth: canvasW.round(),
      canvasHeight: canvasH.round(),
      frame: preview.frame,
      videoController: preview.videoController,
      imageFile: preview.imageFile,
      decodedImage: preview.decodedImage,
      isVideoMedia: preview.activeSlotIsVideo || preview.hasVideoSurface,
      videoLookStill: preview.videoLookStill,
      useVideoLookStill: _shouldUseVideoLookStill(preview, slotId: slotId),
      fallbackFilterName: primaryFilter?.name,
      fallbackFilterIntensity: primaryFilter?.intensity ?? 1,
      fallbackFilterStack: filterStack,
      fallbackEffects: effectStack,
      showTexts: showTexts,
    );
  }

  bool _shouldUseVideoLookStill(
    CompositionPreviewController preview, {
    String? slotId,
  }) {
    if (!preview.activeSlotIsVideo && !preview.hasVideoSurface) return false;
    final id = slotId ?? _previewSlotId(preview);
    return _isFilterActiveAtPlayhead(preview, id) ||
        _isEffectActiveAtPlayhead(preview, id);
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
    final replaceId = _replaceOverlayId;
    if (preset.isClear) {
      _session.clearUserFiltersForSlot(slot.id);
      _clearOverlaySelection();
    } else if (replaceId != null) {
      final existing = _session.userFilters
          .where((f) => f.id == replaceId)
          .firstOrNull;
      if (existing != null) {
        _session.replaceUserFilter(
          replaceId,
          existing.copyWith(
            presetId: VideoTemplateProjectIds.normalizeServerId(preset.id),
            filterName: preset.previewFilterKey,
            label: preset.name,
          ),
        );
        _selectedOverlayId = replaceId;
        _selectedOverlayKind = TemplateEditorOverlayKind.filter;
      }
      _replaceOverlayId = null;
    } else {
      if (_session.filtersForSlot(slot.id).length >= kMaxFiltersPerSlot) {
        _showSnack('Max $kMaxFiltersPerSlot filters per clip');
        return;
      }
      final track = UserEditorFilterTrack(
        id: 'flt_${DateTime.now().microsecondsSinceEpoch}',
        slotId: slot.id,
        presetId: VideoTemplateProjectIds.normalizeServerId(preset.id),
        filterName: preset.previewFilterKey,
        label: preset.name,
      );
      _session.addUserFilter(track);
      _selectedOverlayId = track.id;
      _selectedOverlayKind = TemplateEditorOverlayKind.filter;
    }
    _commitLookPreview(slot.id, seekForEffect: false);
    unawaited(_syncSlotFilters(slot.id));
    setState(() => _activePanel = null);
  }

  Future<void> _applyEffect(TemplatePresetItem preset) async {
    final slot = _selectedSlot;
    final replaceId = _replaceOverlayId;
    if (preset.isClear) {
      _session.clearUserEffectsForSlot(slot.id);
      _clearOverlaySelection();
    } else if (replaceId != null) {
      final existing = _session.userEffects
          .where((e) => e.id == replaceId)
          .firstOrNull;
      if (existing != null) {
        _session.replaceUserEffect(
          replaceId,
          existing.copyWith(
            presetId: VideoTemplateProjectIds.normalizeServerId(preset.id),
            effectType: preset.previewEffectKey,
            label: preset.name,
          ),
        );
        _selectedOverlayId = replaceId;
        _selectedOverlayKind = TemplateEditorOverlayKind.effect;
      }
      _replaceOverlayId = null;
    } else {
      if (_session.effectsForSlot(slot.id).length >= kMaxEffectsPerSlot) {
        _showSnack('Max $kMaxEffectsPerSlot effects per clip');
        return;
      }
      final track = UserEditorEffectTrack(
        id: 'fx_${DateTime.now().microsecondsSinceEpoch}',
        slotId: slot.id,
        presetId: VideoTemplateProjectIds.normalizeServerId(preset.id),
        effectType: preset.previewEffectKey,
        label: preset.name,
      );
      _session.addUserEffect(track);
      _selectedOverlayId = track.id;
      _selectedOverlayKind = TemplateEditorOverlayKind.effect;
    }
    _commitLookPreview(slot.id, seekForEffect: !preset.isClear);
    unawaited(_syncSlotEffects(slot.id));
    setState(() => _activePanel = null);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _clearOverlaySelection() {
    _selectedOverlayId = null;
    _selectedOverlayKind = null;
    _replaceOverlayId = null;
  }

  /// Instant local preview after filter/effect pick (no server round-trip).
  void _commitLookPreview(String slotId, {required bool seekForEffect}) {
    if (!mounted) return;
    final preview = _preview;
    if (preview == null) return;
    final slotStart = _slotStartOnTimeline(slotId);
    final slotDur = max(_slotDuration(slotId), 0.05);
    final total = max(preview.duration, 0.01);
    // Seek into the edited clip so slot-local FX/filters are visible immediately.
    final target = (slotStart + slotDur * (seekForEffect ? 0.45 : 0.3))
        .clamp(0.0, total);
    unawaited(
      preview.applyLookPreview(slotId: slotId, targetTime: target).then((_) {
        if (mounted) setState(() {});
      }),
    );
    setState(() {});
  }

  Future<void> _syncSlotFilters(String slotId) async {
    final projectId = _serverProjectId;
    final serverSlotId = _serverSlotIdFor(slotId);
    if (projectId == null || serverSlotId == null) return;
    final slotDur = _slotDuration(slotId);
    final items = <Map<String, dynamic>>[];
    for (final filter in _session.filtersForSlot(slotId)) {
      final presetId = VideoTemplateProjectIds.normalizeServerId(filter.presetId);
      final window = SlotLocalTiming.normalize(
        slotDuration: slotDur,
        startTime: filter.startTime,
        endTime: filter.endTime,
      );
      if (presetId != null) {
        items.add({
          'presetId': presetId,
          'intensity': filter.intensity.clamp(0.0, 1.0),
          'startTime': window.start,
          'endTime': window.end,
        });
      } else if (filter.filterName.isNotEmpty && filter.filterName != 'none') {
        items.add({
          'filterName': filter.filterName,
          'intensity': filter.intensity.clamp(0.0, 1.0),
          'startTime': window.start,
          'endTime': window.end,
        });
      }
    }
    await _repository.putSlotFilterItems(
      projectId: projectId,
      slotId: serverSlotId,
      items: items,
    );
  }

  Future<void> _syncSlotEffects(String slotId) async {
    final projectId = _serverProjectId;
    final serverSlotId = _serverSlotIdFor(slotId);
    if (projectId == null || serverSlotId == null) return;
    final slotDur = _slotDuration(slotId);
    final items = <Map<String, dynamic>>[];
    for (final effect in _session.effectsForSlot(slotId)) {
      final presetId = VideoTemplateProjectIds.normalizeServerId(effect.presetId);
      final window = SlotLocalTiming.normalize(
        slotDuration: slotDur,
        startTime: effect.startTime,
        endTime: effect.endTime,
      );
      if (presetId != null) {
        items.add({
          'presetId': presetId,
          'startTime': window.start,
          'endTime': window.end,
        });
      } else if (effect.effectType.isNotEmpty && effect.effectType != 'none') {
        items.add({
          'effectType': effect.effectType,
          'startTime': window.start,
          'endTime': window.end,
          if (effect.parameters.isNotEmpty) 'parameters': effect.parameters,
        });
      }
    }
    await _repository.putSlotEffectItems(
      projectId: projectId,
      slotId: serverSlotId,
      items: items,
    );
  }

  void _debounceLookTimingSync(TemplateEditorOverlayKind kind, String trackId) {
    _lookTimingSyncTimer?.cancel();
    _lookTimingSyncTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_syncOverlayLookTiming(kind, trackId));
    });
  }

  Future<void> _syncOverlayLookTiming(
    TemplateEditorOverlayKind kind,
    String trackId,
  ) async {
    switch (kind) {
      case TemplateEditorOverlayKind.filter:
        final track = _session.userFilters
            .where((f) => f.id == trackId)
            .firstOrNull;
        if (track == null) return;
        await _syncSlotFilters(track.slotId);
      case TemplateEditorOverlayKind.effect:
        final track = _session.userEffects
            .where((e) => e.id == trackId)
            .firstOrNull;
        if (track == null) return;
        await _syncSlotEffects(track.slotId);
      case TemplateEditorOverlayKind.text:
      case TemplateEditorOverlayKind.sticker:
      case TemplateEditorOverlayKind.audio:
        return;
    }
  }

  TemplateEditorTextDraft? _textDraftFrom(UserEditorTextOverlay overlay) {
    TemplateFontItem? font;
    if (overlay.fontAssetId != null) {
      font = _fonts.where((f) => f.id == overlay.fontAssetId).firstOrNull;
      if (font == null &&
          overlay.fontAssetUrl != null &&
          overlay.fontAssetUrl!.isNotEmpty) {
        font = TemplateFontItem(
          id: overlay.fontAssetId!,
          label: overlay.fontLabel ?? 'Font',
          url: overlay.fontAssetUrl!,
        );
      }
    }
    return TemplateEditorTextDraft(
      text: overlay.text,
      font: font,
      fontSize: overlay.fontSize,
      color: overlay.color,
      positionX: overlay.positionX,
      positionY: overlay.positionY,
    );
  }

  TemplatePresetItem? _stickerPresetFor(UserEditorStickerOverlay overlay) {
    if (overlay.presetId != null) {
      final match =
          _stickerPresets.where((p) => p.id == overlay.presetId).firstOrNull;
      if (match != null) return match;
    }
    if (overlay.presetId != null ||
        (overlay.assetUrl?.trim().isNotEmpty ?? false)) {
      return TemplatePresetItem(
        id: overlay.presetId ?? overlay.id,
        name: overlay.label ?? 'Sticker',
        kind: TemplatePresetKind.sticker,
        assetUrl: overlay.assetUrl,
      );
    }
    return null;
  }

  TemplateEditorStickerDraft? _stickerDraftFrom(
    UserEditorStickerOverlay overlay,
  ) {
    final preset = _stickerPresetFor(overlay);
    if (preset == null) return null;
    return TemplateEditorStickerDraft(
      preset: preset,
      positionX: overlay.positionX,
      positionY: overlay.positionY,
      scale: overlay.scale,
    );
  }

  Future<void> _addTextOverlay({String? replaceId}) async {
    final recipe = widget.recipe;
    final preview = _preview;
    final canvasW = recipe.width > 0 ? recipe.width : 1080;
    final canvasH = recipe.height > 0 ? recipe.height : 1920;
    final existing = replaceId == null
        ? null
        : _session.userTexts.where((t) => t.id == replaceId).firstOrNull;
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
      initial: existing == null ? null : _textDraftFrom(existing),
      title: existing == null ? 'Add text' : 'Replace text',
    );
    if (draft == null || draft.text.isEmpty) return;

    final font = draft.font;
    if (font != null) {
      await TemplateFontCache.load(fontAssetId: font.id, url: font.url);
    }

    final duration = _preview?.duration ?? widget.recipe.duration ?? 5;
    if (existing != null && replaceId != null) {
      _session.replaceUserText(
        replaceId,
        existing.copyWith(
          text: draft.text,
          fontSize: draft.fontSize,
          color: draft.color,
          positionX: draft.positionX,
          positionY: draft.positionY,
          fontAssetId: font?.id,
          fontAssetUrl: font?.url,
          fontLabel: font?.label,
          clearFont: font == null,
        ),
      );
      _selectedOverlayId = replaceId;
      _selectedOverlayKind = TemplateEditorOverlayKind.text;
    } else {
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
      _session.setUserTexts([..._session.userTexts, overlay]);
      _selectedOverlayId = overlay.id;
      _selectedOverlayKind = TemplateEditorOverlayKind.text;

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
    if (mounted) setState(() {});
    await _refreshPreview();
  }

  Future<void> _addStickerOverlay({String? replaceId}) async {
    final recipe = widget.recipe;
    final preview = _preview;
    final canvasW = recipe.width > 0 ? recipe.width : 1080;
    final canvasH = recipe.height > 0 ? recipe.height : 1920;
    final existing = replaceId == null
        ? null
        : _session.userStickers.where((s) => s.id == replaceId).firstOrNull;
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
      initial: existing == null ? null : _stickerDraftFrom(existing),
      title: existing == null ? 'Stickers' : 'Replace sticker',
    );
    if (draft == null) return;

    final duration = _preview?.duration ?? widget.recipe.duration ?? 5;
    if (existing != null && replaceId != null) {
      _session.replaceUserSticker(
        replaceId,
        existing.copyWith(
          presetId: draft.preset.id,
          assetUrl: draft.preset.assetUrl,
          label: draft.preset.name,
          positionX: draft.positionX,
          positionY: draft.positionY,
          scale: draft.scale,
        ),
      );
      _selectedOverlayId = replaceId;
      _selectedOverlayKind = TemplateEditorOverlayKind.sticker;
    } else {
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
      _session.setUserStickers([..._session.userStickers, overlay]);
      _selectedOverlayId = overlay.id;
      _selectedOverlayKind = TemplateEditorOverlayKind.sticker;

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
    if (mounted) setState(() {});
    await _refreshPreview();
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

  Future<void> _syncAllSlotLayersForRender() async {
    if (_serverProjectId == null) return;
    for (final slot in _session.slots) {
      if (_session.slotUsesUserFilters(slot.id)) {
        await _syncSlotFilters(slot.id);
      }
      if (_session.slotUsesUserEffects(slot.id)) {
        await _syncSlotEffects(slot.id);
      }
    }
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

      final hasMedia = _session.slots.any((slot) {
        final fill = _session.fills[slot.id];
        return fill != null &&
            ((fill.localFile?.path.isNotEmpty ?? false) ||
                (fill.userAssetUrl?.trim().isNotEmpty ?? false));
      });

      if (hasMedia) {
        // Gallery-style render — POST /render body only (no catalog merge).
        final apply = await vt_di.sl<OneShotRenderVideoTemplateUseCase>()(
          session: _session,
          selection: selection,
          catalogTemplateId: null,
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

      if (!mounted) return;
      setState(() {
        _busy = false;
        _exportProgress = 1;
        _exportLabel = 'Done';
      });

      // Skip in-editor server preview — studio shows local render before post.
      Navigator.of(context).pop(
        VideoTemplateEditorFinishResult(
          selection: selection.copyWith(
            projectId: _serverProjectId,
            templateId: '',
          ),
          renderedFile: hasFile ? outFile : null,
          serverExportUrl: hasUrl ? exportUrl : null,
          proceedToNext: true,
        ),
      );
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

      final useUserFilters = _session.slotUsesUserFilters(slot.id);
      final filtersToRender = _session.previewFiltersForSlot(slot.id);

      for (final filter in filtersToRender) {
        if (filter.filterName.isEmpty || filter.filterName == 'none') continue;
        final window = SlotLocalTiming.normalize(
          slotDuration: dur,
          startTime: filter.startTime,
          endTime: filter.endTime,
        );
        segments.add(
          TemplateEditorOverlaySegment(
            id: filter.id,
            slotId: slot.id,
            kind: TemplateEditorOverlayKind.filter,
            start: slotStart + window.start,
            end: slotStart + window.end,
            label: filter.displayName,
            color: TemplateEditorTheme.filterTrack,
            icon: LucideIcons.blend,
            selected: _selectedOverlayId == filter.id,
            editable: useUserFilters,
          ),
        );
      }

      final useUserEffects = _session.slotUsesUserEffects(slot.id);
      final effectsToRender = _session.previewEffectsForSlot(slot.id);

      for (final effect in effectsToRender) {
        if (effect.effectType.isEmpty || effect.effectType == 'none') continue;
        final window = SlotLocalTiming.normalize(
          slotDuration: dur,
          startTime: effect.startTime,
          endTime: effect.endTime,
        );
        segments.add(
          TemplateEditorOverlaySegment(
            id: effect.id,
            slotId: slot.id,
            kind: TemplateEditorOverlayKind.effect,
            start: slotStart + window.start,
            end: slotStart + window.end,
            label: effect.displayName,
            color: TemplateEditorTheme.effectTrack,
            icon: LucideIcons.sparkles,
            selected: _selectedOverlayId == effect.id,
            editable: useUserEffects,
          ),
        );
      }

      cursor = slotStart + dur;
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
          selected: _selectedOverlayId == t.id,
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
          selected: _selectedOverlayId == s.id,
        ),
      );
    }

    final audioTracks = _session.resolvedAudioTracks;
    if (audioTracks.isNotEmpty) {
      final track = audioTracks.first;
      final start = track.startTime.clamp(0.0, total);
      final end = safeEditorClamp(track.endTime ?? total, start + 0.2, total);
      segments.insert(
        0,
        TemplateEditorOverlaySegment(
          id: track.id,
          kind: TemplateEditorOverlayKind.audio,
          start: start.toDouble(),
          end: end.toDouble(),
          label: track.timelineLabel(totalDuration: total),
          color: TemplateEditorTheme.audioTrack,
          icon: LucideIcons.music,
          showVolumeIcon: true,
          editable: true,
          selected: _selectedOverlayId == track.id,
        ),
      );
    }

    return segments;
  }

  void _onOverlayTap(TemplateEditorOverlayKind kind, String id) {
    setState(() {
      _selectedOverlayKind = kind;
      _selectedOverlayId = id;
      _replaceOverlayId = null;
      if (kind == TemplateEditorOverlayKind.filter ||
          kind == TemplateEditorOverlayKind.effect) {
        final slotId = kind == TemplateEditorOverlayKind.filter
            ? _session.userFilters
                .where((f) => f.id == id)
                .map((f) => f.slotId)
                .firstOrNull
            : _session.userEffects
                .where((e) => e.id == id)
                .map((e) => e.slotId)
                .firstOrNull;
        if (slotId != null) {
          final idx = _session.slots.indexWhere((s) => s.id == slotId);
          if (idx >= 0) _selectedSlotIndex = idx;
        }
      }
    });
  }

  Widget? _buildLayerToolbar() {
    final kind = _selectedOverlayKind;
    final id = _selectedOverlayId;
    if (kind == null || id == null) return null;

    switch (kind) {
      case TemplateEditorOverlayKind.filter:
        return TemplateEditorLayerToolbar(
          replaceLabel: 'Replace filter',
          onDismiss: () => setState(_clearOverlaySelection),
          onReplace: () {
            _replaceOverlayId = id;
            setState(() => _activePanel = TemplateEditorPanel.filters);
          },
          onCopy: () {
            final copy = _session.duplicateUserFilter(id);
            if (copy == null) {
              _showSnack('Max $kMaxFiltersPerSlot filters per clip');
              return;
            }
            setState(() {
              _selectedOverlayId = copy.id;
              _selectedOverlayKind = TemplateEditorOverlayKind.filter;
            });
            unawaited(_syncSlotFilters(copy.slotId));
          },
          onDelete: () {
            if (id.startsWith('recipe_flt_')) {
              final slotId = _slotIdForRecipeFilterOverlay(id);
              if (slotId != null) {
                _session.clearUserFiltersForSlot(slotId);
                unawaited(_syncSlotFilters(slotId));
                _commitLookPreview(slotId, seekForEffect: false);
              }
            } else {
              final track = _session.userFilters
                  .where((f) => f.id == id)
                  .firstOrNull;
              _session.removeUserFilter(id);
              if (track != null) {
                unawaited(_syncSlotFilters(track.slotId));
                _commitLookPreview(track.slotId, seekForEffect: false);
              } else {
                unawaited(_refreshPreview());
              }
            }
            _clearOverlaySelection();
            setState(() {});
          },
          onLayers: () => _showFxLayersSheet(isFilter: true),
          layersEnabled: _session.userFilters.length > 1,
          copyEnabled: _session.filtersForSlot(
                _session.userFilters
                        .where((f) => f.id == id)
                        .map((f) => f.slotId)
                        .firstOrNull ??
                    '',
              ).length <
              kMaxFiltersPerSlot,
        );
      case TemplateEditorOverlayKind.effect:
        return TemplateEditorLayerToolbar(
          replaceLabel: 'Replace effect',
          onDismiss: () => setState(_clearOverlaySelection),
          onReplace: () {
            _replaceOverlayId = id;
            setState(() => _activePanel = TemplateEditorPanel.effects);
          },
          onCopy: () {
            final copy = _session.duplicateUserEffect(id);
            if (copy == null) {
              _showSnack('Max $kMaxEffectsPerSlot effects per clip');
              return;
            }
            setState(() {
              _selectedOverlayId = copy.id;
              _selectedOverlayKind = TemplateEditorOverlayKind.effect;
            });
            unawaited(_syncSlotEffects(copy.slotId));
          },
          onDelete: () {
            if (id.startsWith('recipe_fx_')) {
              final slotId = _slotIdForRecipeEffectOverlay(id);
              if (slotId != null) {
                _session.clearUserEffectsForSlot(slotId);
                unawaited(_syncSlotEffects(slotId));
                _commitLookPreview(slotId, seekForEffect: false);
              }
            } else {
              final track = _session.userEffects
                  .where((e) => e.id == id)
                  .firstOrNull;
              _session.removeUserEffect(id);
              if (track != null) {
                unawaited(_syncSlotEffects(track.slotId));
                _commitLookPreview(track.slotId, seekForEffect: false);
              } else {
                unawaited(_refreshPreview());
              }
            }
            _clearOverlaySelection();
            setState(() {});
          },
          onLayers: () => _showFxLayersSheet(isFilter: false),
          layersEnabled: _session.userEffects.length > 1,
          copyEnabled: _session.effectsForSlot(
                _session.userEffects
                        .where((e) => e.id == id)
                        .map((e) => e.slotId)
                        .firstOrNull ??
                    '',
              ).length <
              kMaxEffectsPerSlot,
        );
      case TemplateEditorOverlayKind.audio:
        return TemplateEditorLayerToolbar(
          replaceLabel: 'Replace music',
          onDismiss: () => setState(_clearOverlaySelection),
          onReplace: () => unawaited(_pickAudio(replaceTrackId: id)),
          onCopy: () {},
          onDelete: () {
            _session.clearUserAudios();
            _clearOverlaySelection();
            unawaited(SoundAudioPreview.stop());
            unawaited(_refreshPreview());
            setState(() {});
          },
          copyEnabled: false,
        );
      case TemplateEditorOverlayKind.text:
        return TemplateEditorLayerToolbar(
          replaceLabel: 'Replace text',
          onDismiss: () => setState(_clearOverlaySelection),
          onReplace: () => unawaited(_addTextOverlay(replaceId: id)),
          onCopy: () {},
          onDelete: () {
            _session.removeUserText(id);
            _clearOverlaySelection();
            unawaited(_refreshPreview());
            setState(() {});
          },
          copyEnabled: false,
        );
      case TemplateEditorOverlayKind.sticker:
        return TemplateEditorLayerToolbar(
          replaceLabel: 'Replace sticker',
          onDismiss: () => setState(_clearOverlaySelection),
          onReplace: () => unawaited(_addStickerOverlay(replaceId: id)),
          onCopy: () {},
          onDelete: () {
            _session.removeUserSticker(id);
            _clearOverlaySelection();
            unawaited(_refreshPreview());
            setState(() {});
          },
          copyEnabled: false,
        );
    }
  }

  Future<void> _showFxLayersSheet({required bool isFilter}) async {
    final slot = _selectedSlot;
    if (isFilter) {
      final layers = _session.filtersForSlot(slot.id);
      if (layers.isEmpty) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: TemplateEditorTheme.panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Filter layers',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                for (final layer in layers)
                  ListTile(
                    title: Text(
                      layer.displayName,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: _selectedOverlayId == layer.id
                        ? const Icon(LucideIcons.check, color: Colors.white)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedOverlayId = layer.id;
                        _selectedOverlayKind = TemplateEditorOverlayKind.filter;
                      });
                    },
                  ),
              ],
            ),
          );
        },
      );
      return;
    }

    final effectLayers = _session.effectsForSlot(slot.id);
    if (effectLayers.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TemplateEditorTheme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Effect layers',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              for (final layer in effectLayers)
                ListTile(
                  title: Text(
                    layer.displayName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: _selectedOverlayId == layer.id
                      ? const Icon(LucideIcons.check, color: Colors.white)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedOverlayId = layer.id;
                      _selectedOverlayKind = TemplateEditorOverlayKind.effect;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
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
    start = safeEditorClamp(start, 0.0, total);
    end = safeEditorClamp(end, start + 0.2, total);

    switch (kind) {
      case TemplateEditorOverlayKind.filter:
        final track = _session.userFilters
            .where((f) => f.id == id)
            .firstOrNull;
        if (track == null) return;
        final slotStart = _slotStartOnTimeline(track.slotId);
        final slotDur = _slotDuration(track.slotId);
        final window = SlotLocalTiming.normalize(
          slotDuration: slotDur,
          startTime: safeEditorClamp(start - slotStart, 0.0, slotDur),
          endTime: safeEditorClamp(end - slotStart, 0.05, slotDur),
        );
        _session.patchUserFilterTiming(
          id,
          startTime: window.start,
          endTime: window.end,
        );
        _debounceLookTimingSync(kind, id);
      case TemplateEditorOverlayKind.effect:
        final track = _session.userEffects
            .where((e) => e.id == id)
            .firstOrNull;
        if (track == null) return;
        final slotStart = _slotStartOnTimeline(track.slotId);
        final slotDur = _slotDuration(track.slotId);
        final window = SlotLocalTiming.normalize(
          slotDuration: slotDur,
          startTime: safeEditorClamp(start - slotStart, 0.0, slotDur),
          endTime: safeEditorClamp(end - slotStart, 0.05, slotDur),
        );
        _session.patchUserEffectTiming(
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
        _session.patchUserAudioTiming(id: id, startTime: start, endTime: end);
    }
    _preview?.reloadTimeline();
    if (kind == TemplateEditorOverlayKind.filter ||
        kind == TemplateEditorOverlayKind.effect) {
      final preview = _preview;
      if (preview != null) {
        final slotId = kind == TemplateEditorOverlayKind.filter
            ? _session.userFilters
                .where((f) => f.id == id)
                .map((f) => f.slotId)
                .firstOrNull
            : _session.userEffects
                .where((e) => e.id == id)
                .map((e) => e.slotId)
                .firstOrNull;
        if (slotId != null) {
          unawaited(
            preview
                .applyLookPreview(slotId: slotId, targetTime: preview.playhead)
                .then((_) {
                  if (mounted) setState(() {});
                }),
          );
        }
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final aspect = canvasW / canvasH;
          var w = constraints.maxWidth;
          var h = w / aspect;
          if (constraints.maxHeight.isFinite && h > constraints.maxHeight) {
            h = constraints.maxHeight;
            w = h * aspect;
          }
          return Center(
            child: SizedBox(
              width: w,
              height: h,
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
        },
      ),
    );
  }

  Widget? _buildActiveSheet() {
    switch (_activePanel) {
      case TemplateEditorPanel.filters:
        return TemplateEditorPresetSheet(
          title: _replaceOverlayId != null
              ? 'Replace filter'
              : 'Add filter · clip ${_selectedSlotIndex + 1}',
          presets: _filterPresets,
          selectedId: _selectedFilterId,
          onSelected: _applyFilter,
          onClear: () => _applyFilter(kFallbackFilterPresets.first),
          onClose: () => setState(() {
            _activePanel = null;
            _replaceOverlayId = null;
          }),
        );
      case TemplateEditorPanel.effects:
        return TemplateEditorPresetSheet(
          title: _replaceOverlayId != null
              ? 'Replace effect'
              : 'Add effect · clip ${_selectedSlotIndex + 1}',
          presets: _effectPresets,
          selectedId: _selectedEffectId,
          onSelected: _applyEffect,
          onClear: () => _applyEffect(kFallbackEffectPresets.first),
          onClose: () => setState(() {
            _activePanel = null;
            _replaceOverlayId = null;
          }),
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
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxPreviewH = constraints.maxHeight * 0.58;
                  return Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxPreviewH.clamp(180.0, 520.0),
                        ),
                        child: Center(child: _buildPreview()),
                      ),
                      if (!_showRenderedPreview && preview != null)
                        Expanded(
                          child: ListenableBuilder(
                            listenable: preview,
                            builder: (context, _) {
                              final total = max(preview.duration, 0.01);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  Expanded(
                                    child: TemplateEditorTimeline(
                                      slots: _session.slots,
                                      fills: _session.fills,
                                      playhead: preview.playhead,
                                      totalDuration: total,
                                      selectedSlotIndex: _selectedSlotIndex,
                                      overlaySegments:
                                          _buildOverlaySegments(total),
                                      onSlotTap: _busy
                                          ? null
                                          : _pickMediaForSlot,
                                      onAddMedia: _busy
                                          ? null
                                          : () => _pickMediaForSlot(
                                                _selectedSlotIndex,
                                              ),
                                      onSeek: _onSeek,
                                      onOverlayRangeChanged: _busy
                                          ? null
                                          : _onOverlayRangeChanged,
                                      onOverlayTap:
                                          _busy ? null : _onOverlayTap,
                                      selectedOverlayId: _selectedOverlayId,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      else if (!_showRenderedPreview)
                        Flexible(
                          child: SingleChildScrollView(
                            child: TemplateEditorTimeline(
                              slots: _session.slots,
                              fills: _session.fills,
                              playhead: 0,
                              totalDuration: max(
                                widget.recipe.duration ?? 5,
                                0.01,
                              ),
                              selectedSlotIndex: _selectedSlotIndex,
                              overlaySegments: _buildOverlaySegments(
                                max(widget.recipe.duration ?? 5, 0.01),
                              ),
                              onSlotTap: _busy ? null : _pickMediaForSlot,
                              onAddMedia: _busy
                                  ? null
                                  : () => _pickMediaForSlot(_selectedSlotIndex),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (!_showRenderedPreview)
              _buildLayerToolbar() ??
                  TemplateEditorToolbar(
                    editable: _editable,
                    activePanel: _activePanel,
                    onPanelSelected: (panel) {
                      if (_busy) return;
                      _clearOverlaySelection();
                      if (panel == TemplateEditorPanel.edit) {
                        unawaited(_pickMediaForSlot(_selectedSlotIndex));
                        return;
                      }
                      if (panel == TemplateEditorPanel.audio) {
                        unawaited(_pickAudio());
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
