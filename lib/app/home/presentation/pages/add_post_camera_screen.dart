import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_preview.dart';
import 'package:bimobondapp/app/ar_camera/ar_color_filter_catalog_model.dart';
import 'package:bimobondapp/app/ar_camera/ar_color_filter_remote_loader.dart';
import 'package:bimobondapp/app/ar_camera/ar_overlay_remote_loader.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/camera_studio/presentation/di/camera_studio_injector.dart'
    as camera_studio_di;
import 'package:bimobondapp/app/camera_studio/presentation/services/camera_studio_catalog_loader.dart';
import 'package:bimobondapp/app/home/presentation/utils/camera_capture_utils.dart';
import 'package:bimobondapp/app/home/presentation/utils/camera_layout_composer.dart';
import 'package:bimobondapp/app/home/presentation/utils/camera_layout_video_composer.dart';
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
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_layout_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_overlays.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_sheets.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_photo_editor_panel.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_sheet.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/video_template_slot_filler.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/video_templates_picker_sheet.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/features/live_source/presentation/pages/live_start_page.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AddPostCameraScreen extends StatefulWidget {
  const AddPostCameraScreen({
    super.key,
    this.isStory = false,
    this.initialSound,
    this.initialSoundSegmentId,
    this.returnMediaOnDone = false,
    this.initialFilterName,
    this.initialFilterCategory,
    this.initialArFilterId,
    this.initialArColorCategoryId,
  });

  final bool isStory;
  final SoundEntity? initialSound;

  /// Mode A clip id when reusing another post’s exact segment.
  final String? initialSoundSegmentId;
  final bool returnMediaOnDone;
  final String? initialFilterName;
  final CameraFilterCategory? initialFilterCategory;
  final String? initialArFilterId;
  final String? initialArColorCategoryId;

  @override
  State<AddPostCameraScreen> createState() => _AddPostCameraScreenState();
}

