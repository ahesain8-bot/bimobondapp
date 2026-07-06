import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/camera_studio/presentation/di/camera_studio_injector.dart'
    as camera_studio_di;
import 'package:bimobondapp/app/camera_studio/presentation/services/camera_studio_catalog_loader.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_import_flow.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_app_loading.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_compositor.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_compositor.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_strip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_sheets.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_studio_editor_strip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_studio_preview.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_camera_editor.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Instagram-style editor for gallery photos and videos before posting.
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

class _MediaStudioEditorScreenState extends State<MediaStudioEditorScreen> {
  late List<MediaItemEditState> _states;
  late int _currentIndex;

  CameraFilterCategory _filterCategory = CameraFilterCategory.trending;
  String _filterCategorySlug = 'trending';
  AwesomeFilter _selectedFilter = AwesomeFilter.None;
  CameraEffectId? _selectedEffect;
  bool _beautyEnabled = false;
  bool _showFilters = true;
  bool _filtersReady = false;
  bool _isProcessing = false;

  MediaItemEditState get _currentState => _states[_currentIndex];

  AwesomeFilter get _effectiveFilter {
    if (_selectedFilter.name != AwesomeFilter.None.name) return _selectedFilter;
    if (_beautyEnabled) return CameraFilterCatalog.beautyFilter.filter;
    return AwesomeFilter.None;
  }

  CameraEffectDefinition? get _activeEffect =>
      CameraEffectsCatalog.byId(_selectedEffect);

  @override
  void initState() {
    super.initState();
    _states = widget.items.map(MediaItemEditState.fromItem).toList();
    if (widget.initialEdit != null && _states.isNotEmpty) {
      _states[0] = MediaItemEditState.fromItemWithSeed(
        _states[0].item,
        widget.initialEdit!,
      );
    }
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _applyStateToUi(_states[_currentIndex]);
    unawaited(_loadCatalog());
  }

  Future<void> _loadCatalog() async {
    await camera_studio_di.sl<CameraStudioCatalogLoader>().ensureLoaded();
    if (!mounted) return;
    final categories = CameraFilterCatalog.filterCategories;
    setState(() {
      _filtersReady = CameraFilterCatalog.hasBackendCatalog;
      if (categories.isNotEmpty) {
        final slugs = categories.map((c) => c.slug).toList();
        if (!slugs.contains(_filterCategorySlug)) {
          _filterCategorySlug = categories.first.slug;
        }
        _filterCategory =
            CameraFilterCatalog.categoryFromSlug(_filterCategorySlug) ??
            CameraFilterCategory.trending;
      }
    });
  }

  void _applyStateToUi(MediaItemEditState state) {
    _selectedFilter = state.filter;
    _selectedEffect = state.effect;
    _beautyEnabled = state.beautyEnabled;
    _filterCategory = state.filterCategory;
    _filterCategorySlug = state.filterCategory.name;
  }

  void _saveUiToCurrentState() {
    final effect =
        _selectedEffect == null || _selectedEffect == CameraEffectId.none
        ? null
        : _selectedEffect;
    _states[_currentIndex] = MediaItemEditState(
      item: _states[_currentIndex].item,
      filter: _selectedFilter,
      effect: effect,
      beautyEnabled: _beautyEnabled,
      filterCategory: _filterCategory,
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

  Future<List<File>> _exportAll() async {
    _saveUiToCurrentState();
    final results = <File>[];

    for (final state in _states) {
      var file = state.sourceFile;
      final isVideo = state.isVideo;
      final filter = state.effectiveFilter;
      final hasFilter = CameraFilterCompositor.isActiveFilter(filter);
      final hasEffect =
          state.effect != null && state.effect != CameraEffectId.none;

      if (hasFilter) {
        file = await CameraFilterCompositor.applyIfNeeded(
          input: file,
          filter: filter,
          isVideo: isVideo,
        );
      }
      if (hasEffect) {
        file = await CameraEffectCompositor.applyIfNeeded(
          input: file,
          effectId: state.effect,
          isVideo: isVideo,
        );
      }
      results.add(file);
    }

    return results;
  }

  Future<void> _onNext() async {
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
          ),
        );
        return;
      }

