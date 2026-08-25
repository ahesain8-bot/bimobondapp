import 'dart:async';
import 'dart:math';

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
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
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_playback_bar.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_preset_sheet.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_timeline.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_toolbar.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/video_template_composed_preview.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  });

  final VideoTemplateRecipeEntity recipe;
  final VideoTemplateCardEntity? card;
  final VideoTemplateSelection? initialSelection;
  final Map<String, SlotFillEntry>? initialFills;
  final String? projectId;
  final TemplateEditableFlags? editable;

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
  int _selectedSlotIndex = 0;
  TemplateEditorPanel? _activePanel;
  String? _serverProjectId;

  List<TemplatePresetItem> _filterPresets = kFallbackFilterPresets;
  List<TemplatePresetItem> _effectPresets = kFallbackEffectPresets;
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
    _serverProjectId = VideoTemplateProjectIds.normalizeServerId(
      widget.projectId ?? widget.initialSelection?.projectId,
    );
    _session = _engine.open(
      widget.recipe,
      projectId: _serverProjectId,
    );
    if (widget.initialFills != null) {
      _session.fills = Map<String, SlotFillEntry>.from(widget.initialFills!);
    }
    _bootstrap();
    unawaited(_loadPresets());
    unawaited(_ensureServerProject());
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
    if (_editorAudioLabel != null && _session.userAudioTiming == null) {
      final total = max(preview.duration, 0.01);
      _session.patchUserAudioTiming(startTime: 0, endTime: total);
    }
  }

  Future<void> _ensureServerProject() async {
    if (_serverProjectId != null) return;
    final result = await vt_di.sl<CreateVideoTemplateProjectUseCase>()(
      templateId: widget.recipe.id,
      title: widget.recipe.name,
    );
    if (!mounted) return;
    result.fold((_) {}, (project) {
      _serverProjectId = project.id;
      _session.projectId = project.id;
      if (project.editable != null) {
        setState(() => _editable = project.editable!);
      }
    });
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
    _preview?.dispose();
    _session.dispose();
    super.dispose();
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

  Future<void> _refreshPreview({bool reattachMedia = false}) async {
    final preview = _preview;
    if (preview == null) return;
    if (reattachMedia) {
      await preview.attach();
    } else {
      preview.reloadTimeline();
    }
    if (mounted) setState(() {});
  }

  (double start, double end) _slotRelativeWindow(String slotId) {
    final slotStart = _slotStartOnTimeline(slotId);
    final slotDur = _slotDuration(slotId);
    final playhead = _preview?.playhead ?? 0;
    final localStart = (playhead - slotStart).clamp(0.0, slotDur);
    return (localStart, slotDur);
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
    await _session.assignFile(
      slot.id,
      file.file,
      mediaKind: file.type,
    );
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
                title: const Text('Photo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'image'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.video, color: Colors.white),
                title: const Text('Video', style: TextStyle(color: Colors.white)),
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
      final existing = _session.slotFilterOverrides[slot.id];
      final window = _slotRelativeWindow(slot.id);
      _session.setSlotFilter(
        slot.id,
        UserSlotFilterOverride(
          presetId: preset.id,
          filterName: preset.filterName ?? preset.name.toLowerCase(),
          startTime: existing?.startTime ?? window.$1,
          endTime: existing?.endTime ?? window.$2,
        ),
      );
    }
    await _refreshPreview();
    unawaited(_syncFilter(slot.id, preset));
  }

  Future<void> _applyEffect(TemplatePresetItem preset) async {
    final slot = _selectedSlot;
    if (preset.isClear) {
      _session.setSlotEffect(slot.id, null);
    } else {
      final existing = _session.slotEffectOverrides[slot.id];
      final window = _slotRelativeWindow(slot.id);
      _session.setSlotEffect(
        slot.id,
        UserSlotEffectOverride(
          presetId: preset.id,
          effectType: preset.effectType ?? preset.name.toLowerCase(),
          startTime: existing?.startTime ?? window.$1,
          endTime: existing?.endTime ?? window.$2,
        ),
      );
    }
    await _refreshPreview();
    unawaited(_syncEffect(slot.id, preset));
  }

  Future<void> _syncFilter(String slotId, TemplatePresetItem preset) async {
    final projectId = _serverProjectId;
    if (projectId == null) return;
    await _repository.putSlotFilter(
      projectId: projectId,
      slotId: slotId,
      presetId: preset.isClear ? null : preset.id,
      intensity: 1,
    );
  }

  Future<void> _syncEffect(String slotId, TemplatePresetItem preset) async {
    final projectId = _serverProjectId;
    if (projectId == null) return;
    await _repository.putSlotEffect(
      projectId: projectId,
      slotId: slotId,
      presetId: preset.isClear ? null : preset.id,
    );
  }

  Future<void> _addTextOverlay() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TemplateEditorTheme.panel,
        title: const Text('Add text', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Summer vibes ☀️',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;

    final duration = _preview?.duration ?? widget.recipe.duration ?? 5;
    final overlay = UserEditorTextOverlay(
      id: 'text_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      endTime: duration,
    );
    final next = [..._session.userTexts, overlay];
    _session.setUserTexts(next);
    await _refreshPreview();

    final projectId = _serverProjectId;
    if (projectId != null) {
      unawaited(
        _repository.createProjectText(
          projectId: projectId,
          text: text,
          endTime: duration,
        ),
      );
    }
  }

  Future<void> _addSticker(TemplatePresetItem preset) async {
    final duration = _preview?.duration ?? widget.recipe.duration ?? 5;
    final sticker = UserEditorStickerOverlay(
      id: 'stk_${DateTime.now().millisecondsSinceEpoch}',
      presetId: preset.id,
      assetUrl: preset.assetUrl,
      endTime: duration,
    );
    final next = [..._session.userStickers, sticker];
    _session.setUserStickers(next);
    setState(() => _activePanel = null);
    await _refreshPreview();

    final projectId = _serverProjectId;
    if (projectId != null) {
      unawaited(
        _repository.createProjectSticker(
          projectId: projectId,
          presetId: preset.id,
          assetUrl: preset.assetUrl,
          endTime: duration,
        ),
      );
    }
  }

  Future<void> _exportAndFinish() async {
    setState(() {
      _busy = true;
      _error = null;
      _exportProgress = 0;
    });

    final result = await _engine.export(
      _session,
      onProgress: (p) {
        if (mounted) setState(() => _exportProgress = p);
      },
    );

    if (!mounted) return;

    result.fold(
      (e) {
        setState(() {
          _busy = false;
          _error = e.userMessage;
        });
      },
      (file) {
        setState(() => _busy = false);
        final selection = (widget.initialSelection ??
                VideoTemplateSelection.fromRecipe(widget.recipe))
            .copyWith(
          projectId:
              VideoTemplateProjectIds.normalizeServerId(_session.projectId),
          recipe: widget.recipe,
        );
        Navigator.of(context).pop(selection);
      },
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
        final relStart = filter.startTime.clamp(0.0, dur);
        final relEnd = (filter.endTime ?? dur).clamp(relStart + 0.05, dur);
        segments.add(
          TemplateEditorOverlaySegment(
            id: slot.id,
            kind: TemplateEditorOverlayKind.filter,
            start: slotStart + relStart,
            end: slotStart + relEnd,
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
        final relStart = effect.startTime.clamp(0.0, dur);
        final relEnd = (effect.endTime ?? dur).clamp(relStart + 0.05, dur);
        segments.add(
          TemplateEditorOverlaySegment(
            id: slot.id,
            kind: TemplateEditorOverlayKind.effect,
            start: slotStart + relStart,
            end: slotStart + relEnd,
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

    final audioLabel = _editorAudioLabel;
    if (audioLabel != null) {
      final timing = _session.userAudioTiming;
      final start = timing?.startTime ?? 0.0;
      final end = timing?.endTime ?? total;
      segments.insert(
        0,
        TemplateEditorOverlaySegment(
          id: 'audio_main',
          kind: TemplateEditorOverlayKind.audio,
          start: start.clamp(0, total),
          end: (end > start ? end : total).clamp(0, total),
          label: audioLabel,
          color: TemplateEditorTheme.audioTrack,
          icon: LucideIcons.music,
          showVolumeIcon: true,
        ),
      );
    }

    return segments;
  }

  String? get _editorAudioLabel {
    final name = widget.recipe.sound?.name ?? widget.recipe.music?.title;
    if (name == null || name.trim().isEmpty) return null;
    return name;
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
        _session.patchSlotFilterTiming(
          id,
          startTime: (start - slotStart).clamp(0.0, slotDur),
          endTime: (end - slotStart).clamp(0.05, slotDur),
        );
      case TemplateEditorOverlayKind.effect:
        final slotStart = _slotStartOnTimeline(id);
        final slotDur = _slotDuration(id);
        _session.patchSlotEffectTiming(
          id,
          startTime: (start - slotStart).clamp(0.0, slotDur),
          endTime: (end - slotStart).clamp(0.05, slotDur),
        );
      case TemplateEditorOverlayKind.text:
        _session.patchUserTextTiming(
          id,
          startTime: start,
          endTime: end,
        );
      case TemplateEditorOverlayKind.sticker:
        _session.patchUserStickerTiming(
          id,
          startTime: start,
          endTime: end,
        );
      case TemplateEditorOverlayKind.audio:
        _session.patchUserAudioTiming(startTime: start, endTime: end);
    }
    _preview?.reloadTimeline();
    setState(() {});
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _CircleNavButton(
            icon: LucideIcons.chevronLeft,
            color: TemplateEditorTheme.accent,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          _CircleNavButton(
            icon: LucideIcons.chevronRight,
            color: TemplateEditorTheme.panelElevated,
            onPressed: _busy ? null : _exportAndFinish,
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final preview = _preview;
    final recipe = widget.recipe;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: AspectRatio(
        aspectRatio: recipe.width > 0 && recipe.height > 0
            ? recipe.width / recipe.height
            : 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: preview == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : ListenableBuilder(
                  listenable: preview,
                  builder: (context, _) {
                    return VideoTemplateComposedPreview(
                      canvasWidth:
                          recipe.width > 0 ? recipe.width : 1080,
                      canvasHeight:
                          recipe.height > 0 ? recipe.height : 1920,
                      frame: preview.frame,
                      videoController: preview.videoController,
                      imageFile: preview.imageFile,
                      decodedImage: preview.decodedImage,
                      isVideoMedia: preview.activeSlotIsVideo ||
                          preview.hasVideoSurface,
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
        return TemplateEditorStickerSheet(
          presets: _stickerPresets,
          onSelected: _addSticker,
          onClose: () => setState(() => _activePanel = null),
        );
      case TemplateEditorPanel.text:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_activePanel == TemplateEditorPanel.text) {
            setState(() => _activePanel = null);
            unawaited(_addTextOverlay());
          }
        });
        return null;
      case TemplateEditorPanel.audio:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: TemplateEditorTheme.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.music, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _editorAudioLabel ?? 'Template sound',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _activePanel = null),
                      icon: const Icon(LucideIcons.check, color: Colors.white),
                    ),
                  ],
                ),
                if (_editorAudioLabel != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Drag the blue bar handles on the timeline to set '
                    'when sound plays.',
                    style: TextStyle(
                      color: TemplateEditorTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
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
            if (preview != null)
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
                        onOverlayRangeChanged:
                            _busy ? null : _onOverlayRangeChanged,
                      ),
                    ],
                  );
                },
              )
            else
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
            if (activeSheet != null) activeSheet,
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