class _AddPostCameraScreenState extends State<AddPostCameraScreen>
    with FeedPlaybackBlocker {
  CameraState? _cameraState;
  // Preserve native preview identity across layout mode changes to avoid a
  // brief native re-init ("blink") when the preview widget moves.
  final GlobalKey _arPreviewKey = GlobalKey(debugLabel: 'ar-camera-preview');
  bool _pendingVideoStart = false;
  bool _returnToPhotoAfterVideo = false;

  /// True while the go-live screen owns the camera. The CamerAwesome branch
  /// unmounts for the duration — the live page runs its own capture session
  /// and iOS will not hand the same device to both at once. The native AR
  /// branch does not need this; it releases through ArCameraBridge instead.
  bool _liveHandoffActive = false;
  bool _showFilters = false;
  bool _showPhotoEditor = false;
  MediaPhotoEditorTab _photoEditorTab = MediaPhotoEditorTab.face;
  MediaPhotoEditorTool _photoEditorTool = MediaPhotoEditorTool.smooth;

  /// Retouch (Magic) On by default when the camera opens.
  bool _photoEditorMagicOn = true;
  bool _preserveNeutralAdjustments = false;

  /// Auto Smooth level when Retouch Off→On (0..1). Slider can go lower/higher.
  static const double _kMagicAutoSmooth = 0.50;

  /// Face color sliders (label = value×100) applied on live camera even when
  /// Retouch/Magic is Off.
  /// Live color defaults (empty-frame / Retouch-Off baseline).
  static const Map<MediaPhotoEditorTool, double> _kLiveColorDefaults = {
    MediaPhotoEditorTool.contrast: 1.0, // max (+100)
    MediaPhotoEditorTool.saturation: 0.10, // +10
    MediaPhotoEditorTool.brightness: -0.47, // -47
    MediaPhotoEditorTool.exposure: 0.06, // +6
    MediaPhotoEditorTool.whiteBalance: -0.08, // warmth -8
    MediaPhotoEditorTool.highlights: 0.08, // +8
    MediaPhotoEditorTool.shadows: 0.10, // +10
  };

  /// Front-camera live color defaults — must match the front-camera target
  /// values in FaceWarpRenderer.bindRetouchUniforms (the "frontTarget"
  /// argument of each fieldMix call). Kept in sync manually: previously this
  /// screen sent [_kLiveColorDefaults] (the back-camera baseline) or zeros for
  /// front, so the slider thumbs showed a value (e.g. contrast +100) that
  /// didn't match what the native override actually rendered, and flipping to
  /// front camera reset the look instead of reapplying it. Sending the real
  /// front values here means the slider position and the rendered look agree,
  /// on cold open and after every camera flip.
  static const Map<MediaPhotoEditorTool, double> _kFrontLiveColorDefaults = {
    MediaPhotoEditorTool.contrast: 0.0, // 0
    MediaPhotoEditorTool.saturation: -0.10, // -10
    MediaPhotoEditorTool.brightness: 1.0, // +100
    MediaPhotoEditorTool.exposure: 0.30, // +30
    MediaPhotoEditorTool.whiteBalance: -0.50, // warmth -50
    MediaPhotoEditorTool.highlights: -0.10, // -10
    MediaPhotoEditorTool.shadows: 0.25, // +25
  };
  // Beauty/morph fields only — deliberately no colour-grade keys (contrast,
  // saturation, brightness, exposure, whiteBalance, highlights, shadows).
  // They used to be here, hardcoded to the back-camera baseline, and every
  // Magic-on toggle overwrote whatever colour values were actually correct
  // for the current camera (e.g. front's brightness) with those stale
  // numbers — reported as "slider shows -47 even though we set 100".
  // _restoreLiveColorDefaults() already owns colour grade per-camera;
  // touching it here duplicated that and went out of sync.
  static const Map<MediaPhotoEditorTool, double> _kMagicBeautyDefaults = {
    MediaPhotoEditorTool.smooth: _kMagicAutoSmooth,
    MediaPhotoEditorTool.shape: 0.08,
    MediaPhotoEditorTool.nose: 0.05,
    MediaPhotoEditorTool.eyes: 0.05,
    MediaPhotoEditorTool.tooth: 0.12,
    MediaPhotoEditorTool.mouth: 0.05,
  };
  final Map<MediaPhotoEditorTool, double> _photoAdjustments = {
    MediaPhotoEditorTool.smooth: _kMagicAutoSmooth,
    MediaPhotoEditorTool.contrast: 1.0,
    MediaPhotoEditorTool.shape: 0.08,
    MediaPhotoEditorTool.nose: 0.05,
    MediaPhotoEditorTool.eyes: 0.05,
    MediaPhotoEditorTool.tooth: 0.12,
    MediaPhotoEditorTool.mouth: 0.05,
    MediaPhotoEditorTool.saturation: 0.10,
    MediaPhotoEditorTool.brightness: -0.47,
    MediaPhotoEditorTool.exposure: 0.06,
    MediaPhotoEditorTool.whiteBalance: -0.08,
    MediaPhotoEditorTool.highlights: 0.08,
    MediaPhotoEditorTool.shadows: 0.10,
  };
  bool _catalogLoading = true;
  bool _filtersReady = false;
  bool _beautyEnabled = false;
  bool _timerEnabled = false;
  int _countdownDelaySeconds = 3;
  bool _flashEnabled = false;
  bool _ratioLetterboxed = false;
  bool _layoutPickerOpen = false;
  bool _speedPickerOpen = false;
  CameraLayoutMode _layoutMode = CameraLayoutMode.off;
  List<String?> _layoutCellPhotos = const [];
  int _layoutActiveCell = 0;

  /// TikTok layout: max seconds for the next cell = min of prior cell lengths.
  int? _layoutCellCapSeconds;
  bool _isRecording = false;
  bool _isBusy = false;
  bool _isProcessingCapture = false;
  bool _isCapturingPhoto = false;
  bool _showShutterFlash = false;
  bool _recordingFinalizeInFlight = false;

  /// True while a photo-mode press-and-hold is recording a quick video.
  bool _quickVideoMode = false;
  static const _quickVideoMaxSeconds = 15;

  /// Finger is down on a hold-to-record gesture (survives shutter rebuilds).
  bool _holdRecordActive = false;

  /// Hold ended before native start finished — stop as soon as recording arms.
  bool _stopWhenRecordReady = false;

  int _recordSeconds = 0;
  final List<String> _videoSegments = [];
  // Playback speed for each recorded segment, parallel to [_videoSegments], so
  // every portion keeps the speed selected while it was recorded (TikTok-style).
  final List<double> _segmentSpeeds = [];
  // Speed captured when the current segment started recording.
  double _currentSegmentSpeed = 1.0;
  // CamerAwesome delivers finished clips asynchronously via onMediaCapture, so
  // the recorded speed is queued (FIFO) at stop time and matched on arrival.
  final List<double> _pendingSegmentSpeeds = [];
  Timer? _recordTimer;
  Timer? _countdownTimer;
  int? _countdownValue;
  CameraFilterCategory _filterCategory = CameraFilterCategory.trending;
  String _filterCategorySlug = 'trending';
  AwesomeFilter _selectedFilter = AwesomeFilter.None;
  bool _initialFilterApplied = false;
  double _selectedZoom = CameraStudioConstants.zoomSteps.first.value;
  int _selectedDuration = CameraStudioConstants.durationOptions.first;
  double _selectedSpeed = 1.0;
  String? _selectedEffectSlug;
  CameraStudioMode _studioMode = CameraStudioMode.video;
  SoundEntity? _selectedSound;
  Duration _soundStartOffset = Duration.zero;
  Duration _soundWindow = const Duration(seconds: 15);
  bool _soundDidTrim = false;
  String? _pickedSoundSegmentId;
  bool _muteOriginalAudio = false;
  String? _videoTemplateId;
  String? _videoTemplateName;
  int? _videoTemplateSlotCount;
  String? _templateProjectId;
  File? _storyCapturedFile;
  String? _storyCapturedType;
  late final CameraFaceDetectorService _faceDetectorService;
  Type? _lastCameraStateType;
  String? _appliedFilterId;
  bool _isFrontCamera = false;
  int _workspaceTabIndex = 0;
  int _arFilterIndex = 0;
  String _arColorCategoryId = 'beauty';
  double _arFilterIntensity = 1.0;
  double _arSwipeDrag = 0;
  double _pinchBaseZoom = CameraStudioConstants.zoomSteps.first.value;
  bool _isPinchingZoom = false;
  static const double _pinchZoomSensitivity = 0.9;

  /// Android uses native MediaPipe/GPU AR stack from `ar_camera`.
  /// iOS keeps CamerAwesome until native port.
  bool get _useNativeArFilters =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _selectedSound = widget.initialSound;
    _pickedSoundSegmentId =
        widget.initialSoundSegmentId?.trim().isNotEmpty == true
        ? widget.initialSoundSegmentId!.trim()
        : null;
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
    _faceDetectorService = CameraFaceDetectorService(
      isFrontCamera: _isFrontCamera,
    );
    if (_useNativeArFilters) {
      _isFrontCamera = true;
      // Cold open starts on front camera — match what a flip-to-front does,
      // so the slider thumbs and the rendered look agree from the first
      // frame instead of only after the user flips away and back.
      _restoreLiveColorDefaults();
      ArCameraBridge.installPlatformCallbacks();
      ArCameraBridge.onRecordingAutoStopped = _onNativeRecordingAutoStopped;
      ArCameraBridge.warmup();
      _applyArFilter(ArFilterCatalog.items[_arFilterIndex].id);
      // Retouch/Magic On by default on camera open.
      ArCameraBridge.setMagicEnabled(true, strength: _kMagicAutoSmooth);
      _syncRetouchToNative();
    }
    unawaited(CameraStudioPermissions.ensureCameraAndMicrophone());
    unawaited(_loadCatalog());
  }

  Future<void> _loadCatalog() async {
    await Future.wait([
      camera_studio_di.sl<CameraStudioCatalogLoader>().ensureLoaded(
        forceRefresh: true,
      ),
      if (_useNativeArFilters)
        ArColorFilterRemoteLoader.ensureLoaded(forceRefresh: true),
      if (_useNativeArFilters)
        ArOverlayRemoteLoader.ensureLoaded(forceRefresh: true),
    ]);
    if (_useNativeArFilters) {
      // Downloads every published overlay animation into Lottie's disk cache
      // now, while the user is still looking at Normal Mode, so the first tap
      // on one plays immediately instead of waiting on the network.
      unawaited(ArCameraBridge.prefetchOverlays());
    }
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
      if (_useNativeArFilters) {
        final arCategories = ArFilterCatalog.colorCategories;
        if (arCategories.isNotEmpty &&
            !arCategories.any((c) => c.id == _arColorCategoryId)) {
          // Default to whichever category the catalog lists first (matches
          // the backend's own category order), not a hardcoded id — the old
          // static catalog only ever had one category ('beauty'), which
          // doesn't exist anymore now that categories are dynamic.
          _arColorCategoryId = arCategories.first.id;
        }
      }
      _applyInitialArFilterIfNeeded();
    });
  }

  void _applyInitialArFilterIfNeeded() {
    final id = widget.initialArFilterId?.trim();
    if (id == null || id.isEmpty || id == 'none') return;
    if (!_useNativeArFilters) return;
    if (!ArFilterCatalog.items.any((item) => item.id == id)) return;

    setState(() {
      _arFilterIndex = ArFilterCatalog.indexOfId(id);
      final categoryId = widget.initialArColorCategoryId?.trim();
      if (categoryId != null && categoryId.isNotEmpty) {
        _arColorCategoryId = categoryId;
      } else if (ArFilterCatalog.isColorFilter(id)) {
        for (final category in ArFilterCatalog.colorCategories) {
          if (category.filterIds.contains(id)) {
            _arColorCategoryId = category.id;
            break;
          }
        }
      }
      if (ArFilterCatalog.isColorFilter(id)) {
        _arFilterIntensity = 0.50;
      }
      _showFilters = true;
    });
    _applyArFilter(
      id,
      intensity: ArFilterCatalog.isColorFilter(id) ? _arFilterIntensity : 1.0,
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _countdownTimer?.cancel();
    _arFilterIntensityDebounce?.cancel();
    _smoothAdjustDebounce?.cancel();
    _retouchAdjustDebounce?.cancel();
    unawaited(SoundAudioPreview.stop());
    _clearLayoutCapture();
    if (_useNativeArFilters) {
      ArCameraBridge.clearPlatformCallbacks();
      ArCameraBridge.clearRetouchAdjustments();
      unawaited(ArCameraBridge.setPreviewLetterbox(topPx: 0, bottomPx: 0));
    }
    for (final path in _videoSegments) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    _videoSegments.clear();
    _segmentSpeeds.clear();
    _pendingSegmentSpeeds.clear();
    unawaited(_faceDetectorService.dispose());
    super.dispose();
  }

  Future<void> _importFromGallery(List<GalleryMediaItem> items) async {
    if (items.isEmpty || !mounted) return;
    unawaited(SoundAudioPreview.stop());
    setState(() => _isBusy = true);
    // Same reason as _openCapturedMediaEditor: the editor route is pushed over a
    // still-running native camera view.
    unawaited(ArCameraBridge.suspendPreview());
    try {
      final editorItems = items;
      if (!mounted) return;
      if (widget.returnMediaOnDone) {
        final edited = await MediaGalleryImportFlow.openBatchEditor(
          context,
          items: editorItems,
          isStory: widget.isStory,
          initialSound: _selectedSound,
          initialSoundOffset: _soundStartOffset,
          initialMuteOriginal: _muteOriginalAudio,
          videoTemplateId: _videoTemplateId,
          videoTemplateName: _videoTemplateName,
          videoTemplateSlotCount: _videoTemplateSlotCount,
          templateProjectId: _templateProjectId,
        );
        if (edited != null && mounted) {
          _returnPickedMedia(edited);
        }
        return;
      }
      final edited = await MediaGalleryImportFlow.openBatchEditor(
        context,
        items: editorItems,
        isStory: widget.isStory,
        initialSound: _selectedSound,
        initialSoundOffset: _soundStartOffset,
        initialMuteOriginal: _muteOriginalAudio,
        videoTemplateId: _videoTemplateId,
        videoTemplateName: _videoTemplateName,
        videoTemplateSlotCount: _videoTemplateSlotCount,
        templateProjectId: _templateProjectId,
      );
      if (!mounted || edited == null || edited.files.isEmpty) return;
      final postFiles = MediaGalleryImportFlow.composerFiles(edited);
      context.pushReplacementNamed(
        'add_post',
        extra: {
          'files': postFiles,
          'type': MediaGalleryImportFlow.composerType(edited),
          'isStory': false,
          'initialSound': edited.sound ?? _selectedSound,
          'initialSoundOffset': edited.soundOffset,
          'initialSoundWindow': edited.soundWindow,
          'initialSoundDidTrim': edited.soundDidTrim || _soundDidTrim,
          'initialSoundSegmentId':
              edited.soundSegmentId ?? _pickedSoundSegmentId,
          if (edited.filterName != null) 'filterName': edited.filterName,
          'filterCategory': edited.filterCategory.name,
          if (edited.effectSlug != null) 'effectSlug': edited.effectSlug,
          'beautyEnabled': edited.beautyEnabled,
          if ((edited.videoTemplateId ?? _videoTemplateId) != null)
            'videoTemplateId': edited.videoTemplateId ?? _videoTemplateId,
          if ((edited.videoTemplateName ?? _videoTemplateName) != null)
            'videoTemplateName': edited.videoTemplateName ?? _videoTemplateName,
          if ((edited.videoTemplateSlotCount ?? _videoTemplateSlotCount) !=
              null)
            'videoTemplateSlotCount':
                edited.videoTemplateSlotCount ?? _videoTemplateSlotCount,
          if ((edited.templateProjectId ?? _templateProjectId) != null)
            'templateProjectId': edited.templateProjectId ?? _templateProjectId,
          if (edited.templateRenderedVideo != null)
            'templateRenderedVideo': edited.templateRenderedVideo,
          if (edited.templateSlotFiles != null &&
              edited.templateSlotFiles!.isNotEmpty)
            'templateSlotFiles': edited.templateSlotFiles,
          if (edited.templateServerExportUrl != null)
            'templateServerExportUrl': edited.templateServerExportUrl,
          if (edited.templateClientExportQuality != null)
            'templateClientExportQuality': edited.templateClientExportQuality,
        },
      );
    } finally {
      unawaited(ArCameraBridge.resumePreview());
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _returnPickedMedia(MediaStudioExportResult result) {
    if (result.files.isEmpty) return;
    final postFiles = MediaGalleryImportFlow.composerFiles(result);
    context.pop(
      CameraMediaPickResult(
        files: postFiles,
        type: MediaGalleryImportFlow.composerType(result),
        filterName: result.filterName ?? _activeFilterName,
        sound: result.sound ?? _selectedSound,
        soundOffset: result.soundOffset,
        soundWindow: result.soundWindow,
        soundDidTrim: result.soundDidTrim || _soundDidTrim,
        soundSegmentId: result.soundSegmentId ?? _pickedSoundSegmentId,
        videoTemplateId: result.videoTemplateId ?? _videoTemplateId,
      ),
    );
  }

  String? get _activeFilterName {
    final filter = _effectiveCaptureFilter();
    if (!CameraFilterCompositor.isActiveFilter(filter)) return null;
    return filter.name;
  }

  MediaEditorSeed get _captureEditSeed {
    if (_useNativeArFilters) {
      final arId = ArFilterCatalog.items[_arFilterIndex].id;
      final category = ArFilterCatalog.isColorFilter(arId)
          ? _arColorCategoryId
          : 'beauty';
      return MediaEditorSeed(
        arFilterId: arId,
        arColorCategoryId: category,
        arFilterIntensity: _arFilterIntensity,
        beautyEnabled: _photoEditorMagicOn,
        alreadyBaked: true,
        effectSlug: ArFilterCatalog.isColorFilter(arId) || arId == 'none'
            ? null
            : arId,
        faceSaturation: _photoAdj(MediaPhotoEditorTool.saturation),
        faceBrightness: _photoAdj(MediaPhotoEditorTool.brightness),
        faceContrast: _photoAdj(MediaPhotoEditorTool.contrast),
        faceExposure: _photoAdj(MediaPhotoEditorTool.exposure),
        faceWhiteBalance: _photoAdj(MediaPhotoEditorTool.whiteBalance),
        faceHighlights: _photoAdj(MediaPhotoEditorTool.highlights),
        faceShadows: _photoAdj(MediaPhotoEditorTool.shadows),
        faceNose: _photoAdj(MediaPhotoEditorTool.nose),
      );
    }
    return MediaEditorSeed(
      filterName: _activeFilterName,
      effectSlug: _selectedEffectSlug,
      beautyEnabled: _beautyEnabled || _photoEditorMagicOn,
      filterCategory: _filterCategory,
      faceSaturation: _photoAdj(MediaPhotoEditorTool.saturation),
      faceBrightness: _photoAdj(MediaPhotoEditorTool.brightness),
      faceContrast: _photoAdj(MediaPhotoEditorTool.contrast),
      faceExposure: _photoAdj(MediaPhotoEditorTool.exposure),
      faceWhiteBalance: _photoAdj(MediaPhotoEditorTool.whiteBalance),
      faceHighlights: _photoAdj(MediaPhotoEditorTool.highlights),
      faceShadows: _photoAdj(MediaPhotoEditorTool.shadows),
      faceNose: _photoAdj(MediaPhotoEditorTool.nose),
    );
  }

  double _photoAdj(MediaPhotoEditorTool tool) =>
      _photoEditorMagicOn ? (_photoAdjustments[tool] ?? 0.0) : 0.0;

  double _liveColorAdj(MediaPhotoEditorTool tool) {
    // Retouch Off → fully neutral on both cameras, same as front used to be.
    if (!_photoEditorMagicOn) return 0.0;
    return _photoAdjustments[tool] ?? 0.0;
  }

  void _restoreLiveColorDefaults() {
    if (_preserveNeutralAdjustments) return;
    _photoAdjustments.addAll(
      _isFrontCamera ? _kFrontLiveColorDefaults : _kLiveColorDefaults,
    );
  }

  void _syncRetouchToNative() {
    if (!_useNativeArFilters) return;
    ArCameraBridge.setRetouchAdjustments(
      saturation: _liveColorAdj(MediaPhotoEditorTool.saturation),
      brightness: _liveColorAdj(MediaPhotoEditorTool.brightness),
      contrast: _liveColorAdj(MediaPhotoEditorTool.contrast),
      exposure: _liveColorAdj(MediaPhotoEditorTool.exposure),
      whiteBalance: _liveColorAdj(MediaPhotoEditorTool.whiteBalance),
      highlights: _liveColorAdj(MediaPhotoEditorTool.highlights),
      shadows: _liveColorAdj(MediaPhotoEditorTool.shadows),
      nose: _photoAdj(MediaPhotoEditorTool.nose),
      shape: _photoAdj(MediaPhotoEditorTool.shape),
      eyes: _photoAdj(MediaPhotoEditorTool.eyes),
      tooth: _photoAdj(MediaPhotoEditorTool.tooth),
      mouth: _photoAdj(MediaPhotoEditorTool.mouth),
    );
  }

  void _togglePhotoEditor() {
    setState(() {
      if (_showPhotoEditor) {
        _showPhotoEditor = false;
        return;
      }
      _showPhotoEditor = true;
      _showFilters = false;
      _layoutPickerOpen = false;
      _speedPickerOpen = false;
      // Magic stays Off until the user taps it (TikTok behavior).
    });
    if (_useNativeArFilters) {
      _syncRetouchToNative();
    }
    // Deliberately NOT re-syncing the native letterbox margins here — same
    // reason as onFiltersToggle above: it's cosmetic-only (handled by the
    // live preview's ClipPath) and re-applying it natively resizes the
    // SurfaceView, causing a brief camera freeze on every open/close.
  }

  void _onPhotoEditorMagicToggled() {
    final next = !_photoEditorMagicOn;
    _photoEditorMagicOn = next;
    if (next) {
      if (!_preserveNeutralAdjustments) {
        _photoAdjustments.addAll(_kMagicBeautyDefaults);
      }
      _photoEditorTool = MediaPhotoEditorTool.smooth;
    } else {
      _photoEditorTool = MediaPhotoEditorTool.magic;
      // Retouch Off → restore live color baseline (keep morphs cleared via sync).
      _restoreLiveColorDefaults();
    }
    setState(() {});
    if (_useNativeArFilters) {
      if (next) {
        ArCameraBridge.setMagicEnabled(
          true,
          strength:
              _photoAdjustments[MediaPhotoEditorTool.smooth] ??
              _kMagicAutoSmooth,
        );
        _syncRetouchToNative();
      } else {
        ArCameraBridge.setMagicEnabled(false);
        _syncRetouchToNative();
      }
    } else {
      unawaited(_applyBeauty(next));
    }
  }

  Timer? _smoothAdjustDebounce;
  Timer? _retouchAdjustDebounce;

  void _onPhotoEditorAdjustmentChanged(
    MediaPhotoEditorTool tool,
    double value,
  ) {
    if (tool == MediaPhotoEditorTool.smooth) {
      final strength = value.clamp(0.0, 1.0);
      setState(() {
        _photoAdjustments[tool] = strength;
        // Dragging Smooth turns Retouch On if it was Off.
        if (!_photoEditorMagicOn && strength > 0.01) {
          _photoEditorMagicOn = true;
        }
      });
      if (_useNativeArFilters) {
        // Slider fires on every pixel of drag movement — keep the visible
        // thumb instant (setState above), but debounce the native push.
        // Same fix already applied to the filter-intensity slider (see
        // _onArFilterIntensityChanged) for the identical "spamming native
        // calls on every tick during drag" freeze — this one was missed.
        _smoothAdjustDebounce?.cancel();
        _smoothAdjustDebounce = Timer(const Duration(milliseconds: 40), () {
          if (_photoEditorMagicOn) {
            ArCameraBridge.setMagicEnabled(true, strength: strength);
          } else {
            ArCameraBridge.setMagicEnabled(false);
          }
        });
      }
      return;
    }
    setState(() => _photoAdjustments[tool] = value);
    if (_useNativeArFilters) {
      // Same "fires on every drag pixel" issue as Smooth above — debounce
      // the native push, keep the visible slider instant via setState.
      _retouchAdjustDebounce?.cancel();
      _retouchAdjustDebounce = Timer(
        const Duration(milliseconds: 40),
        _syncRetouchToNative,
      );
    }
  }

  void _resetPhotoEditor() {
    _smoothAdjustDebounce?.cancel();
    _retouchAdjustDebounce?.cancel();
    _arFilterIntensityDebounce?.cancel();
    setState(() {
      for (final key in _photoAdjustments.keys) {
        _photoAdjustments[key] = 0.0;
      }
      _arFilterIntensity = 0.0;
      _preserveNeutralAdjustments = true;
      _photoEditorTool = MediaPhotoEditorTool.magic;
      _photoEditorMagicOn = false;
      if (_useNativeArFilters) {
        final currentId = ArFilterCatalog.items[_arFilterIndex].id;
        if (currentId == 'whitening' ||
            ArFilterCatalog.isColorFilter(currentId)) {
          _arFilterIndex = 0;
        }
      }
    });
    if (_useNativeArFilters) {
      ArCameraBridge.setMagicEnabled(false);
      _applyArFilter('none', intensity: 0.0);
      // clearRetouchAdjustments restores a camera baseline; Reset requires
      // every adjustable renderer value to be exactly neutral instead.
      ArCameraBridge.setRetouchAdjustments();
      ArCameraBridge.setBeautyFilter(
        smooth: 0,
        whiten: 0,
        brighten: 0,
        blush: 0,
        lipTint: '#000000',
        lipStrength: 0,
        intensity: 0,
      );
    } else {
      unawaited(_applyBeauty(false));
    }
  }

  void _onMakeupFilmFilterSelected(String id) {
    if (!_useNativeArFilters) return;
    setState(() {
      if (id == 'none') {
        final current = ArFilterCatalog.items[_arFilterIndex].id;
        if (ArFilterCatalog.isColorFilter(current)) {
          _arFilterIndex = 0;
        }
      } else {
        _arFilterIndex = ArFilterCatalog.indexOfId(id);
        _arColorCategoryId = 'beauty';
        _arFilterIntensity = 0.50;
        _photoEditorMagicOn = false;
        _photoAdjustments[MediaPhotoEditorTool.smooth] = 0.0;
      }
    });
    if (!_photoEditorMagicOn) {
      ArCameraBridge.setMagicEnabled(false);
    }
    final applied = ArFilterCatalog.items[_arFilterIndex].id;
    final intensity = ArFilterCatalog.isColorFilter(applied)
        ? _arFilterIntensity
        : 1.0;
    _applyArFilter(applied, intensity: intensity);
  }

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
    // Leave camera → editor: never carry a catalog preview into the next step.
    unawaited(SoundAudioPreview.stop());
    // The editor is pushed on top of this screen, which leaves the native camera
    // view mounted and running (a route push doesn't pause the Activity). Stop it
    // for the duration so the editor's video playback isn't competing with a live
    // camera stream plus, for screen-overlay filters, a full-screen Lottie loop.
    // Fire-and-forget on purpose: awaiting a channel round-trip here would delay
    // the push itself, and the native side's work is already non-blocking.
    unawaited(ArCameraBridge.suspendPreview());
    final MediaStudioExportResult? edited;
    try {
      final items = [GalleryMediaItem(file: file, type: type)];
      if (!mounted) return;
      edited = await MediaGalleryImportFlow.openBatchEditor(
        context,
        items: items,
        isStory: widget.isStory,
        initialSound: _selectedSound,
        initialSoundOffset: _soundStartOffset,
        initialMuteOriginal: _muteOriginalAudio,
        initialEdit: _captureEditSeed,
        videoTemplateId: _videoTemplateId,
        videoTemplateName: _videoTemplateName,
        videoTemplateSlotCount: _videoTemplateSlotCount,
        templateProjectId: _templateProjectId,
      );
    } finally {
      // Back on the camera (or about to leave it entirely) — either way the
      // native side must not be left suspended.
      unawaited(ArCameraBridge.resumePreview());
    }
    if (!mounted || edited == null || edited.files.isEmpty) return;

    if (widget.returnMediaOnDone) {
      _returnPickedMedia(edited);
      return;
    }

    final postFiles = MediaGalleryImportFlow.composerFiles(edited);
    context.pushReplacementNamed(
      'add_post',
      extra: {
        'files': postFiles,
        'type': MediaGalleryImportFlow.composerType(edited),
        'isStory': false,
        'initialSound': edited.sound ?? _selectedSound,
        'initialSoundOffset': edited.soundOffset,
        'initialSoundWindow': edited.soundWindow,
        'initialSoundDidTrim': edited.soundDidTrim || _soundDidTrim,
        'initialSoundSegmentId': edited.soundSegmentId ?? _pickedSoundSegmentId,
        if (edited.filterName != null) 'filterName': edited.filterName,
        'filterCategory': edited.filterCategory.name,
        if (edited.effectSlug != null) 'effectSlug': edited.effectSlug,
        'beautyEnabled': edited.beautyEnabled,
        if ((edited.videoTemplateId ?? _videoTemplateId) != null)
          'videoTemplateId': edited.videoTemplateId ?? _videoTemplateId,
        if ((edited.videoTemplateName ?? _videoTemplateName) != null)
          'videoTemplateName': edited.videoTemplateName ?? _videoTemplateName,
        if ((edited.videoTemplateSlotCount ?? _videoTemplateSlotCount) != null)
          'videoTemplateSlotCount':
              edited.videoTemplateSlotCount ?? _videoTemplateSlotCount,
        if ((edited.templateProjectId ?? _templateProjectId) != null)
          'templateProjectId': edited.templateProjectId ?? _templateProjectId,
        if (edited.templateRenderedVideo != null)
          'templateRenderedVideo': edited.templateRenderedVideo,
        if (edited.templateSlotFiles != null &&
            edited.templateSlotFiles!.isNotEmpty)
          'templateSlotFiles': edited.templateSlotFiles,
        if (edited.templateServerExportUrl != null)
          'templateServerExportUrl': edited.templateServerExportUrl,
        if (edited.templateClientExportQuality != null)
          'templateClientExportQuality': edited.templateClientExportQuality,
      },
    );
  }

  Future<void> _pickSound() async {
    final picked = await SoundPickerSheet.show(
      context,
      initialSelection: _selectedSound,
      initialOffset: _soundStartOffset,
      initialWindow: _soundWindow,
    );
    if (!mounted || picked == null) return;
    if (picked.cleared) {
      _clearSound();
      return;
    }
    final sound = picked.sound;
    if (sound == null) return;
    setState(() {
      _selectedSound = sound;
      _soundStartOffset = picked.offset;
      _soundWindow = picked.window > Duration.zero
          ? picked.window
          : const Duration(seconds: 15);
      _muteOriginalAudio = true;
      _soundDidTrim = picked.didTrim || picked.offset > Duration.zero;
      final seg = picked.soundSegmentId?.trim();
      final defaultId = sound.defaultSegment?.id.trim();
      _pickedSoundSegmentId =
          (seg != null && seg.isNotEmpty && seg != defaultId) ? seg : null;
    });
    // Preview only inside the picker/trim sheets — stop once the user continues.
    await SoundAudioPreview.stop();
  }

  void _clearSound() {
    unawaited(SoundAudioPreview.stop());
    setState(() {
      _selectedSound = null;
      _soundStartOffset = Duration.zero;
      _soundWindow = const Duration(seconds: 15);
      _muteOriginalAudio = false;
      _soundDidTrim = false;
      _pickedSoundSegmentId = null;
    });
  }

  AwesomeFilter _effectiveCaptureFilter() {
    if (_selectedFilter.id != AwesomeFilter.None.id) return _selectedFilter;
    if (_beautyEnabled) return CameraFilterCatalog.beautyFilter.filter;
    return AwesomeFilter.None;
  }

  Future<void> _onMediaCapture(MediaCapture capture) async {
    if (!mounted) return;

    // Capture begins — kill any leftover catalog preview so it can't keep
    // looping under the processing / editor flow.
    unawaited(SoundAudioPreview.stop());

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
      file = await _applyRatioCropIfNeeded(file);
    } else if (isVideo) {
      await CameraFilterCompositor.waitForCaptureFile(file);
      if (!mounted) return;
    }

    if (!isVideo && capture.isPicture && _layoutMode != CameraLayoutMode.off) {
      await _handleLayoutPhoto(file);
      return;
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

    // Layout grid: each clip fills one cell, then compose when full.
    if (isVideo && _layoutMode != CameraLayoutMode.off) {
      setState(() {
        _isBusy = false;
        _isRecording = false;
      });
      await _handleLayoutVideo(file);
      return;
    }

    // Multi-clip video: each hold/release is a segment — Next merges & edits.
    if (isVideo) {
      final speed = _pendingSegmentSpeeds.isNotEmpty
          ? _pendingSegmentSpeeds.removeAt(0)
          : _currentSegmentSpeed;
      setState(() {
        _videoSegments.add(file.path);
        _segmentSpeeds.add(speed);
        _isBusy = false;
        _isRecording = false;
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
          _startRecordTimer(resume: _shouldResumeRecordTimer);
        });
      },
      onPhotoMode: (_) {},
      onVideoRecordingMode: (_) {},
      onPreparingCamera: (_) {},
      onPreviewMode: (_) {},
      onAnalysisOnlyMode: (_) {},
    );
  }

  /// Multi-clip draft resumes the shared timer; layout cells always start at 0.
  bool get _shouldResumeRecordTimer =>
      _layoutMode == CameraLayoutMode.off && _videoSegments.isNotEmpty;

  /// Max recording length: 15s for a photo-mode quick video, otherwise the
  /// duration selected in the video mode bar. In layout mode, prior cells
  /// further cap the take (shortest previous cell length).
  int get _effectiveMaxRecordSeconds {
    final base = _quickVideoMode ? _quickVideoMaxSeconds : _selectedDuration;
    final layoutCap = _layoutCellCapSeconds;
    if (_layoutMode != CameraLayoutMode.off && layoutCap != null) {
      return layoutCap.clamp(1, base);
    }
    return base;
  }

  /// Stops a photo-mode quick video and opens the editor with the clip.
  Future<void> _finishQuickVideo() async {
    if (!_quickVideoMode) return;
    _quickVideoMode = false;
    _recordTimer?.cancel();

    // Released before the (CamerAwesome) recording actually started: cancel the
    // pending start and return to photo mode instead of finishing empty.
    if (!_isRecording && _pendingVideoStart) {
      _pendingVideoStart = false;
      if (_returnToPhotoAfterVideo) {
        _returnToPhotoAfterVideo = false;
        _cameraState?.setState(CaptureMode.photo);
      }
      if (mounted) setState(() => _isBusy = false);
      return;
    }

    await _finishMultiClipVideo();
  }

  void _startRecordTimer({bool resume = false}) {
    unawaited(SoundAudioPreview.stop());
    _recordTimer?.cancel();
    // Capture the speed for this segment so per-portion speed is preserved even
    // if the user changes speed again later.
    _currentSegmentSpeed = _selectedSpeed;
    setState(() {
      _isRecording = true;
      if (!resume) _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isRecording) return;
      setState(() => _recordSeconds += 1);
      if (_recordSeconds >= _effectiveMaxRecordSeconds) {
        if (_quickVideoMode) {
          // Photo-mode quick video: cap reached → finish and open the editor.
          unawaited(_finishQuickVideo());
        } else {
          unawaited(_pauseRecordingSegment(autoFinish: true));
        }
      }
    });
  }

  Future<void> _pauseRecordingSegment({bool autoFinish = false}) async {
    _recordTimer?.cancel();
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
      _isBusy = true;
    });

    if (_useNativeArFilters) {
      try {
        final path = await ArCameraBridge.stopRecording();
        if (!mounted) {
          setState(() => _isBusy = false);
          return;
        }
        await _completeRecordingSegment(path ?? '', autoFinish: autoFinish);
      } catch (_) {
        if (mounted) {
          setState(() => _isBusy = false);
        }
      }
      return;
    }

    // CamerAwesome: stop write; file arrives via onMediaCapture as a segment.
    // Queue this segment's speed so it's matched when the clip arrives.
    _pendingSegmentSpeeds.add(_currentSegmentSpeed);
    await _cameraState?.when(
      onVideoRecordingMode: (state) => state.stopRecording(),
      onPhotoMode: (_) async {},
      onVideoMode: (_) async {},
      onPreparingCamera: (_) async {},
      onPreviewMode: (_) async {},
      onAnalysisOnlyMode: (_) async {},
    );
    if (mounted) setState(() => _isBusy = false);
  }

  void _onNativeRecordingAutoStopped(String path) {
    if (!mounted || path.isEmpty) return;
    unawaited(
      _completeRecordingSegment(
        path,
        autoFinish: _layoutMode == CameraLayoutMode.off,
      ),
    );
  }

  /// Finalizes a stopped clip: layout cell, multi-clip segment, or quick video.
  Future<void> _completeRecordingSegment(
    String path, {
    bool autoFinish = false,
  }) async {
    if (_recordingFinalizeInFlight) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isBusy = false;
        });
      }
      return;
    }
    if (path.isEmpty) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isBusy = false;
        });
      }
      return;
    }

    _recordingFinalizeInFlight = true;
    _recordTimer?.cancel();
    try {
      if (!mounted) return;

      if (_layoutMode != CameraLayoutMode.off) {
        final mode = _layoutMode;
        final index = _layoutActiveCell;
        if (index >= 0 &&
            index < mode.cellCount &&
            index < _layoutCellPhotos.length &&
            _layoutCellPhotos[index] != null) {
          setState(() {
            _isRecording = false;
            _isBusy = false;
          });
          return;
        }
        setState(() {
          _isRecording = false;
          _isBusy = false;
        });
        await _handleLayoutVideo(File(path));
        return;
      }

      setState(() {
        _isRecording = false;
        _isBusy = false;
      });
      _videoSegments.add(path);
      _segmentSpeeds.add(_currentSegmentSpeed);
      if (autoFinish && _videoSegments.isNotEmpty) {
        await _finishMultiClipVideo();
      }
    } finally {
      _recordingFinalizeInFlight = false;
    }
  }

  Future<void> _finishMultiClipVideo() async {
    // Allow Next even if a pause is still settling.
    if (_isRecording) {
      await _pauseRecordingSegment();
    }
    if (!mounted) return;

    // After release, stopRecording / media callback may still be finishing.
    var waited = 0;
    while (mounted && waited < 100) {
      if (!_isBusy && _videoSegments.isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 50));
      waited++;
    }
    if (!mounted) return;

    if (_videoSegments.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cameraCaptureError('no_video'))),
      );
      return;
    }
    if (_isBusy) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cameraCaptureError('busy'))));
      return;
    }

    setState(() => _isBusy = true);
    final segments = List<String>.from(_videoSegments);
    final speeds = List<double>.from(_segmentSpeeds);
    try {
      // 1) Apply each segment's OWN recording speed first, so every portion of
      //    the timeline keeps the speed selected while it was recorded
      //    (TikTok-style), instead of one speed for the whole clip.
      final processed = <String>[];
      final speedTemps = <String>[];
      for (var i = 0; i < segments.length; i++) {
        final src = File(segments[i]);
        final speed = i < speeds.length ? speeds[i] : 1.0;
        final adjusted = await _applySpeedToSegment(src, speed);
        processed.add(adjusted.path);
        if (adjusted.path != src.path) speedTemps.add(adjusted.path);
      }

      // 2) Merge the speed-adjusted segments into a single clip.
      String? path;
      if (processed.length == 1) {
        path = processed.first;
      } else if (_useNativeArFilters) {
        try {
          path = await ArCameraBridge.mergeVideoSegments(processed);
        } catch (_) {
          path = null;
        }
      }
      path ??= processed.last;

      final outFile = File(path);
      if (!await outFile.exists() || await outFile.length() == 0) {
        throw StateError('empty_video');
      }

      // Clean up every intermediate file except the final output.
      void cleanupTemps() {
        for (final s in segments) {
          if (s != path) {
            try {
              File(s).deleteSync();
            } catch (_) {}
          }
        }
        for (final t in speedTemps) {
          if (t != path) {
            try {
              File(t).deleteSync();
            } catch (_) {}
          }
        }
      }

      _videoSegments.clear();
      _segmentSpeeds.clear();
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _recordSeconds = 0;
      });

      if (widget.isStory) {
        setState(() {
          _storyCapturedFile = outFile;
          _storyCapturedType = 'VIDEO';
        });
        cleanupTemps();
        return;
      }

      await _openCapturedMediaEditor(outFile, type: 'VIDEO');
      cleanupTemps();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cameraCaptureError(e.toString()))),
      );
    }
  }

  /// Handles a speed pick. While recording (non-layout), it splits the timeline
  /// so the portion already recorded keeps the old speed and the next portion
  /// records at the new speed — like TikTok. Otherwise it just updates the
  /// speed applied to the next segment.
  void _onSpeedSelected(double speed) {
    if (_speedPickerOpen) {
      setState(() => _speedPickerOpen = false);
    }
    if (speed == _selectedSpeed) return;
    if (_isRecording &&
        _layoutMode == CameraLayoutMode.off &&
        !_quickVideoMode) {
      unawaited(_splitSegmentForSpeedChange(speed));
    } else {
      setState(() => _selectedSpeed = speed);
    }
  }

  void _toggleSpeedPicker() {
    if (_layoutMode != CameraLayoutMode.off) return;
    setState(() {
      _speedPickerOpen = !_speedPickerOpen;
      if (_speedPickerOpen) {
        _layoutPickerOpen = false;
        _showPhotoEditor = false;
      }
    });
  }

  void _dismissToolPopups() {
    if (!_layoutPickerOpen && !_speedPickerOpen) return;
    setState(() {
      _layoutPickerOpen = false;
      _speedPickerOpen = false;
    });
  }

  void _toggleLayoutPicker() {
    setState(() {
      _layoutPickerOpen = !_layoutPickerOpen;
      if (_layoutPickerOpen) {
        _speedPickerOpen = false;
        _showPhotoEditor = false;
      }
    });
  }

  Future<void> _splitSegmentForSpeedChange(double speed) async {
    // Finalize the current segment at its (old) speed, then start a fresh one
    // recording at the new speed. The shared timer resumes so total length and
    // the max-duration cap stay continuous across the split.
    await _pauseRecordingSegment();
    if (!mounted) return;
    setState(() => _selectedSpeed = speed);
    if (_recordSeconds >= _effectiveMaxRecordSeconds) return;
    await _beginVideoRecording();
  }

  Future<File> _applySelectedSpeed(File input) =>
      _applySpeedToSegment(input, _selectedSpeed);

  /// Re-encodes [input] to play back at [speed]. Returns [input] unchanged for
  /// 1x (keeps original audio) or on failure.
  Future<File> _applySpeedToSegment(File input, double speed) async {
    if (speed == 1.0 || kIsWeb) return input;
    try {
      final adjusted = await NativeVideoProcessor.changeSpeed(
        input,
        speed: speed,
        muteAudio: true,
      );
      if (adjusted != null &&
          await adjusted.exists() &&
          await adjusted.length() > 0) {
        return adjusted;
      }
    } catch (e, st) {
      debugPrint('Apply segment speed failed: $e\n$st');
    }
    return input;
  }

  void _discardVideoDraft() {
    _recordTimer?.cancel();
    _holdRecordActive = false;
    _stopWhenRecordReady = false;
    for (final path in _videoSegments) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    _videoSegments.clear();
    _segmentSpeeds.clear();
    _pendingSegmentSpeeds.clear();
    if (_isRecording && _useNativeArFilters) {
      unawaited(ArCameraBridge.stopRecording().catchError((_) => null));
    }
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _isBusy = false;
      _quickVideoMode = false;
    });
  }

  Future<File> _applyRatioCropIfNeeded(File file) async {
    if (!_ratioLetterboxed || !mounted) return file;
    final media = MediaQuery.of(context);
    final viewport = CameraRatioLetterbox.previewSize(
      screenSize: media.size,
      topInset: media.padding.top,
      letterboxed: true,
      useNativeAr: _useNativeArFilters,
      filtersPanelOpen: _showFilters || _showPhotoEditor,
    );
    return CameraCaptureUtils.cropToFillCenterViewport(
      file: file,
      viewportSize: viewport,
    );
  }

  Future<void> _playShutterFlash() async {
    if (!mounted) return;
    setState(() => _showShutterFlash = true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (mounted) setState(() => _showShutterFlash = false);
  }

  Future<void> _capturePhoto() async {
    if (_isBusy || _isProcessingCapture || _isCapturingPhoto || _isRecording) {
      return;
    }

    // Native AR uses a GPU snapshot — white shutter flash only adds a visible blink.
    if (!_useNativeArFilters && _layoutMode == CameraLayoutMode.off) {
      unawaited(_playShutterFlash());
    }

    if (_useNativeArFilters) {
      _isCapturingPhoto = true;
      try {
        final media = MediaQuery.of(context);
        final dpr = media.devicePixelRatio;
        final path = await ArCameraBridge.takePhoto(
          letterboxTopPx: _ratioLetterboxed
              ? (CameraRatioLetterbox.topHeight(media.padding.top) * dpr)
                    .round()
              : 0,
          letterboxBottomPx: _ratioLetterboxed
              ? (CameraRatioLetterbox.bottomHeight(
                          useNativeAr: true,
                          filtersPanelOpen: _showFilters || _showPhotoEditor,
                        ) *
                        dpr)
                    .round()
              : 0,
        );
        if (!mounted) return;
        if (path == null || path.isEmpty) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.cameraCaptureError('no_frame'))),
          );
          return;
        }
        var file = File(path);
        // Native already crops letterboxed FOV to match preview — don't re-crop.
        if (!mounted) return;
        if (_layoutMode != CameraLayoutMode.off) {
          await _handleLayoutPhoto(file);
          return;
        }
        if (widget.isStory) {
          setState(() {
            _storyCapturedFile = file;
            _storyCapturedType = 'IMAGE';
          });
          return;
        }
        await _openCapturedMediaEditor(file, type: 'IMAGE');
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.cameraCaptureError(e.toString()))),
          );
        }
      } finally {
        _isCapturingPhoto = false;
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
    if (_recordSeconds >= _effectiveMaxRecordSeconds) return;

    if (_useNativeArFilters) {
      // Camera preview is already live — never show "Starting camera..." here.
      // That overlay was the first-tap flash; 2nd tap felt instant because
      // mic/encoder were already warm.
      try {
        final micOk = await CameraStudioPermissions.ensureMicrophone();
        if (!micOk || !mounted || _isRecording) return;
        if (_ratioLetterboxed) {
          await _syncNativePreviewLetterbox(letterboxed: true);
        }
        if (!mounted || _isRecording) return;
        final media = MediaQuery.of(context);
        final dpr = media.devicePixelRatio;
        await ArCameraBridge.startRecording(
          letterboxTopPx: _ratioLetterboxed
              ? (CameraRatioLetterbox.topHeight(media.padding.top) * dpr)
                    .round()
              : 0,
          letterboxBottomPx: _ratioLetterboxed
              ? (CameraRatioLetterbox.bottomHeight(
                          useNativeAr: true,
                          filtersPanelOpen: _showFilters || _showPhotoEditor,
                        ) *
                        dpr)
                    .round()
              : 0,
          maxDurationMs: _layoutMode != CameraLayoutMode.off
              ? _effectiveMaxRecordSeconds * 1000
              : null,
        );
        if (!mounted) return;
        _startRecordTimer(resume: _shouldResumeRecordTimer);
        if (_stopWhenRecordReady) {
          _stopWhenRecordReady = false;
          unawaited(_pauseRecordingSegment());
        }
      } catch (_) {
        _quickVideoMode = false;
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
        _startRecordTimer(resume: _shouldResumeRecordTimer);
        if (_stopWhenRecordReady) {
          _stopWhenRecordReady = false;
          unawaited(_pauseRecordingSegment());
        }
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
    final intensity = ArFilterCatalog.isColorFilter(id)
        ? _arFilterIntensity
        : 1.0;
    if (clamped == _arFilterIndex) {
      _applyArFilter(id, intensity: intensity);
      return;
    }
    setState(() => _arFilterIndex = clamped);
    _applyArFilter(id, intensity: intensity);
  }

  /// Single entry point for applying a filter id to the native camera —
  /// forwards AR-effect ids (glasses, stickers, distortion) via setFilter as
  /// before, and additionally pushes named beauty-preset params (Soft Glow,
  /// Pure, Rosy, Clean, ...) when [id] is one of those, or clears them when
  /// it isn't. Keeps every call site consistent instead of duplicating this.
  void _applyArFilter(String id, {double intensity = 1.0}) {
    // Identity change (switching filters) — setFilter re-triggers native
    // render-mode logic, so only call it here, never on intensity-only
    // updates (see _onArFilterIntensityChanged), or a slider drag ends up
    // spamming it dozens of times a second.
    ArCameraBridge.setFilter(id, intensity: intensity);
    _pushBeautyParams(ArFilterCatalog.colorFilterById(id)?.params, intensity);
  }

  void _pushBeautyParams(ArBeautyFilterParams? params, double intensity) {
    final magicSmooth =
        (_photoAdjustments[MediaPhotoEditorTool.smooth] ?? _kMagicAutoSmooth)
            .clamp(0.0, 1.0);
    if (params != null) {
      ArCameraBridge.setBeautyFilter(
        // Magic only boosts smooth — never whiten/brighten.
        smooth: _photoEditorMagicOn ? magicSmooth : params.smooth,
        whiten: params.whiten,
        brighten: params.brighten,
        blush: params.blush,
        lipTint: params.lipTint,
        lipStrength: params.lipStrength,
        intensity: intensity,
      );
      // Color grade (Fade/Fade Warm/Fade Cool) — same engine as the Face
      // retouch sliders. Identity grades keep the live Retouch-Off baseline.
      if (!params.hasColorGrade) {
        _syncRetouchToNative();
      } else {
        ArCameraBridge.setRetouchAdjustments(
          brightness: params.brightness * intensity,
          contrast: params.contrast * intensity,
          saturation: params.saturation * intensity,
          whiteBalance: params.warmth * intensity,
          // Filters only grade B/C/S/WB — keep live exposure/highlights/shadows.
          exposure: _liveColorAdj(MediaPhotoEditorTool.exposure),
          highlights: _liveColorAdj(MediaPhotoEditorTool.highlights),
          shadows: _liveColorAdj(MediaPhotoEditorTool.shadows),
        );
      }
      if (_photoEditorMagicOn) {
        ArCameraBridge.setMagicEnabled(true, strength: magicSmooth);
      }
    } else if (_photoEditorMagicOn) {
      ArCameraBridge.setMagicEnabled(true, strength: magicSmooth);
      _syncRetouchToNative();
    } else {
      ArCameraBridge.clearBeautyFilter();
      ArCameraBridge.clearRetouchAdjustments();
    }
  }

  void _onArColorCategorySelected(String categoryId) {
    if (categoryId == _arColorCategoryId) return;
    setState(() => _arColorCategoryId = categoryId);
  }

  Timer? _arFilterIntensityDebounce;

  void _onArFilterIntensityChanged(double value) {
    final clamped = value.clamp(0.0, 1.0);
    // Slider fires on every pixel of drag movement — keep the visible thumb
    // instant (setState below), but debounce the native push (was sending
    // setFilter + setBeautyFilter + setRetouchAdjustments on every tick,
    // which is what caused the freeze while dragging).
    setState(() => _arFilterIntensity = clamped);
    ArCameraBridge.setFilterIntensity(clamped);
    final id = ArFilterCatalog.items[_arFilterIndex].id;
    if (!ArFilterCatalog.isColorFilter(id)) return;
    _arFilterIntensityDebounce?.cancel();
    _arFilterIntensityDebounce = Timer(const Duration(milliseconds: 40), () {
      _pushBeautyParams(ArFilterCatalog.colorFilterById(id)?.params, clamped);
    });
  }

  void _onArPreviewSwipeEnd(double primaryVelocity) {
    if (!_useNativeArFilters ||
        _isRecording ||
        _showFilters ||
        _showPhotoEditor) {
      return;
    }
    final currentId = ArFilterCatalog.items[_arFilterIndex].id;
    final current = ArFilterCatalog.effectCarouselIndex(currentId);
    final count = ArFilterCatalog.effectItems.length;
    if (count == 0) return;
    final velocity = primaryVelocity;
    if (velocity < -80 || _arSwipeDrag < -36) {
      final next = (current + 1) % count;
      _onArFilterSelected(
        ArFilterCatalog.indexOfId(ArFilterCatalog.effectItems[next].id),
      );
    } else if (velocity > 80 || _arSwipeDrag > 36) {
      final prev = (current - 1 + count) % count;
      _onArFilterSelected(
        ArFilterCatalog.indexOfId(ArFilterCatalog.effectItems[prev].id),
      );
    }
    _arSwipeDrag = 0;
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdownValue != null && mounted) {
      setState(() => _countdownValue = null);
    } else {
      _countdownValue = null;
    }
  }

  void _runCountdown({int? seconds, required VoidCallback onDone}) {
    final start = seconds ?? _countdownDelaySeconds;
    _countdownTimer?.cancel();
    setState(() => _countdownValue = start);
    // TikTok-style: tick on every number, and a distinct beep on the final "1".
    _playCountdownTick(isFinal: start <= 1);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _countdownValue;
      if (current == null) {
        timer.cancel();
        return;
      }
      if (current <= 1) {
        timer.cancel();
        _countdownTimer = null;
        // doesn't auto-trigger on the next capture (and is off on return).
        setState(() {
          _countdownValue = null;
          _timerEnabled = false;
        });
        onDone();
      } else {
        final next = current - 1;
        setState(() => _countdownValue = next);
        _playCountdownTick(isFinal: next <= 1);
      }
    });
  }

  /// are disabled — Flutter's [SystemSound] was silent in that case.
  void _playCountdownTick({required bool isFinal}) {
    if (isFinal) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    ArCameraBridge.playCountdownTick(isFinal: isFinal);
  }

  void _openCountdownSheet() {
    if (_isRecording || _countdownValue != null || _isBusy) return;
    final l10n = AppLocalizations.of(context)!;
    final isPhoto = _studioMode == CameraStudioMode.photo;
    unawaited(
      CameraStudioSheets.showCountdownSheet(
        context,
        l10n: l10n,
        initialCountdownSeconds: _countdownDelaySeconds,
        timerEnabled: _timerEnabled,
        onTurnOff: () {
          if (!mounted) return;
          setState(() => _timerEnabled = false);
        },
        onStart: (countdownSeconds) {
          if (!mounted) return;
          setState(() {
            _countdownDelaySeconds = countdownSeconds;
            _timerEnabled = true;
          });
          _runCountdown(
            seconds: countdownSeconds,
            onDone: () {
              if (!mounted) return;
              if (isPhoto) {
                unawaited(_capturePhoto());
              } else if (!_isRecording) {
                unawaited(_beginVideoRecording());
              }
            },
          );
        },
      ),
    );
  }

  void _startRecordingWithOptionalTimer() {
    if (_timerEnabled) {
      _runCountdown(
        seconds: _countdownDelaySeconds,
        onDone: () {
          if (!mounted || _isRecording) return;
          unawaited(_beginVideoRecording());
        },
      );
      return;
    }
    unawaited(_beginVideoRecording());
  }

  /// Opens the LiveStartPage from lib/features/live_source/.
  Future<void> _handleGoLiveTap() async {
    if (_isRecording || _isBusy || _isProcessingCapture) return;
    try {
      // Remove the preview from the widget tree for BOTH camera engines. On
      // Android, calling stopCamera() while leaving the platform view mounted
      // lets its visibility callbacks bind CameraX again during the next route
      // transition. That races the Flutter/LiveKit cameras and is the source of
      // the several-second freeze seen at the start of a live.
      setState(() => _liveHandoffActive = true);
      if (_useNativeArFilters) {
        await ArCameraBridge.stopCamera();
      }
      // Let AndroidView/CameraX (or CamerAwesome on iOS) finish unmounting
      // before the live start page asks the operating system for the lens.
      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LiveStartPage()));
    } catch (_) {
      // Never leave a frozen preview.
    } finally {
      if (mounted) setState(() => _liveHandoffActive = false);
      // Back from the live start page: bring the camera preview back.
      if (_useNativeArFilters && mounted) {
        // The AndroidView is created asynchronously after setState. Give its
        // platform controller one frame to attach before asking it to start.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (mounted) {
          await ArCameraBridge.startCamera();
          if (mounted) {
            _applyArFilter(ArFilterCatalog.items[_arFilterIndex].id);
            if (_photoEditorMagicOn) {
              ArCameraBridge.setMagicEnabled(true, strength: _kMagicAutoSmooth);
            }
            _syncRetouchToNative();
          }
        }
      }
    }
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

  Future<void> _applyZoom(double zoom, {bool force = false}) async {
    final clamped = zoom.clamp(0.0, 1.0);
    if (!force && (clamped - _selectedZoom).abs() < 0.008) {
      return;
    }
    if (mounted) {
      setState(() => _selectedZoom = clamped);
    } else {
      _selectedZoom = clamped;
    }
    if (_useNativeArFilters) {
      try {
        await ArCameraBridge.setZoom(clamped);
      } catch (_) {}
      return;
    }
    final state = _cameraState;
    if (state == null) return;
    await state.sensorConfig.setZoom(clamped);
  }

  void _onPreviewScaleStart(ScaleStartDetails details) {
    _pinchBaseZoom = _selectedZoom;
    _isPinchingZoom = false;
    _arSwipeDrag = 0;
  }

  void _onPreviewScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      if (!_isPinchingZoom) {
        _isPinchingZoom = true;
        _pinchBaseZoom = _selectedZoom;
        if (_layoutPickerOpen || _speedPickerOpen) {
          setState(() {
            _layoutPickerOpen = false;
            _speedPickerOpen = false;
          });
        }
      }
      final next =
          (_pinchBaseZoom + (details.scale - 1.0) * _pinchZoomSensitivity)
              .clamp(0.0, 1.0);
      unawaited(_applyZoom(next));
      return;
    }
    if (_isPinchingZoom) return;
    _arSwipeDrag += details.focalPointDelta.dx;
  }

  void _onPreviewScaleEnd(ScaleEndDetails details) {
    if (_isPinchingZoom) {
      _isPinchingZoom = false;
      if (mounted) setState(() {});
      return;
    }
    // Scale gestures carry a two-dimensional velocity. Constructing
    // DragEndDetails from it asserts when the user's finger leaves diagonally;
    // only the horizontal component decides the effect carousel direction.
    _onArPreviewSwipeEnd(details.velocity.pixelsPerSecond.dx);
  }

  Widget _wrapPreviewGestures(Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: _onPreviewScaleStart,
      onScaleUpdate: _onPreviewScaleUpdate,
      onScaleEnd: _onPreviewScaleEnd,
      child: child,
    );
  }

  Future<void> _flipCamera() async {
    _cancelCountdown();
    if (_useNativeArFilters) {
      if (_isRecording || _isBusy) return;
      try {
        final isFront = await ArCameraBridge.flipCamera();
        if (!mounted) return;
        setState(() {
          _isFrontCamera = isFront;
          _selectedZoom = CameraStudioConstants.zoomSteps.first.value;
          // Always reset on flip, not just when Magic/Retouch is off. Each
          // camera's color values are independent (front's own set, back's
          // empty/person-present set computed natively) — gating this on
          // Magic being off meant that, in the default Magic-on state,
          // flipping cameras never reset or re-sent the color values, so the
          // new camera just kept whatever the previous camera had applied.
          _restoreLiveColorDefaults();
        });
        _faceDetectorService.isFrontCamera = isFront;
        _syncRetouchToNative();
        unawaited(_applyZoom(_selectedZoom, force: true));
      } catch (_) {}
      return;
    }
    await _cameraState?.switchCameraSensor();
    if (mounted) {
      setState(() {
        _isFrontCamera = !_isFrontCamera;
        _selectedZoom = CameraStudioConstants.zoomSteps.first.value;
      });
      _faceDetectorService.isFrontCamera = _isFrontCamera;
      unawaited(_applyZoom(_selectedZoom, force: true));
    }
  }

  void _selectEffect(String? slug) {
    setState(() => _selectedEffectSlug = slug);
    final effect = slug == null ? null : CameraEffectsCatalog.bySlug(slug);
    if (effect?.hasAsset == true) {
      unawaited(CameraEffectAssetLoader.preload(effect!.assetUrl));
    }
  }

  Future<void> _toggleFlash() async {
    if (_useNativeArFilters) {
      try {
        final enabled = await ArCameraBridge.toggleTorch();
        if (!mounted) return;
        setState(() => _flashEnabled = enabled);
      } catch (_) {}
      return;
    }
    _cameraState?.sensorConfig.switchCameraFlash();
    setState(() => _flashEnabled = !_flashEnabled);
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

  void _clearLayoutCapture({bool deleteFiles = true}) {
    if (deleteFiles) {
      for (final path in _layoutCellPhotos) {
        if (path == null) continue;
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
    }
    _layoutCellPhotos = const [];
    _layoutActiveCell = 0;
    _layoutCellCapSeconds = null;
  }

  void _toggleRatioLetterbox() {
    final next = !_ratioLetterboxed;
    setState(() => _ratioLetterboxed = next);
    unawaited(_syncNativePreviewLetterbox(letterboxed: next));
  }

  Future<void> _syncNativePreviewLetterbox({bool? letterboxed}) async {
    if (!_useNativeArFilters) return;
    final on = letterboxed ?? _ratioLetterboxed;
    if (!on) {
      await ArCameraBridge.setPreviewLetterbox(topPx: 0, bottomPx: 0);
      return;
    }
    if (!mounted) return;
    final media = MediaQuery.of(context);
    final dpr = media.devicePixelRatio;
    final top = CameraRatioLetterbox.topHeight(media.padding.top);
    final bottom = CameraRatioLetterbox.bottomHeight(
      useNativeAr: true,
      filtersPanelOpen: _showFilters || _showPhotoEditor,
    );
    await ArCameraBridge.setPreviewLetterbox(
      topPx: (top * dpr).round(),
      bottomPx: (bottom * dpr).round(),
    );
  }

  void _onLayoutModeSelected(CameraLayoutMode mode) {
    _clearLayoutCapture();
    if (mode != CameraLayoutMode.off) {
      _discardVideoDraft();
    }
    setState(() {
      _layoutMode = mode;
      _speedPickerOpen = false;
      if (mode != CameraLayoutMode.off) {
        // Live has no grid capture — fall back to photo. Photo/video keep mode.
        if (_studioMode == CameraStudioMode.live) {
          _studioMode = CameraStudioMode.photo;
        }
        _layoutActiveCell = 0;
        _layoutCellPhotos = List<String?>.filled(mode.cellCount, null);
        _layoutCellCapSeconds = null;
        _recordSeconds = 0;
      }
    });
  }

  Future<void> _handleLayoutPhoto(File raw) async {
    final mode = _layoutMode;
    if (mode == CameraLayoutMode.off) return;

    final index = _layoutActiveCell;
    final next = List<String?>.from(_layoutCellPhotos);
    next[index] = raw.path;
    final filled = next.whereType<String>().length;

    if (filled >= mode.cellCount) {
      setState(() {
        _layoutCellPhotos = next;
        _layoutActiveCell = mode.cellCount;
        _isProcessingCapture = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      try {
        final composed = await CameraLayoutComposer.compose(
          mode: mode,
          cellPaths: next.whereType<String>().toList(),
        );
        if (!mounted) return;
        _clearLayoutCapture();
        setState(() {
          _layoutMode = CameraLayoutMode.off;
          _isProcessingCapture = false;
        });
        if (widget.isStory) {
          setState(() {
            _storyCapturedFile = composed;
            _storyCapturedType = 'IMAGE';
          });
          return;
        }
        await _openCapturedMediaEditor(composed, type: 'IMAGE');
      } catch (_) {
        if (mounted) setState(() => _isProcessingCapture = false);
      }
      return;
    }

    setState(() {
      _layoutCellPhotos = next;
      // Advance to the first still-empty frame (handles gaps left by delete).
      _layoutActiveCell = next.indexWhere((p) => p == null);
    });
  }

  Future<void> _handleLayoutVideo(File raw) async {
    final mode = _layoutMode;
    if (mode == CameraLayoutMode.off) return;

    // Cap later cells to the shortest take so far (TikTok layout rule).
    final recordedSecs = _recordSeconds.clamp(1, 600);
    final prevCap = _layoutCellCapSeconds;
    _layoutCellCapSeconds = prevCap == null
        ? recordedSecs
        : (recordedSecs < prevCap ? recordedSecs : prevCap);

    final next = List<String?>.from(_layoutCellPhotos);
    if (next.length != mode.cellCount) {
      next
        ..clear()
        ..addAll(List<String?>.filled(mode.cellCount, null));
    }
    final emptyIndex = next.indexWhere((p) => p == null);
    final index = (_layoutActiveCell >= 0 && _layoutActiveCell < mode.cellCount)
        ? _layoutActiveCell
        : emptyIndex;
    if (index < 0 || next[index] != null) return;
    next[index] = raw.path;
    final filled = next.whereType<String>().length;

    if (filled >= mode.cellCount) {
      setState(() {
        _layoutCellPhotos = next;
        _layoutActiveCell = mode.cellCount;
        _isProcessingCapture = true;
        _recordSeconds = 0;
      });
      await WidgetsBinding.instance.endOfFrame;
      try {
        final composed = await CameraLayoutVideoComposer.compose(
          mode: mode,
          cellPaths: next.whereType<String>().toList(),
        );
        if (!mounted) return;
        final withSpeed = await _applySelectedSpeed(composed);
        final speedChanged = withSpeed.path != composed.path;
        _clearLayoutCapture();
        setState(() {
          _layoutMode = CameraLayoutMode.off;
          _isProcessingCapture = false;
        });
        if (widget.isStory) {
          setState(() {
            _storyCapturedFile = withSpeed;
            _storyCapturedType = 'VIDEO';
          });
          if (speedChanged) {
            try {
              composed.deleteSync();
            } catch (_) {}
          }
          return;
        }
        await _openCapturedMediaEditor(withSpeed, type: 'VIDEO');
        if (speedChanged) {
          try {
            composed.deleteSync();
          } catch (_) {}
        }
      } catch (_) {
        if (mounted) setState(() => _isProcessingCapture = false);
      }
      return;
    }

    setState(() {
      _layoutCellPhotos = next;
      // Advance to the first still-empty frame (handles gaps left by delete).
      final nextEmpty = next.indexWhere((p) => p == null);
      _layoutActiveCell = nextEmpty < 0 ? mode.cellCount : nextEmpty;
      _recordSeconds = 0;
      _isRecording = false;
      _isBusy = false;
    });
  }

  /// Removes the captured media from [index] and shifts later cells left so
  /// there is no empty gap in the middle of the grid.
  void _deleteLayoutCell(int index) {
    if (_layoutMode == CameraLayoutMode.off) return;
    if (index < 0 || index >= _layoutCellPhotos.length) return;
    final path = _layoutCellPhotos[index];
    if (path == null) return;
    try {
      File(path).deleteSync();
    } catch (_) {}

    final kept = <String>[
      for (var i = 0; i < _layoutCellPhotos.length; i++)
        if (i != index && _layoutCellPhotos[i] != null) _layoutCellPhotos[i]!,
    ];
    final next = List<String?>.filled(_layoutMode.cellCount, null);
    for (var i = 0; i < kept.length; i++) {
      next[i] = kept[i];
    }

    setState(() {
      _layoutCellPhotos = next;
      _layoutActiveCell = next.indexWhere((p) => p == null);
      _recordSeconds = 0;
    });
  }

  /// Copies the captured media at [index] into the next empty frame so the same
  /// shot appears in more than one cell.
  Future<void> _duplicateLayoutCell(int index) async {
    if (_layoutMode == CameraLayoutMode.off) return;
    if (index < 0 || index >= _layoutCellPhotos.length) return;
    final source = _layoutCellPhotos[index];
    if (source == null) return;

    final target = _layoutCellPhotos.indexWhere((p) => p == null);
    if (target < 0) return; // grid already full — nothing to duplicate into.

    File copy;
    try {
      final src = File(source);
      final dot = source.lastIndexOf('.');
      final ext = dot >= 0 ? source.substring(dot) : '';
      final dst =
          '${src.parent.path}/dup_${DateTime.now().microsecondsSinceEpoch}$ext';
      copy = await src.copy(dst);
    } catch (_) {
      return;
    }

    // Reuse the normal capture flow so the grid auto-composes when it fills up.
    // A grid is always all-photo or all-video, decided by the studio mode.
    _layoutActiveCell = target;
    if (_studioMode == CameraStudioMode.video) {
      await _handleLayoutVideo(copy);
    } else {
      await _handleLayoutPhoto(copy);
    }
  }

  /// Imports a gallery photo into a specific empty frame [index].
  Future<void> _importLayoutCell(int index) async {
    if (_layoutMode == CameraLayoutMode.off) return;
    if (index < 0 || index >= _layoutCellPhotos.length) return;
    if (_layoutCellPhotos[index] != null) return;

    List<GalleryMediaItem> picked;
    try {
      picked = await MediaGalleryPicker.pickSingleImage();
    } catch (_) {
      return;
    }
    if (picked.isEmpty || !mounted) return;
    if (_layoutMode == CameraLayoutMode.off) return;
    if (index >= _layoutCellPhotos.length || _layoutCellPhotos[index] != null) {
      return;
    }

    // Drop the chosen image into that exact frame and reuse the photo flow so
    // the grid auto-composes once every frame is filled.
    _layoutActiveCell = index;
    await _handleLayoutPhoto(picked.first.file);
  }

  void _showComingSoon(String message) {
    PopupDialogs.showErrorDialog(context, message);
  }

  void _onWorkspaceTabSelected(int index) {
    setState(() => _workspaceTabIndex = index);
    if (index == 1) {
      if (_studioMode == CameraStudioMode.photo) {
        unawaited(_openPhotoTemplates());
      } else {
        CameraStudioSheets.showEffectsPicker(
          context,
          l10n: AppLocalizations.of(context)!,
          selectedEffectSlug: _selectedEffectSlug,
          onSelected: (slug) => _selectEffect(slug),
        );
      }
    }
  }

  Future<void> _openPhotoTemplates() async {
    final picked = await VideoTemplatesPickerSheet.showPhotoTemplates(
      context,
      selectedTemplateId: _videoTemplateId,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _videoTemplateId = picked.templateId;
      _videoTemplateName = picked.name;
      _videoTemplateSlotCount = VideoTemplateSlotFiller.slotsForSelection(
        slotCount: picked.slotCount,
        recipeApplySlotCount: picked.recipe?.applySlotCount,
      );
      _templateProjectId = picked.projectId;
      if (picked.sound != null) {
        _selectedSound = picked.sound;
        _pickedSoundSegmentId = picked.soundSegmentId;
        _soundDidTrim = picked.soundSegmentId != null;
        _soundStartOffset = Duration.zero;
        _soundWindow = const Duration(seconds: 15);
      } else if (picked.soundSegmentId != null) {
        _pickedSoundSegmentId = picked.soundSegmentId;
      }
    });
    final need =
        _videoTemplateSlotCount ?? VideoTemplateSlotFiller.minPhotoDumpSlots;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${picked.name} applied — your photo keeps one slide'
          '${need > 1 ? '; $need slots fill on publish' : ''}',
        ),
      ),
    );
  }

  void _onStudioModeSelected(CameraStudioMode mode) {
    if (_isRecording) return;
    if (widget.isStory && mode == CameraStudioMode.live) return;
    if (mode == _studioMode) {
      if (_showPhotoEditor || _showFilters) {
        setState(() {
          _showPhotoEditor = false;
          _showFilters = false;
        });
      }
      return;
    }

    _cancelCountdown();
    // Live cannot use grid cells — clear layout. Photo↔video keeps layout
    // but resets cell media so a grid is not mixed photos+videos.
    if (mode == CameraStudioMode.live && _layoutMode != CameraLayoutMode.off) {
      _clearLayoutCapture();
      setState(() => _layoutMode = CameraLayoutMode.off);
    } else if (_layoutMode != CameraLayoutMode.off &&
        mode != _studioMode &&
        (mode == CameraStudioMode.photo || mode == CameraStudioMode.video)) {
      final layoutMode = _layoutMode;
      _clearLayoutCapture();
      _layoutActiveCell = 0;
      _layoutCellPhotos = List<String?>.filled(layoutMode.cellCount, null);
      _recordSeconds = 0;
    }
    if (mode == CameraStudioMode.photo && _videoSegments.isNotEmpty) {
      _discardVideoDraft();
    }

    setState(() {
      _studioMode = mode;
      // A mode choice must remain usable while a bottom editor is open.
      // Dismiss the editor after selection so its panel cannot cover the
      // capture controls for the newly selected mode.
      _showPhotoEditor = false;
      _showFilters = false;
    });

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
    if (_studioMode == CameraStudioMode.live) return;

    if (_countdownValue != null) {
      _cancelCountdown();
      return;
    }

    if (_studioMode == CameraStudioMode.photo) {
      if (_isRecording) {
        unawaited(_pauseRecordingSegment());
      } else if (_timerEnabled) {
        _runCountdown(
          seconds: _countdownDelaySeconds,
          onDone: () {
            if (!mounted) return;
            unawaited(_capturePhoto());
          },
        );
      } else {
        unawaited(_capturePhoto());
      }
      return;
    }

    // Video: TikTok-style tap-to-start / tap-to-stop. A tap while recording
    // stops (pauses) the current segment; a tap while idle starts recording
    // (running the timer countdown first when the timer is on). Press-and-hold
    // is handled separately by [_onRecordHoldStart]/[_onRecordHoldEnd].
    if (_studioMode != CameraStudioMode.photo) {
      if (_isRecording) {
        unawaited(_pauseRecordingSegment());
        return;
      }
      if (_isBusy) return;
      if (_recordSeconds >= _effectiveMaxRecordSeconds) return;
      _startRecordingWithOptionalTimer();
    }
  }

  void _onRecordHoldStart() {
    if (_studioMode == CameraStudioMode.live) return;
    if (_countdownValue != null) return;
    if (_isBusy || _isRecording) return;

    _holdRecordActive = true;
    _stopWhenRecordReady = false;

    if (_studioMode == CameraStudioMode.photo) {
      // Photo mode: press-and-hold records a TikTok-style quick video
      // (auto-stops at 15s, releasing early stops sooner). Skip while a
      // layout grid is active — that flow captures per-cell clips itself.
      if (_layoutMode != CameraLayoutMode.off) {
        _holdRecordActive = false;
        return;
      }
      _quickVideoMode = true;
      unawaited(_beginVideoRecording());
      return;
    }

    if (_recordSeconds >= _effectiveMaxRecordSeconds) {
      _holdRecordActive = false;
      return;
    }
    _startRecordingWithOptionalTimer();
  }

  void _onRecordHoldEnd() {
    if (_studioMode == CameraStudioMode.live) return;

    // Photo-mode quick video: releasing finishes and opens the editor.
    if (_quickVideoMode) {
      _holdRecordActive = false;
      _stopWhenRecordReady = false;
      unawaited(_finishQuickVideo());
      return;
    }

    if (_studioMode == CameraStudioMode.photo) {
      _holdRecordActive = false;
      return;
    }
    // Timed countdown keeps running after release (step-back selfie).
    if (_countdownValue != null) {
      _holdRecordActive = false;
      return;
    }

    final wasHolding = _holdRecordActive;
    _holdRecordActive = false;

    if (_isRecording) {
      _stopWhenRecordReady = false;
      unawaited(_pauseRecordingSegment());
    } else if (wasHolding) {
      // Start still in flight (or shutter rebuilt mid-hold) — stop once armed.
      _stopWhenRecordReady = true;
    }
  }

  void _onHoldPointerLift(PointerEvent event) {
    if (!_holdRecordActive) return;
    _onRecordHoldEnd();
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
        soundOffset: _soundStartOffset,
        soundWindow: _soundWindow,
        soundDidTrim: _soundDidTrim,
        soundSegmentId: _pickedSoundSegmentId,
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
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: _onHoldPointerLift,
        onPointerCancel: _onHoldPointerLift,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_liveHandoffActive)
              const ColoredBox(color: Colors.black)
            else if (_useNativeArFilters)
              _buildNativeArCameraBody(l10n, filters)
            else
              _buildCamerAwesomeBody(l10n, filters),
            if (_showShutterFlash)
              const IgnorePointer(child: ColoredBox(color: Color(0xE6FFFFFF))),
            if (_isProcessingCapture)
              CameraAppLoading(message: l10n.promoteProcessing),
            if (_isBusy && !_isProcessingCapture)
              CameraAppLoading(message: l10n.promoteProcessing),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeArPreviewHost() {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screen = Size(constraints.maxWidth, constraints.maxHeight);
          final media = MediaQuery.of(context);
          final layoutOn = _layoutMode != CameraLayoutMode.off;

          Rect? layoutFrame;
          Offset layoutShift = Offset.zero;
          if (layoutOn) {
            final mode = _layoutMode;
            final last = mode.cellCount - 1;
            final active = last < 0
                ? 0
                : (_layoutActiveCell < 0
                      ? 0
                      : (_layoutActiveCell > last ? last : _layoutActiveCell));
            final cell = mode.cellRect(screen, active);
            layoutFrame = CameraLayoutComposer.previewFrameForCell(
              screen: screen,
              cell: cell,
            );
            layoutShift =
                layoutFrame.center -
                Offset(screen.width / 2, screen.height / 2);
          }

          final isPhoto = _studioMode == CameraStudioMode.photo;
          final videoTop = CameraRatioLetterbox.tikTokTopChromeHeight(
            media.padding.top,
          );
          final photoTop = CameraRatioLetterbox.tikTokTopChromeHeight(
            media.padding.top,
            photoMode: true,
          );
          final videoBottom = CameraRatioLetterbox.tikTokBottomChromeHeight(
            media.padding.bottom,
          );
          final photoBottom = CameraRatioLetterbox.tikTokBottomChromeHeight(
            media.padding.bottom,
            photoMode: true,
          );
          final letterboxTop = CameraRatioLetterbox.topHeight(
            media.padding.top,
          );
          final letterboxBottom = CameraRatioLetterbox.bottomHeight(
            useNativeAr: true,
            filtersPanelOpen: _showFilters || _showPhotoEditor,
          );

          // Keep ArCameraPreview at a fixed full-screen layout size. Layout mode
          // only changes clip + translate — resizing SurfaceView blacks it out.
          return TweenAnimationBuilder<double>(
            duration: CameraRatioLetterbox.chromeAnimDuration,
            curve: CameraRatioLetterbox.chromeAnimCurve,
            tween: Tween<double>(
              end: _ratioLetterboxed ? 0.0 : (isPhoto ? 1.0 : 0.0),
            ),
            builder: (context, t, child) {
              if (layoutFrame != null) {
                return ClipPath(
                  clipper: RectPreviewClipper(layoutFrame),
                  child: Transform.translate(offset: layoutShift, child: child),
                );
              }
              final top = _ratioLetterboxed
                  ? letterboxTop
                  : (videoTop + (photoTop - videoTop) * t);
              final bottom = _ratioLetterboxed
                  ? letterboxBottom
                  : (videoBottom + (photoBottom - videoBottom) * t);
              return ClipPath(
                clipper: TikTokPreviewClipper(top: top, bottom: bottom),
                child: child,
              );
            },
            child: SizedBox(
              width: screen.width,
              height: screen.height,
              child: ArCameraPreview(key: _arPreviewKey),
            ),
          );
        },
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
          child: _wrapPreviewGestures(_buildNativeArPreviewHost()),
        ),
        if (_flashEnabled && _isFrontCamera)
          const Positioned.fill(child: FrontScreenFlashOverlay()),
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
          selectedDuration: _effectiveMaxRecordSeconds,
          selectedSpeed: _selectedSpeed,
          studioMode: _studioMode,
          showFilters: _showFilters,
          showPhotoEditor: _showPhotoEditor,
          beautyEnabled:
              _beautyEnabled ||
              _photoEditorMagicOn ||
              _photoAdjustments.values.any((v) => v.abs() > 0.02),
          photoEditorTab: _photoEditorTab,
          photoEditorTool: _photoEditorTool,
          photoEditorMagicOn: _photoEditorMagicOn,
          photoEditorAdjustments: _photoAdjustments,
          onPhotoEditorTabChanged: (tab) =>
              setState(() => _photoEditorTab = tab),
          onPhotoEditorToolSelected: (tool) =>
              setState(() => _photoEditorTool = tool),
          onPhotoEditorMagicToggled: _onPhotoEditorMagicToggled,
          onPhotoEditorAdjustmentChanged: _onPhotoEditorAdjustmentChanged,
          onPhotoEditorReset: _resetPhotoEditor,
          photoEditorColorFilterId: () {
            final id = ArFilterCatalog.items[_arFilterIndex].id;
            return ArFilterCatalog.isColorFilter(id) ? id : 'none';
          }(),
          photoEditorColorFilterIntensity: _arFilterIntensity,
          onPhotoEditorColorFilterSelected: _onMakeupFilmFilterSelected,
          onPhotoEditorColorFilterIntensityChanged: _onArFilterIntensityChanged,
          timerEnabled: _timerEnabled,
          flashEnabled: _flashEnabled,
          isRecording: _isRecording,
          isBusy: _isBusy || _isProcessingCapture,
          recordSeconds: _recordSeconds,
          hasDraftClips:
              _layoutMode == CameraLayoutMode.off && _videoSegments.isNotEmpty,
          onFinishRecording: () {
            unawaited(_finishMultiClipVideo());
          },
          onDiscardDraft: _discardVideoDraft,
          countdownValue: _countdownValue,
          selectedEffectSlug: null,
          workspaceTabIndex: _workspaceTabIndex,
          onClose: () => context.pop(),
          onFilterCategorySelected: _onFilterCategorySelected,
          onFilterSelected: _applyFilter,
          onClearFilter: _clearFilter,
          onDurationSelected: _onDurationSelected,
          onStudioModeSelected: _onStudioModeSelected,
          onEffectsTap: () {},
          onUploadTap: () => CameraStudioSheets.pickFromLibrary(
            context,
            l10n: l10n,
            limit: widget.isStory ? 1 : 5,
            chooseMediaType: true,
            onPicked: _importFromGallery,
          ),
          onGoLiveTap: _handleGoLiveTap,
          onRecordTap: _onRecordTap,
          onFlip: _flipCamera,
          onFlash: _toggleFlash,
          onSpeedTap: _toggleSpeedPicker,
          onBeautyTap: _togglePhotoEditor,
          onFiltersToggle: () {
            final next = !_showFilters;
            setState(() {
              _showFilters = next;
              if (next) _showPhotoEditor = false;
            });
            // Deliberately NOT re-syncing the native letterbox margins here.
            // bottomHeight() shrinks by ~48px while this panel is open, but
            // that's purely cosmetic — the live preview's ClipPath already
            // reflects it (see _buildNativeArCameraBody). Re-applying it
            // natively via ArCameraBridge.setPreviewLetterbox changes
            // previewView/warpGlView's actual layout margins, which resizes
            // the underlying SurfaceView — the exact thing this screen's own
            // ArCameraPreview sizing comment warns blacks/freezes the camera
            // out ("resizing SurfaceView blacks it out"). Was causing a
            // brief camera freeze on every open AND close of this panel.
            if (next) {
              unawaited(ArCameraBridge.prepareShaderPipeline());
            }
          },
          onTimerToggle: _openCountdownSheet,
          onMusicTap: _pickSound,
          onClearSound: _selectedSound == null ? null : _clearSound,
          onLayoutTap: _toggleLayoutPicker,
          onAspectRatioTap: _toggleRatioLetterbox,
          onTextModeTap: () => _showComingSoon(l10n.cameraLiveComingSoon),
          ratioLetterboxed: _ratioLetterboxed,
          selectedLayoutMode: _layoutMode,
          layoutPickerOpen: _layoutPickerOpen,
          onLayoutModeSelected: _onLayoutModeSelected,
          speedPickerOpen: _speedPickerOpen,
          onSpeedSelected: _onSpeedSelected,
          onDismissToolPopups: _dismissToolPopups,
          layoutCellPhotos: _layoutCellPhotos,
          layoutActiveCellIndex: _layoutActiveCell,
          onLayoutCellDelete: _deleteLayoutCell,
          onLayoutCellDuplicate: (index) =>
              unawaited(_duplicateLayoutCell(index)),
          onLayoutCellImport: _studioMode == CameraStudioMode.video
              ? null
              : (index) => unawaited(_importLayoutCell(index)),
          onWorkspaceTabSelected: (index) {
            setState(() => _workspaceTabIndex = index);
          },
          soundLabel: _studioMode == CameraStudioMode.live
              ? l10n.cameraLiveTitleHint
              : (_selectedSound?.name ?? l10n.cameraAddSound),
          onLongPressStart: (_) => _onRecordHoldStart(),
          onLongPressEnd: (_) => _onRecordHoldEnd(),
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
          // Mirror only when the active sensor is actually the front camera.
          // This prevents a brief "wrong mirrored" preview flash during
          // layout reconfiguration.
          mirrorFrontCamera: _isFrontCamera,
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

          return Stack(
            fit: StackFit.expand,
            children: [
              _wrapPreviewGestures(const SizedBox.expand()),
              CameraStudioOverlay(
                l10n: l10n,
                isStoryMode: widget.isStory,
                showGalleryUpload: !widget.returnMediaOnDone,
                cameraState: state,
                preview: preview,
                faceStream: _faceDetectorService.stream,
                filters: filters,
                filterCategorySlug: _filterCategorySlug,
                selectedFilter: _selectedFilter,
                selectedDuration: _effectiveMaxRecordSeconds,
                selectedSpeed: _selectedSpeed,
                studioMode: _studioMode,
                showFilters: _showFilters && _filtersReady,
                showPhotoEditor: _showPhotoEditor,
                beautyEnabled:
                    _beautyEnabled ||
                    _photoEditorMagicOn ||
                    _photoAdjustments.values.any((v) => v.abs() > 0.02),
                photoEditorTab: _photoEditorTab,
                photoEditorTool: _photoEditorTool,
                photoEditorMagicOn: _photoEditorMagicOn,
                photoEditorAdjustments: _photoAdjustments,
                onPhotoEditorTabChanged: (tab) =>
                    setState(() => _photoEditorTab = tab),
                onPhotoEditorToolSelected: (tool) =>
                    setState(() => _photoEditorTool = tool),
                onPhotoEditorMagicToggled: _onPhotoEditorMagicToggled,
                onPhotoEditorAdjustmentChanged: _onPhotoEditorAdjustmentChanged,
                onPhotoEditorReset: _resetPhotoEditor,
                photoEditorColorFilterId: () {
                  final id = ArFilterCatalog.items[_arFilterIndex].id;
                  return ArFilterCatalog.isColorFilter(id) ? id : 'none';
                }(),
                photoEditorColorFilterIntensity: _arFilterIntensity,
                onPhotoEditorColorFilterSelected: _onMakeupFilmFilterSelected,
                onPhotoEditorColorFilterIntensityChanged:
                    _onArFilterIntensityChanged,
                timerEnabled: _timerEnabled,
                flashEnabled: _flashEnabled,
                isRecording: _isRecording,
                isBusy: _isBusy || _isProcessingCapture,
                recordSeconds: _recordSeconds,
                hasDraftClips:
                    _layoutMode == CameraLayoutMode.off &&
                    _videoSegments.isNotEmpty,
                onFinishRecording: () {
                  unawaited(_finishMultiClipVideo());
                },
                onDiscardDraft: _discardVideoDraft,
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
                onGoLiveTap: _handleGoLiveTap,
                onRecordTap: _onRecordTap,
                onFlip: _flipCamera,
                onFlash: _toggleFlash,
                onSpeedTap: _toggleSpeedPicker,
                onBeautyTap: _togglePhotoEditor,
                onFiltersToggle: () => setState(() {
                  _showFilters = !_showFilters;
                  if (_showFilters) _showPhotoEditor = false;
                }),
                onTimerToggle: _openCountdownSheet,
                onMusicTap: _pickSound,
                onClearSound: _selectedSound == null ? null : _clearSound,
                onLayoutTap: _toggleLayoutPicker,
                onAspectRatioTap: _toggleRatioLetterbox,
                onTextModeTap: () => _showComingSoon(l10n.cameraLiveComingSoon),
                ratioLetterboxed: _ratioLetterboxed,
                selectedLayoutMode: _layoutMode,
                layoutPickerOpen: _layoutPickerOpen,
                onLayoutModeSelected: _onLayoutModeSelected,
                speedPickerOpen: _speedPickerOpen,
                onSpeedSelected: _onSpeedSelected,
                onDismissToolPopups: _dismissToolPopups,
                layoutCellPhotos: _layoutCellPhotos,
                layoutActiveCellIndex: _layoutActiveCell,
                onLayoutCellDelete: _deleteLayoutCell,
                onLayoutCellDuplicate: (index) =>
                    unawaited(_duplicateLayoutCell(index)),
                onLayoutCellImport: _studioMode == CameraStudioMode.video
                    ? null
                    : (index) => unawaited(_importLayoutCell(index)),
                onWorkspaceTabSelected: _onWorkspaceTabSelected,
                soundLabel: _studioMode == CameraStudioMode.live
                    ? l10n.cameraLiveTitleHint
                    : (_selectedSound?.name ?? l10n.cameraAddSound),
                onLongPressStart: (_) => _onRecordHoldStart(),
                onLongPressEnd: (_) => _onRecordHoldEnd(),
                filterLabelBuilder: (preset) => _filterLabel(l10n, preset),
              ),
            ],
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
