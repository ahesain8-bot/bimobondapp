import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/ar_camera/ar_color_filter_matrix.dart';
import 'package:bimobondapp/app/ar_camera/ar_color_filters_panel.dart';
import 'package:bimobondapp/app/ar_camera/ar_effects_picker_sheet.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_import_flow.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_app_loading.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_studio_editor_chrome.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_studio_preview.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_camera_editor.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_sheet.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// TikTok-style editor — same AR filters / effects / beauty behavior as camera.
class MediaStudioEditorScreen extends StatefulWidget {
  const MediaStudioEditorScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.isStory = false,
    this.initialSound,
    this.popOnDone = false,
    this.initialEdit,
  });

  final List<GalleryMediaItem> items;
  final int initialIndex;
  final bool isStory;
  final SoundEntity? initialSound;
  final bool popOnDone;
  final MediaEditorSeed? initialEdit;

  @override
  State<MediaStudioEditorScreen> createState() =>
      _MediaStudioEditorScreenState();
}

class _MediaStudioEditorScreenState extends State<MediaStudioEditorScreen>
    with FeedPlaybackBlocker {
  static const _maxFiles = 5;

  late List<MediaItemEditState> _states;
  late int _currentIndex;
  SoundEntity? _selectedSound;

  String _arFilterId = 'none';
  String _arColorCategoryId = 'portrait';
  double _arFilterIntensity = 1.0;
  bool _alreadyBaked = false;
  String _bakedFilterId = 'none';
  bool _showFilters = false;
  bool _showEffects = false;
  bool _isProcessing = false;

  MediaItemEditState get _currentState => _states[_currentIndex];

  bool get _beautyEnabled => _arFilterId == 'whitening';

  bool get _hasActiveEffect =>
      _arFilterId != 'none' && !ArFilterCatalog.isColorFilter(_arFilterId);

  bool get _hasActiveColorFilter => ArFilterCatalog.isColorFilter(_arFilterId);

  /// Apply Flutter color preview only when grade isn't already in the pixels
  /// or the user changed away from the baked id.
  bool get _applyArColorPreview {
    if (!_hasActiveColorFilter) return false;
    if (!_alreadyBaked) return true;
    return _arFilterId != _bakedFilterId;
  }

  int get _maxFilesLimit => widget.isStory ? 1 : _maxFiles;

  @override
  void initState() {
    super.initState();
    _selectedSound = widget.initialSound;
    _states = widget.items.map(MediaItemEditState.fromItem).toList();
    if (widget.initialEdit != null && _states.isNotEmpty) {
      _states[0] = MediaItemEditState.fromItemWithSeed(
        _states[0].item,
        widget.initialEdit!,
      );
    }
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _applyStateToUi(_states[_currentIndex]);
  }

  void _applyStateToUi(MediaItemEditState state) {
    _arFilterId = state.arFilterId;
    _arColorCategoryId = state.arColorCategoryId;
    _arFilterIntensity = state.arFilterIntensity;
    _alreadyBaked = state.alreadyBaked;
    _bakedFilterId = state.bakedArFilterId;
  }

  void _saveUiToCurrentState() {
    _states[_currentIndex] = _states[_currentIndex].copyWith(
      arFilterId: _arFilterId,
      arColorCategoryId: _arColorCategoryId,
      arFilterIntensity: _arFilterIntensity,
      alreadyBaked: _alreadyBaked,
      bakedArFilterId: _bakedFilterId,
      beautyEnabled: _beautyEnabled,
      effectSlug: _hasActiveEffect ? _arFilterId : null,
    );
  }

  void _selectIndex(int index) {
    if (index == _currentIndex || index < 0 || index >= _states.length) {
      return;
    }
    _saveUiToCurrentState();
    setState(() {
      _currentIndex = index;
      _applyStateToUi(_states[_currentIndex]);
    });
  }

  Future<File> _exportCurrentWithColorIfNeeded(MediaItemEditState state) async {
    final needsColorExport = ArFilterCatalog.isColorFilter(state.arFilterId) &&
        (!state.alreadyBaked || state.arFilterId != state.bakedArFilterId);
    if (!needsColorExport || state.isVideo) {
      return state.sourceFile;
    }
    return _bakeColorFilterToFile(
      state.sourceFile,
      state.arFilterId,
      state.arFilterIntensity,
    );
  }

  Future<File> _bakeColorFilterToFile(
    File input,
    String filterId,
    double intensity,
  ) async {
    final colorFilter = ArColorFilterMatrix.preview(
      filterId,
      intensity: intensity,
    );
    if (colorFilter == null) return input;

    final bytes = await input.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..colorFilter = colorFilter;
    canvas.drawImage(image, Offset.zero, paint);
    final picture = recorder.endRecording();
    final out = await picture.toImage(image.width, image.height);
    image.dispose();
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    if (data == null) return input;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/ar_edit_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
  }

  Future<List<File>> _exportAll() async {
    _saveUiToCurrentState();
    final results = <File>[];
    for (final state in _states) {
      results.add(await _exportCurrentWithColorIfNeeded(state));
    }
    return results;
  }

  Future<void> _finishAsPost({required bool asStory}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final files = await _exportAll();
      if (!mounted) return;

      if (widget.popOnDone) {
        context.pop(
          MediaStudioExportResult(
            files: files,
            filterName: primaryFilterNameFromStates(_states),
            filterCategory: primaryFilterCategoryFromStates(_states),
            effectSlug: primaryEffectSlugFromStates(_states),
            beautyEnabled: _states.any((s) => s.beautyEnabled),
            arFilterId: primaryArFilterIdFromStates(_states),
          ),
        );
        return;
      }

      final goStory = asStory || widget.isStory;
      if (goStory) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => StoryCameraEditor(
              file: files.first,
              type: widget.items.first.type,
              sound: _selectedSound,
              onRetake: () => context.pop(),
            ),
          ),
        );
        return;
      }

      final type = MediaGalleryImportFlow.resolvePostType(files);
      context.pushReplacementNamed(
        'add_post',
        extra: {
          'files': files,
          'type': type,
          'isStory': false,
          'initialSound': _selectedSound,
          'filterName': primaryFilterNameFromStates(_states),
          'filterCategory': primaryFilterCategoryFromStates(_states).name,
          'effectSlug': primaryEffectSlugFromStates(_states),
          'beautyEnabled': _states.any((s) => s.beautyEnabled),
          'arFilterId': primaryArFilterIdFromStates(_states),
        },
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _onNext() => _finishAsPost(asStory: false);

  Future<void> _onYourStory() => _finishAsPost(asStory: true);

  void _toggleBeauty() {
    setState(() {
      if (_arFilterId == 'whitening') {
        _arFilterId = 'none';
      } else {
        _arFilterId = 'whitening';
        _arColorCategoryId = 'portrait';
        _showFilters = true;
        _showEffects = false;
      }
      _saveUiToCurrentState();
    });
  }

  void _selectArFilter(String id) {
    setState(() {
      _arFilterId = id;
      if (ArFilterCatalog.isColorFilter(id)) {
        _showEffects = false;
      }
      _saveUiToCurrentState();
    });
  }

  void _selectEffect(String id) {
    setState(() {
      _arFilterId = id;
      _showEffects = false;
      if (ArFilterCatalog.isColorFilter(id)) {
        _showFilters = true;
      }
      _saveUiToCurrentState();
    });
  }

  Future<void> _pickSound() async {
    final picked = await SoundPickerSheet.show(
      context,
      initialSelection: _selectedSound,
    );
    if (!mounted) return;
    setState(() => _selectedSound = picked);
  }

  void _clearSound() => setState(() => _selectedSound = null);

  Future<void> _shareCurrent() async {
    final file = _currentState.sourceFile;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }

  void _showComingSoon(AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.mediaEditorComingSoon)),
    );
  }

  Future<void> _addMedia() async {
    final remaining = _maxFilesLimit - _states.length;
    if (remaining <= 0) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fieldIsRequired('Maximum $_maxFilesLimit'))),
      );
      return;
    }
    final picked = await MediaGalleryPicker.pickMixed(limit: remaining);
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _states.addAll(picked.map(MediaItemEditState.fromItem));
      _currentIndex = _states.length - 1;
      _applyStateToUi(_states[_currentIndex]);
    });
  }

  Future<void> _openEffects(AppLocalizations l10n) async {
    setState(() {
      _showEffects = true;
      _showFilters = false;
    });
    await ArEffectsPickerSheet.show(
      context,
      l10n: l10n,
      selectedEffectId: _hasActiveEffect ? _arFilterId : 'none',
      onSelected: _selectEffect,
    );
    if (mounted) setState(() => _showEffects = false);
  }

  Future<void> _showSettingsSheet(AppLocalizations l10n) async {
    await GlassBottomSheet.showActions<void>(
      context,
      title: l10n.moreOptionsLabel,
      children: [
        GlassBottomSheetActionTile(
          icon: LucideIcons.sparkles,
          label: l10n.cameraBeauty,
          subtitle: _beautyEnabled ? l10n.settingsOn : l10n.settingsOff,
          isSelected: _beautyEnabled,
          onTap: () {
            Navigator.pop(context);
            _toggleBeauty();
          },
        ),
        GlassBottomSheetActionTile(
          icon: LucideIcons.blend,
          label: l10n.cameraFilters,
          onTap: () {
            Navigator.pop(context);
            setState(() {
              _showFilters = true;
              _showEffects = false;
            });
          },
        ),
        GlassBottomSheetActionTile(
          icon: LucideIcons.wandSparkles,
          label: l10n.cameraEffects,
          onTap: () {
            Navigator.pop(context);
            _openEffects(l10n);
          },
        ),
      ],
    );
  }

  List<MediaStudioSideTool> _sideTools(AppLocalizations l10n) {
    // Same tool semantics as live camera: Beauty / Filters / Effects.
    return [
      MediaStudioSideTool(
        icon: LucideIcons.share2,
        label: l10n.mediaEditorShare,
        onTap: _isProcessing ? () {} : _shareCurrent,
      ),
      MediaStudioSideTool(
        icon: LucideIcons.sparkles,
        label: l10n.cameraBeauty,
        active: _beautyEnabled,
        onTap: _isProcessing ? () {} : _toggleBeauty,
      ),
      MediaStudioSideTool(
        icon: LucideIcons.blend,
        label: l10n.cameraFilters,
        active: _showFilters || _hasActiveColorFilter,
        onTap: _isProcessing
            ? () {}
            : () => setState(() {
                  _showFilters = !_showFilters;
                  if (_showFilters) _showEffects = false;
                }),
      ),
      MediaStudioSideTool(
        icon: LucideIcons.wandSparkles,
        label: l10n.cameraEffects,
        active: _showEffects || _hasActiveEffect,
        onTap: _isProcessing ? () {} : () => _openEffects(l10n),
      ),
      MediaStudioSideTool(
        icon: LucideIcons.layoutTemplate,
        label: l10n.cameraLayout,
        onTap: () => _showComingSoon(l10n),
      ),
      MediaStudioSideTool(
        icon: LucideIcons.ratio,
        label: l10n.cameraAspectRatio,
        onTap: () => _showComingSoon(l10n),
      ),
      MediaStudioSideTool(
        icon: LucideIcons.type,
        label: l10n.mediaEditorText,
        useAa: true,
        onTap: () => _showComingSoon(l10n),
      ),
      MediaStudioSideTool(
        icon: LucideIcons.crop,
        label: l10n.mediaEditorCrop,
        onTap: () => _showComingSoon(l10n),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentItem = _currentState.item;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final soundLabel = _selectedSound?.name.trim().isNotEmpty == true
        ? _selectedSound!.name
        : l10n.cameraAddSound;
    final authState = context.watch<AuthBloc>().state;
    final avatarUrl =
        authState is AuthSuccess ? authState.user.avatarUrl : null;
    final selectedColorId =
        _hasActiveColorFilter ? _arFilterId : 'none';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MediaStudioPreview(
            key: ValueKey(
              '${currentItem.file.path}-$_currentIndex-'
              '$_arFilterId-$_arFilterIntensity-$_applyArColorPreview',
            ),
            file: currentItem.file,
            isVideo: currentItem.isVideo,
            arFilterId: selectedColorId,
            arFilterIntensity: _arFilterIntensity,
            applyArColorPreview: _applyArColorPreview,
          ),
          SafeArea(
            child: Column(
              children: [
                MediaStudioTopBar(
                  soundLabel: soundLabel,
                  onBack: _isProcessing ? () {} : () => context.pop(),
                  onSoundTap: _isProcessing ? () {} : _pickSound,
                  onClearSound: _selectedSound == null || _isProcessing
                      ? null
                      : _clearSound,
                  onSettingsTap:
                      _isProcessing ? () {} : () => _showSettingsSheet(l10n),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 8,
                        bottom: 8,
                        right: isRtl ? null : 0,
                        left: isRtl ? 0 : null,
                        child: MediaStudioSideRail(tools: _sideTools(l10n)),
                      ),
                    ],
                  ),
                ),
                if (_showFilters)
                  ArColorFiltersPanel(
                    selectedFilterId: selectedColorId,
                    selectedCategoryId: _arColorCategoryId,
                    intensity: _arFilterIntensity,
                    onCategorySelected: (id) => setState(() {
                      _arColorCategoryId = id;
                      _saveUiToCurrentState();
                    }),
                    onFilterSelected: _selectArFilter,
                    onIntensityChanged: (value) => setState(() {
                      _arFilterIntensity = value;
                      _saveUiToCurrentState();
                    }),
                    onClear: () => _selectArFilter('none'),
                  ),
                MediaStudioClipDock(
                  items: _states.map((s) => s.item).toList(growable: false),
                  selectedIndex: _currentIndex,
                  onSelected: _selectIndex,
                  onAdd: _isProcessing ? () {} : _addMedia,
                ),
                MediaStudioBottomActions(
                  yourStoryLabel: l10n.messagesYourStory,
                  nextLabel: l10n.nextAction,
                  avatarUrl: avatarUrl,
                  enabled: !_isProcessing,
                  onYourStory: _onYourStory,
                  onNext: _onNext,
                ),
              ],
            ),
          ),
          if (_isProcessing) CameraAppLoading(message: l10n.promoteProcessing),
        ],
      ),
    );
  }
}