      if (widget.isStory) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => StoryCameraEditor(
              file: files.first,
              type: widget.items.first.type,
              sound: widget.initialSound,
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
          'initialSound': widget.initialSound,
        },
      );
    } catch (e) {
      if (!mounted) return;
      PopupDialogs.showErrorDialog(context, '$e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _applyFilter(CameraFilterPreset preset) {
    setState(() {
      _selectedFilter = preset.filter;
      _saveUiToCurrentState();
    });
  }

  void _toggleBeauty() {
    setState(() {
      _beautyEnabled = !_beautyEnabled;
      _saveUiToCurrentState();
    });
  }

  void _selectEffect(CameraEffectId? effect) {
    setState(() {
      _selectedEffect = effect;
      _saveUiToCurrentState();
    });
  }

  String _filterLabel(AppLocalizations l10n, CameraFilterPreset preset) {
    return preset.label(l10n: l10n, originalLabel: l10n.cameraFilterOriginal);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filters = CameraFilterCatalog.forCategorySlug(_filterCategorySlug);
    final currentItem = _currentState.item;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MediaStudioPreview(
            key: ValueKey('${currentItem.file.path}-$_currentIndex'),
            file: currentItem.file,
            isVideo: currentItem.isVideo,
            filter: _effectiveFilter,
            effect: _activeEffect,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isProcessing ? null : () => context.pop(),
                        icon: const Icon(LucideIcons.x, color: Colors.white),
                      ),
                      if (widget.items.length > 1)
                        Text(
                          '${_currentIndex + 1}/${widget.items.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _isProcessing ? null : _onNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          l10n.continueAction,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                MediaStudioEditorStrip(
                  items: _states.map((s) => s.item).toList(growable: false),
                  selectedIndex: _currentIndex,
                  onSelected: _selectIndex,
                ),
                if (widget.items.length > 1) const SizedBox(height: 10),
                if (_showFilters && _filtersReady) ...[
                  CameraFilterCategoryTabs(
                    categories: CameraFilterCatalog.filterCategories,
                    selectedSlug: _filterCategorySlug,
                    labelBuilder: (category) =>
                        CameraFilterCatalog.labelForCategory(l10n, category),
                    onSelected: (slug) => setState(() {
                      _filterCategorySlug = slug;
                      _filterCategory =
                          CameraFilterCatalog.categoryFromSlug(slug) ??
                          CameraFilterCategory.trending;
                    }),
                  ),
                  const SizedBox(height: 10),
                  CameraFilterStrip(
                    presets: filters,
                    selected: _selectedFilter,
                    labelBuilder: (p) => _filterLabel(l10n, p),
                    onSelected: _applyFilter,
                  ),
                  const SizedBox(height: 12),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ToolChip(
                        icon: LucideIcons.sparkles,
                        label: l10n.cameraEffects,
                        active:
                            _selectedEffect != null &&
                            _selectedEffect != CameraEffectId.none,
                        onTap: _isProcessing
                            ? null
                            : () => CameraStudioSheets.showEffectsPicker(
                                context,
                                l10n: l10n,
                                selectedEffect: _selectedEffect,
                                onSelected: _selectEffect,
                              ),
                      ),
                      _ToolChip(
                        icon: LucideIcons.star,
                        label: l10n.cameraBeauty,
                        active: _beautyEnabled,
                        onTap: _isProcessing ? null : _toggleBeauty,
                      ),
                      _ToolChip(
                        icon: LucideIcons.slidersHorizontal,
                        label: l10n.cameraFilters,
                        active: _showFilters,
                        onTap: _isProcessing
                            ? null
                            : () =>
                                  setState(() => _showFilters = !_showFilters),
                      ),
                    ],
                  ),
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

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white24 : Colors.white12,
              border: active
                  ? Border.all(color: Colors.redAccent, width: 2)
                  : null,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
