import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_preview.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/camera_studio/presentation/di/camera_studio_injector.dart'
    as camera_studio_di;
import 'package:bimobondapp/app/camera_studio/presentation/services/camera_studio_catalog_loader.dart';
import 'package:bimobondapp/app/home/presentation/utils/camera_capture_utils.dart';
import 'package:bimobondapp/app/home/presentation/utils/camera_studio_permissions.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_import_flow.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_camera_editor.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_app_loading.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_asset_loader.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_compositor.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_compositor.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detector_service.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_effect_mapper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_sheets.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_sheet.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddPostCameraScreen extends StatefulWidget {
  const AddPostCameraScreen({
    super.key,
    this.isStory = false,
    this.initialSound,
    this.returnMediaOnDone = false,
    this.initialFilterName,
    this.initialFilterCategory,
  });

  final bool isStory;
  final SoundEntity? initialSound;
  final bool returnMediaOnDone;
  final String? initialFilterName;
  final CameraFilterCategory? initialFilterCategory;

  @override
  State<AddPostCameraScreen> createState() => _AddPostCameraScreenState();
}

class _AddPostCameraScreenState extends State<AddPostCameraScreen>
    with FeedPlaybackBlocker {
  CameraState? _cameraState;
  bool _pendingVideoStart = false;
  bool _returnToPhotoAfterVideo = false;
  bool _showFilters = false;
  bool _catalogLoading = true;
  bool _filtersReady = false;
  bool _beautyEnabled = false;
  bool _timerEnabled = false;
  bool _isRecording = false;
  bool _isBusy = false;
  bool _isProcessingCapture = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  Timer? _countdownTimer;
  int? _countdownValue;
  CameraFilterCategory _filterCategory = CameraFilterCategory.trending;
  String _filterCategorySlug = 'trending';
  AwesomeFilter _selectedFilter = AwesomeFilter.None;
  bool _initialFilterApplied = false;
  double _selectedZoom = CameraStudioConstants.zoomSteps[1].value;
  int _selectedDuration = CameraStudioConstants.durationOptions.first;
  double _selectedSpeed = CameraStudioConstants.speedOptions[1];
  String? _selectedEffectSlug;
  CameraStudioMode _studioMode = CameraStudioMode.video;
  SoundEntity? _selectedSound;
  File? _storyCapturedFile;
  String? _storyCapturedType;
  late final CameraFaceDetectorService _faceDetectorService;
  Type? _lastCameraStateType;
  String? _appliedFilterId;
  bool _isFrontCamera = false;
  int _workspaceTabIndex = 0;
  int _arFilterIndex = 0;
  String _arColorCategoryId = 'portrait';
  double _arFilterIntensity = 1.0;
  double _arSwipeDrag = 0;

  /// Android uses native MediaPipe/GPU AR stack from `ar_camera`.
  /// iOS keeps CamerAwesome until native port.
  bool get _useNativeArFilters =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _selectedSound = widget.initialSound;
    if (widget.initialFilterName != null &&
        CameraFilterCatalog.isUsableFilterName(widget.initialFilterName)) {
      _selectedFilter = CameraFilterCatalog.filterByName(
        widget.initialFilterName!,
      );
      _filterCategory =
          widget.initialFilterCategory ??
          CameraFilterCatalog.categoryForFilter(_selectedFilter);
      _showFilters = true;
    }
    if (widget.isStory) {
      _selectedDuration = CameraStudioConstants.durationOptions.first;
      _studioMode = CameraStudioMode.photo;
    }
    _faceDetectorService = CameraFaceDetectorService(isFrontCamera: _isFrontCamera);
    if (_useNativeArFilters) {
      _isFrontCamera = true;
      ArCameraBridge.warmup();
      ArCameraBridge.setFilter(ArFilterCatalog.items[_arFilterIndex].id);
    }
    unawaited(_loadCatalog());
  }

  Future<void> _loadCatalog() async {
    await camera_studio_di.sl<CameraStudioCatalogLoader>().ensureLoaded(
      forceRefresh: true,
    );
    if (!mounted) return;
    final categories = CameraFilterCatalog.filterCategories;
    setState(() {
      _catalogLoading = false;
      _filtersReady = CameraFilterCatalog.hasCatalog;
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

  @override
  void dispose() {
    _recordTimer?.cancel();
    _countdownTimer?.cancel();
    unawaited(_faceDetectorService.dispose());
    super.dispose();
  }

  Future<void> _importFromGallery(List<GalleryMediaItem> items) async {
    if (items.isEmpty || !mounted) return;
    setState(() => _isBusy = true);
    try {
      if (widget.returnMediaOnDone) {
        final edited = await MediaGalleryImportFlow.openBatchEditor(
          context,
          items: items,
          isStory: widget.isStory,
          initialSound: _selectedSound,
        );
        if (edited != null && mounted) {
          _returnPickedMedia(edited);
        }
        return;
      }
      await MediaGalleryImportFlow.editAndOpenComposer(
        context,
        items: items,
        isStory: widget.isStory,
        initialSound: _selectedSound,
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _returnPickedMedia(MediaStudioExportResult result) {
    if (result.files.isEmpty) return;
    context.pop(
      CameraMediaPickResult(
        files: result.files,
        type: MediaGalleryImportFlow.resolvePostType(result.files),
        filterName: result.filterName ?? _activeFilterName,
      ),
    );
  }

  String? get _activeFilterName {
    final filter = _effectiveCaptureFilter();
    if (!CameraFilterCompositor.isActiveFilter(filter)) return null;
    return filter.name;
  }

  MediaEditorSeed get _captureEditSeed => MediaEditorSeed(
    filterName: _activeFilterName,
    effectSlug: _selectedEffectSlug,
    beautyEnabled: _beautyEnabled,
    filterCategory: _filterCategory,
  );

  Future<void> _reapplySelectedFilter() async {
    final state = _cameraState;
    if (state == null) return;

    final filter = _effectiveCaptureFilter();
    final targetId = filter.id;
    if (_appliedFilterId == targetId) return;

    await state.setFilter(filter);
    _appliedFilterId = targetId;
  }

  void _syncFilterOnCameraState(CameraState state) {
    final stateType = state.runtimeType;
    if (stateType == _lastCameraStateType) return;
    _lastCameraStateType = stateType;

    state.when(
      onVideoMode: (_) {
        _appliedFilterId = null;
        unawaited(_reapplySelectedFilter());
      },
      onVideoRecordingMode: (_) {
        _appliedFilterId = null;
        unawaited(_reapplySelectedFilter());
      },
      onPhotoMode: (_) {},
      onPreparingCamera: (_) {},
      onPreviewMode: (_) {},
      onAnalysisOnlyMode: (_) {},
    );
  }

  Future<void> _openCapturedMediaEditor(
    File file, {
    required String type,
  }) async {
    final edited = await MediaGalleryImportFlow.openBatchEditor(
      context,
      items: [GalleryMediaItem(file: file, type: type)],
      isStory: widget.isStory,
      initialSound: _selectedSound,
      initialEdit: _captureEditSeed,
    );
    if (!mounted || edited == null || edited.files.isEmpty) return;

    if (widget.returnMediaOnDone) {
      _returnPickedMedia(edited);
      return;
    }

    context.pushReplacementNamed(
      'add_post',
      extra: {
        'files': edited.files,
        'type': MediaGalleryImportFlow.resolvePostType(edited.files),
        'isStory': false,
        'initialSound': _selectedSound,
        if (edited.filterName != null) 'filterName': edited.filterName,
        'filterCategory': edited.filterCategory.name,
        if (edited.effectSlug != null) 'effectSlug': edited.effectSlug,
        'beautyEnabled': edited.beautyEnabled,
      },
    );
  }

  Future<void> _pickSound() async {
    final picked = await SoundPickerSheet.show(
      context,
      initialSelection: _selectedSound,
    );
    if (!mounted) return;
    setState(() => _selectedSound = picked);
  }

  AwesomeFilter _effectiveCaptureFilter() {
    if (_selectedFilter.id != AwesomeFilter.None.id) return _selectedFilter;
    if (_beautyEnabled) return CameraFilterCatalog.beautyFilter.filter;
    return AwesomeFilter.None;
  }

  Future<void> _onMediaCapture(MediaCapture capture) async {
    if (!mounted) return;

    if (capture.status == MediaCaptureStatus.failure) {
      if (_isBusy || _isProcessingCapture) {
        setState(() {
          _isBusy = false;
          _isProcessingCapture = false;
        });
      }
      return;
    }
    if (capture.status != MediaCaptureStatus.success) return;

    final path = capture.captureRequest.when(
      single: (single) => single.file?.path,
      multiple: (multiple) => multiple.fileBySensor.values
          .firstWhere((file) => file?.path != null, orElse: () => null)
          ?.path,
    );

    if (path == null) {
      if (_isBusy || _isProcessingCapture) {
        setState(() {
          _isBusy = false;
          _isProcessingCapture = false;
        });
      }
      return;
    }

    if (_returnToPhotoAfterVideo && capture.isVideo) {
      _returnToPhotoAfterVideo = false;
      _cameraState?.setState(CaptureMode.photo);
    }

    final captureFilter = _effectiveCaptureFilter();
    final hasFilter = captureFilter.id != AwesomeFilter.None.id;
    final hasEffect =
        _selectedEffectSlug != null && _selectedEffectSlug != 'none';
    var file = File(path);
    final isVideo = capture.isVideo;

    if (!isVideo && capture.isPicture) {
      file = await CameraCaptureUtils.normalizeCapturedImage(file);
    } else if (isVideo) {
      await CameraFilterCompositor.waitForCaptureFile(file);
      if (!mounted) return;
    }

    if (widget.isStory) {
      if (hasFilter || hasEffect) {
        setState(() => _isProcessingCapture = true);
        try {
          if (hasFilter) {
            file = await CameraFilterCompositor.applyIfNeeded(
              input: file,
              filter: captureFilter,
              isVideo: isVideo,
            );
          }
          if (hasEffect) {
            file = await CameraEffectCompositor.applyIfNeeded(
              input: file,
              effectSlug: _selectedEffectSlug,
              isVideo: isVideo,
            );
          }
        } finally {
          if (mounted) setState(() => _isProcessingCapture = false);
        }
      } else if (_isBusy) {
        setState(() => _isBusy = false);
      }

      if (!mounted) return;

      setState(() {
        _storyCapturedFile = file;
        _storyCapturedType = capture.isPicture ? 'IMAGE' : 'VIDEO';
      });
      return;
    }

    if (_isBusy) {
      setState(() => _isBusy = false);
    }

    if (!mounted) return;

    await _openCapturedMediaEditor(
      file,
      type: capture.isPicture ? 'IMAGE' : 'VIDEO',
    );
  }

  void _retakeStory() {
    setState(() {
      _storyCapturedFile = null;
      _storyCapturedType = null;
    });
  }

  void _handlePendingVideoStart(CameraState state) {
    if (!_pendingVideoStart) return;

    state.when(
      onVideoMode: (videoState) {
        _pendingVideoStart = false;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          _appliedFilterId = null;
          await _reapplySelectedFilter();
          await videoState.startRecording();
          _appliedFilterId = null;
          await _reapplySelectedFilter();
          _startRecordTimer();
        });
      },
      onPhotoMode: (_) {},
      onVideoRecordingMode: (_) {},
      onPreparingCamera: (_) {},
      onPreviewMode: (_) {},
      onAnalysisOnlyMode: (_) {},
    );
  }

  void _startRecordTimer() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recordSeconds += 1);
      if (_recordSeconds >= _selectedDuration) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
      _isBusy = true;
    });

    if (_useNativeArFilters) {
      try {
        final path = await ArCameraBridge.stopRecording();
        if (!mounted) return;
        setState(() {
          _isBusy = false;
          _recordSeconds = 0;
        });
        if (path == null) return;
        await _openCapturedMediaEditor(File(path), type: 'VIDEO');
      } catch (_) {
        if (mounted) {
          setState(() {
            _isBusy = false;
            _recordSeconds = 0;
          });
        }
      }
      return;
    }

    await _cameraState?.when(
      onVideoRecordingMode: (state) => state.stopRecording(),
      onPhotoMode: (_) async {},
      onVideoMode: (_) async {},
      onPreparingCamera: (_) async {},
      onPreviewMode: (_) async {},
      onAnalysisOnlyMode: (_) async {},
    );

    if (mounted) {
      setState(() => _recordSeconds = 0);
    }
  }

  Future<void> _capturePhoto() async {
    if (_isBusy || _isProcessingCapture || _isRecording) return;

    if (_useNativeArFilters) {
      setState(() => _isBusy = true);
      try {
        final path = await ArCameraBridge.takePhoto();
        if (!mounted) return;
        setState(() => _isBusy = false);
        if (path == null) return;
        if (widget.isStory) {
          setState(() {
            _storyCapturedFile = File(path);
            _storyCapturedType = 'IMAGE';
          });
          return;
        }
        await _openCapturedMediaEditor(File(path), type: 'IMAGE');
      } catch (_) {
        if (mounted) setState(() => _isBusy = false);
      }
      return;
    }

    await _cameraState?.when(
      onPhotoMode: (state) => state.takePhoto(),
      onVideoMode: (state) {
        state.setState(CaptureMode.photo);
      },
      onVideoRecordingMode: (_) async {},
      onPreparingCamera: (_) async {},
      onPreviewMode: (_) async {},
      onAnalysisOnlyMode: (_) async {},
    );
  }

  Future<void> _beginVideoRecording() async {
    if (_isBusy || _isRecording) return;

    if (_useNativeArFilters) {
      setState(() => _isBusy = true);
      try {
        // Native AR records mic in parallel — ensure permission every time.
        await CameraStudioPermissions.ensureMicrophone();
        await ArCameraBridge.startRecording();
        if (!mounted) return;
        setState(() => _isBusy = false);
        _startRecordTimer();
      } catch (_) {
        if (mounted) setState(() => _isBusy = false);
      }
      return;
    }

    final state = _cameraState;
    if (state == null) return;

    await state.when(
      onPhotoMode: (photoState) async {
        _returnToPhotoAfterVideo = true;
        _pendingVideoStart = true;
        photoState.setState(CaptureMode.video);
      },
      onVideoMode: (videoState) async {
        _appliedFilterId = null;
        await _reapplySelectedFilter();
        await videoState.startRecording();
        _appliedFilterId = null;
        await _reapplySelectedFilter();
        _startRecordTimer();
      },
      onVideoRecordingMode: (_) async {},
      onPreparingCamera: (_) async {},
      onPreviewMode: (_) async {},
      onAnalysisOnlyMode: (_) async {},
    );
  }

  void _onArFilterSelected(int index) {
    final clamped = index.clamp(0, ArFilterCatalog.items.length - 1);
    final id = ArFilterCatalog.items[clamped].id;
    final intensity =
        ArFilterCatalog.isColorFilter(id) ? _arFilterIntensity : 1.0;
    if (clamped == _arFilterIndex) {
      ArCameraBridge.setFilter(id, intensity: intensity);
      return;
    }
    setState(() => _arFilterIndex = clamped);
    ArCameraBridge.setFilter(id, intensity: intensity);
  }

  void _onArColorCategorySelected(String categoryId) {
    if (categoryId == _arColorCategoryId) return;
    setState(() => _arColorCategoryId = categoryId);
  }

  void _onArFilterIntensityChanged(double value) {
    setState(() => _arFilterIntensity = value.clamp(0.0, 1.0));
    ArCameraBridge.setFilterIntensity(_arFilterIntensity);
  }

  void _onArPreviewSwipeEnd(DragEndDetails details) {
    if (!_useNativeArFilters || _isRecording || _showFilters) return;
    final currentId = ArFilterCatalog.items[_arFilterIndex].id;
    final current = ArFilterCatalog.effectCarouselIndex(currentId);
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -80 || _arSwipeDrag < -36) {
      final next = (current + 1).clamp(0, ArFilterCatalog.effectItems.length - 1);
      _onArFilterSelected(
        ArFilterCatalog.indexOfId(ArFilterCatalog.effectItems[next].id),
      );
    } else if (velocity > 80 || _arSwipeDrag > 36) {
      final prev = (current - 1).clamp(0, ArFilterCatalog.effectItems.length - 1);
      _onArFilterSelected(
        ArFilterCatalog.indexOfId(ArFilterCatalog.effectItems[prev].id),
      );
    }
    _arSwipeDrag = 0;
  }

  void _startRecordingWithOptionalTimer() {
    if (_timerEnabled) {
      setState(() => _countdownValue = 3);
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_countdownValue == null || _countdownValue! <= 1) {
          timer.cancel();
          setState(() => _countdownValue = null);
          _beginVideoRecording();
        } else {
          setState(() => _countdownValue = _countdownValue! - 1);
        }
      });
      return;
    }

    _beginVideoRecording();
  }

  Future<void> _applyFilter(CameraFilterPreset preset) async {
    setState(() => _selectedFilter = preset.filter);
    _appliedFilterId = null;
    await _reapplySelectedFilter();
  }

  void _ensureInitialFilterApplied(CameraState state) {
    _syncFilterOnCameraState(state);
    if (_initialFilterApplied) return;
    _initialFilterApplied = true;
    _appliedFilterId = null;
    unawaited(_reapplySelectedFilter());
  }

  Future<void> _applyBeauty(bool enabled) async {
    setState(() => _beautyEnabled = enabled);
    final state = _cameraState;
    if (state == null) return;

    if (enabled) {
      state.sensorConfig.setBrightness(0.35);
    } else {
      state.sensorConfig.setBrightness(0.0);
    }

    _appliedFilterId = null;
    await _reapplySelectedFilter();
  }

  Future<void> _applyZoom(double zoom) async {
    final state = _cameraState;
    if (state == null) return;
    await state.sensorConfig.setZoom(zoom.clamp(0.0, 1.0));
    if (mounted) setState(() => _selectedZoom = zoom);
  }

  Future<void> _flipCamera() async {
    await _cameraState?.switchCameraSensor();
    if (mounted) {
      setState(() => _isFrontCamera = !_isFrontCamera);
      _faceDetectorService.isFrontCamera = _isFrontCamera;
    }
  }

  void _selectEffect(String? slug) {
    setState(() => _selectedEffectSlug = slug);
    final effect = slug == null ? null : CameraEffectsCatalog.bySlug(slug);
    if (effect?.hasAsset == true) {
      unawaited(CameraEffectAssetLoader.preload(effect!.assetUrl));
    }
  }

  void _toggleFlash() {
    _cameraState?.sensorConfig.switchCameraFlash();
  }

  String _filterLabel(AppLocalizations l10n, CameraFilterPreset preset) {
    return preset.label(l10n: l10n, originalLabel: l10n.cameraFilterOriginal);
  }

  void _onFilterCategorySelected(String slug) {
    setState(() {
      _filterCategorySlug = slug;
      _filterCategory =
          CameraFilterCatalog.categoryFromSlug(slug) ??
          CameraFilterCategory.trending;
    });
  }

  void _onDurationSelected(int seconds) {
    setState(() => _selectedDuration = seconds);
  }

  void _clearFilter() {
    unawaited(_applyFilter(CameraFilterCatalog.original));
  }

  void _showComingSoon(String message) {
    PopupDialogs.showErrorDialog(context, message);
  }

  void _onWorkspaceTabSelected(int index) {
    setState(() => _workspaceTabIndex = index);
    if (index == 1) {
      CameraStudioSheets.showEffectsPicker(
        context,
        l10n: AppLocalizations.of(context)!,
        selectedEffectSlug: _selectedEffectSlug,
        onSelected: (slug) => _selectEffect(slug),
      );
    }
  }

  void _onStudioModeSelected(CameraStudioMode mode) {
    if (_isRecording) return;
    if (widget.isStory && mode == CameraStudioMode.live) return;

    setState(() => _studioMode = mode);

    _cameraState?.when(
      onPhotoMode: (state) {
        if (mode == CameraStudioMode.video) {
          _appliedFilterId = null;
          state.setState(CaptureMode.video);
        }
      },
      onVideoMode: (state) {
        if (mode == CameraStudioMode.photo) {
          state.setState(CaptureMode.photo);
        } else {
          _appliedFilterId = null;
          unawaited(_reapplySelectedFilter());
        }
      },
      onVideoRecordingMode: (_) {},
      onPreparingCamera: (_) {},
      onPreviewMode: (_) {},
      onAnalysisOnlyMode: (_) {},
    );
  }

  void _onRecordTap() {
    if (_studioMode == CameraStudioMode.photo) {
      _capturePhoto();
      return;
    }

    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecordingWithOptionalTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.isStory &&
        _storyCapturedFile != null &&
        _storyCapturedType != null) {
      return StoryCameraEditor(
        file: _storyCapturedFile!,
        type: _storyCapturedType!,
        sound: _selectedSound,
        onRetake: _retakeStory,
      );
    }

    final filters = CameraFilterCatalog.forCategorySlug(_filterCategorySlug);

    if (_catalogLoading && !_useNativeArFilters) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CameraAppLoading(message: l10n.cameraStarting)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_useNativeArFilters)
            _buildNativeArCameraBody(l10n, filters)
          else
            _buildCamerAwesomeBody(l10n, filters),
          if (_isProcessingCapture)
            CameraAppLoading(message: l10n.promoteProcessing),
          if (_isBusy && !_isProcessingCapture)
            CameraAppLoading(message: l10n.cameraStarting),
        ],
      ),
    );
  }

  Widget _buildNativeArCameraBody(
    AppLocalizations l10n,
    List<CameraFilterPreset> filters,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              _arSwipeDrag += details.delta.dx;
            },
            onHorizontalDragEnd: _onArPreviewSwipeEnd,
            child: const ArCameraPreview(),
          ),
        ),
        CameraStudioOverlay(
          l10n: l10n,
          isStoryMode: widget.isStory,
          showGalleryUpload: !widget.returnMediaOnDone,
          useNativeArFilters: true,
          arFilterIndex: _arFilterIndex,
          onArFilterSelected: _onArFilterSelected,
          arColorCategoryId: _arColorCategoryId,
          onArColorCategorySelected: _onArColorCategorySelected,
          arFilterIntensity: _arFilterIntensity,
          onArFilterIntensityChanged: _onArFilterIntensityChanged,
          filters: filters,
          filterCategorySlug: _filterCategorySlug,
          selectedFilter: _selectedFilter,
          selectedDuration: _selectedDuration,
          selectedSpeed: _selectedSpeed,
          studioMode: _studioMode,
          showFilters: _showFilters,
          beautyEnabled: _beautyEnabled ||
              ArFilterCatalog.items[_arFilterIndex].id == 'whitening',
          timerEnabled: _timerEnabled,
          isRecording: _isRecording,
          isBusy: _isBusy || _isProcessingCapture,
          recordSeconds: _recordSeconds,
          countdownValue: _countdownValue,
          selectedEffectSlug: null,
          workspaceTabIndex: _workspaceTabIndex,
          onClose: () => context.pop(),
          onFilterCategorySelected: _onFilterCategorySelected,
          onFilterSelected: _applyFilter,
          onClearFilter: _clearFilter,
          onDurationSelected: _onDurationSelected,
          onStudioModeSelected: (mode) {
            if (_isRecording) return;
            if (widget.isStory && mode == CameraStudioMode.live) return;
            setState(() => _studioMode = mode);
          },
          // OLD effects picker — disabled on native AR (carousel replaces it).
          onEffectsTap: () {},
          onUploadTap: () => CameraStudioSheets.pickFromLibrary(
            context,
            l10n: l10n,
            limit: widget.isStory ? 1 : 5,
            chooseMediaType: true,
            onPicked: _importFromGallery,
          ),
          onGoLiveTap: () =>
              CameraStudioSheets.showLiveSetup(context, l10n: l10n),
          onRecordTap: _onRecordTap,
          onFlip: () {},
          onFlash: () {},
          onSpeedTap: () => CameraStudioSheets.showSpeedPicker(
            context,
            selectedSpeed: _selectedSpeed,
            onSelected: (speed) => setState(() => _selectedSpeed = speed),
          ),
          onBeautyTap: () {
            // Map side beauty toggle to native Pure (whitening) color filter.
            if (ArFilterCatalog.items[_arFilterIndex].id == 'whitening') {
              _onArFilterSelected(0);
            } else {
              _onArFilterSelected(ArFilterCatalog.indexOfId('whitening'));
              setState(() {
                _arColorCategoryId = 'portrait';
                _showFilters = true;
              });
            }
          },
          onFiltersToggle: () {
            final next = !_showFilters;
            setState(() => _showFilters = next);
            if (next) {
              // Warm GL under preview so first filter pick doesn't black-flash.
              unawaited(ArCameraBridge.prepareShaderPipeline());
            }
          },
          onTimerToggle: () => setState(() => _timerEnabled = !_timerEnabled),
          onMusicTap: _pickSound,
          onLayoutTap: () => _showComingSoon(l10n.cameraLiveComingSoon),
          onAspectRatioTap: () => _showComingSoon(l10n.cameraLiveComingSoon),
          onZoomTap: () {},
          onTextModeTap: () => _showComingSoon(l10n.cameraLiveComingSoon),
          onWorkspaceTabSelected: (index) {
            setState(() => _workspaceTabIndex = index);
            // Creative tab old effects sheet commented out on native AR.
          },
          soundLabel: _studioMode == CameraStudioMode.live
              ? l10n.cameraLiveTitleHint
              : (_selectedSound?.name ?? l10n.cameraAddSound),
          onLongPressStart: (_) => _startRecordingWithOptionalTimer(),
          onLongPressEnd: (_) {
            if (_isRecording) _stopRecording();
          },
          filterLabelBuilder: (preset) => _filterLabel(l10n, preset),
        ),
      ],
    );
  }

  Widget _buildCamerAwesomeBody(
    AppLocalizations l10n,
    List<CameraFilterPreset> filters,
  ) {
    return KeyedSubtree(
      key: ValueKey(CameraFilterCatalog.activeCatalog.version),
      child: CameraAwesomeBuilder.custom(
        saveConfig: SaveConfig.photoAndVideo(
          initialCaptureMode: widget.isStory
              ? CaptureMode.photo
              : (_studioMode == CameraStudioMode.video
                    ? CaptureMode.video
                    : CaptureMode.photo),
          mirrorFrontCamera: true,
        ),
        sensorConfig: SensorConfig.single(
          sensor: Sensor.position(SensorPosition.back),
          flashMode: FlashMode.none,
          zoom: _selectedZoom,
          aspectRatio: CameraAspectRatios.ratio_16_9,
        ),
        filter: _effectiveCaptureFilter(),
        filters: CameraFilterCatalog.gpuFiltersForCamera,
        previewFit: CameraPreviewFit.cover,
        onMediaCaptureEvent: _onMediaCapture,
        onImageForAnalysis: _onImageForAnalysis,
        imageAnalysisConfig: AnalysisConfig(
          androidOptions: AndroidAnalysisOptions.nv21(
            width: CameraFaceEffectMapper.liveAnalysisWidth,
          ),
          maxFramesPerSecond: 8,
        ),
        progressIndicator: CameraAppLoading(message: l10n.cameraStarting),
        builder: (state, preview) {
          _cameraState = state;
          _ensureInitialFilterApplied(state);
          _handlePendingVideoStart(state);

          return CameraStudioOverlay(
            l10n: l10n,
            isStoryMode: widget.isStory,
            showGalleryUpload: !widget.returnMediaOnDone,
            cameraState: state,
            preview: preview,
            faceStream: _faceDetectorService.stream,
            filters: filters,
            filterCategorySlug: _filterCategorySlug,
            selectedFilter: _selectedFilter,
            selectedDuration: _selectedDuration,
            selectedSpeed: _selectedSpeed,
            studioMode: _studioMode,
            showFilters: _showFilters && _filtersReady,
            beautyEnabled: _beautyEnabled,
            timerEnabled: _timerEnabled,
            isRecording: _isRecording,
            isBusy: _isBusy || _isProcessingCapture,
            recordSeconds: _recordSeconds,
            countdownValue: _countdownValue,
            selectedEffectSlug: _selectedEffectSlug,
            workspaceTabIndex: _workspaceTabIndex,
            onClose: () => context.pop(),
            onFilterCategorySelected: _onFilterCategorySelected,
            onFilterSelected: _applyFilter,
            onClearFilter: _clearFilter,
            onDurationSelected: _onDurationSelected,
            onStudioModeSelected: _onStudioModeSelected,
            onEffectsTap: () => CameraStudioSheets.showEffectsPicker(
              context,
              l10n: l10n,
              selectedEffectSlug: _selectedEffectSlug,
              onSelected: _selectEffect,
            ),
            onUploadTap: () => CameraStudioSheets.pickFromLibrary(
              context,
              l10n: l10n,
              limit: widget.isStory ? 1 : 5,
              chooseMediaType: true,
              onPicked: _importFromGallery,
            ),
            onGoLiveTap: () =>
                CameraStudioSheets.showLiveSetup(context, l10n: l10n),
            onRecordTap: _onRecordTap,
            onFlip: _flipCamera,
            onFlash: _toggleFlash,
            onSpeedTap: () => CameraStudioSheets.showSpeedPicker(
              context,
              selectedSpeed: _selectedSpeed,
              onSelected: (speed) => setState(() => _selectedSpeed = speed),
            ),
            onBeautyTap: () => _applyBeauty(!_beautyEnabled),
            onFiltersToggle: () => setState(() => _showFilters = !_showFilters),
            onTimerToggle: () =>
                setState(() => _timerEnabled = !_timerEnabled),
            onMusicTap: _pickSound,
            onLayoutTap: () => _showComingSoon(l10n.cameraLiveComingSoon),
            onAspectRatioTap: () =>
                _showComingSoon(l10n.cameraLiveComingSoon),
            onZoomTap: () {
              final steps = CameraStudioConstants.zoomSteps;
              var currentIndex = steps.indexWhere(
                (step) => (_selectedZoom - step.value).abs() < 0.12,
              );
              if (currentIndex < 0) currentIndex = 0;
              final next = steps[(currentIndex + 1) % steps.length];
              unawaited(_applyZoom(next.value));
            },
            onTextModeTap: () => _showComingSoon(l10n.cameraLiveComingSoon),
            onWorkspaceTabSelected: _onWorkspaceTabSelected,
            soundLabel: _studioMode == CameraStudioMode.live
                ? l10n.cameraLiveTitleHint
                : (_selectedSound?.name ?? l10n.cameraAddSound),
            onLongPressStart: (_) => _startRecordingWithOptionalTimer(),
            onLongPressEnd: (_) {
              if (_isRecording) _stopRecording();
            },
            filterLabelBuilder: (preset) => _filterLabel(l10n, preset),
          );
        },
      ),
    );
  }

  Future<void> _onImageForAnalysis(AnalysisImage image) async {
    if (!CameraEffectsCatalog.needsFaceDetection(_selectedEffectSlug)) return;
    await _faceDetectorService.analyze(image);
  }
}
