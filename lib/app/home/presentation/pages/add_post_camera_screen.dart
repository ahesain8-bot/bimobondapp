import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_preview.dart';
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
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_sheet.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
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
  // Preserve native preview identity across layout mode changes to avoid a
  // brief native re-init ("blink") when the preview widget moves.
  static const _arPreviewKey = ValueKey<String>('ar-camera-preview');
  bool _pendingVideoStart = false;
  bool _returnToPhotoAfterVideo = false;
  bool _showFilters = false;
  bool _catalogLoading = true;
  bool _filtersReady = false;
  bool _beautyEnabled = false;
  bool _timerEnabled = false;
  int _countdownDelaySeconds = 3;
  bool _flashEnabled = false;
  bool _ratioLetterboxed = false;
  bool _layoutPickerOpen = false;
  CameraLayoutMode _layoutMode = CameraLayoutMode.off;
  List<String?> _layoutCellPhotos = const [];
  int _layoutActiveCell = 0;
  bool _isRecording = false;
  bool _isBusy = false;
  bool _isProcessingCapture = false;
  bool _isCapturingPhoto = false;
  bool _showShutterFlash = false;

  /// True while a photo-mode press-and-hold is recording a quick video.
  bool _quickVideoMode = false;
  static const _quickVideoMaxSeconds = 15;

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
  double _selectedZoom = CameraStudioConstants.zoomSteps[1].value;
  int _selectedDuration = CameraStudioConstants.durationOptions.first;
  double _selectedSpeed = CameraStudioConstants.speedOptions[1];
  String? _selectedEffectSlug;
  CameraStudioMode _studioMode = CameraStudioMode.video;
  SoundEntity? _selectedSound;
  Duration _soundStartOffset = Duration.zero;
  Duration _soundWindow = const Duration(seconds: 15);
  bool _muteOriginalAudio = false;
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
  double _pinchBaseZoom = CameraStudioConstants.zoomSteps[1].value;
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
      ArCameraBridge.warmup();
      ArCameraBridge.setFilter(ArFilterCatalog.items[_arFilterIndex].id);
    }
    unawaited(CameraStudioPermissions.ensureCameraAndMicrophone());
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
    _clearLayoutCapture();
    if (_useNativeArFilters) {
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
    setState(() => _isBusy = true);
    try {
      if (widget.returnMediaOnDone) {
        final edited = await MediaGalleryImportFlow.openBatchEditor(
          context,
          items: items,
          isStory: widget.isStory,
          initialSound: _selectedSound,
          initialSoundOffset: _soundStartOffset,
          initialMuteOriginal: _muteOriginalAudio,
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
        initialSoundOffset: _soundStartOffset,
        initialMuteOriginal: _muteOriginalAudio,
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
        sound: result.sound ?? _selectedSound,
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
          : 'portrait';
      return MediaEditorSeed(
        arFilterId: arId,
        arColorCategoryId: category,
        arFilterIntensity: _arFilterIntensity,
        beautyEnabled: arId == 'whitening',
        alreadyBaked: true,
        effectSlug: ArFilterCatalog.isColorFilter(arId) || arId == 'none'
            ? null
            : arId,
      );
    }
    return MediaEditorSeed(
      filterName: _activeFilterName,
      effectSlug: _selectedEffectSlug,
      beautyEnabled: _beautyEnabled,
      filterCategory: _filterCategory,
    );
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
    final edited = await MediaGalleryImportFlow.openBatchEditor(
      context,
      items: [GalleryMediaItem(file: file, type: type)],
      isStory: widget.isStory,
      initialSound: _selectedSound,
      initialSoundOffset: _soundStartOffset,
      initialMuteOriginal: _muteOriginalAudio,
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
        'initialSound': edited.sound ?? _selectedSound,
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
      initialOffset: _soundStartOffset,
      initialWindow: _soundWindow,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedSound = picked.sound;
      _soundStartOffset = picked.offset;
      _soundWindow = picked.window > Duration.zero
          ? picked.window
          : const Duration(seconds: 15);
      _muteOriginalAudio = picked.muteOriginal;
    });
    // Preview only inside the picker/trim sheets — stop once the user continues.
    await SoundAudioPreview.stop();
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
  /// duration selected in the video mode bar.
  int get _effectiveMaxRecordSeconds =>
      _quickVideoMode ? _quickVideoMaxSeconds : _selectedDuration;

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
        if (!mounted) return;
        if (path != null && path.isNotEmpty) {
          if (_layoutMode != CameraLayoutMode.off) {
            setState(() => _isBusy = false);
            await _handleLayoutVideo(File(path));
            return;
          }
          _videoSegments.add(path);
          _segmentSpeeds.add(_currentSegmentSpeed);
        }
        setState(() => _isBusy = false);
        if (autoFinish && _videoSegments.isNotEmpty) {
          await _finishMultiClipVideo();
        }
      } catch (_) {
        if (mounted) setState(() => _isBusy = false);
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
    if (speed == _selectedSpeed) return;
    if (_isRecording &&
        _layoutMode == CameraLayoutMode.off &&
        !_quickVideoMode) {
      unawaited(_splitSegmentForSpeedChange(speed));
    } else {
      setState(() => _selectedSpeed = speed);
    }
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
      filtersPanelOpen: _showFilters,
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

    // Instant feedback — capture work continues in parallel feel.
    unawaited(_playShutterFlash());

    if (_useNativeArFilters) {
      _isCapturingPhoto = true;
      try {
        if (_ratioLetterboxed) {
          await _syncNativePreviewLetterbox(letterboxed: true);
        }
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
                          filtersPanelOpen: _showFilters,
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
    if (_recordSeconds >= _selectedDuration) return;

    if (_useNativeArFilters) {
      setState(() => _isBusy = true);
      try {
        // Native AR records mic in parallel — ensure permission every time.
        await CameraStudioPermissions.ensureMicrophone();
        if (_ratioLetterboxed) {
          await _syncNativePreviewLetterbox(letterboxed: true);
        }
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
                          filtersPanelOpen: _showFilters,
                        ) *
                        dpr)
                    .round()
              : 0,
        );
        if (!mounted) return;
        setState(() => _isBusy = false);
        _startRecordTimer(resume: _shouldResumeRecordTimer);
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
        _startRecordTimer(resume: _shouldResumeRecordTimer);
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
      final next = (current + 1).clamp(
        0,
        ArFilterCatalog.effectItems.length - 1,
      );
      _onArFilterSelected(
        ArFilterCatalog.indexOfId(ArFilterCatalog.effectItems[next].id),
      );
    } else if (velocity > 80 || _arSwipeDrag > 36) {
      final prev = (current - 1).clamp(
        0,
        ArFilterCatalog.effectItems.length - 1,
      );
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
        if (_layoutPickerOpen) {
          setState(() => _layoutPickerOpen = false);
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
    _onArPreviewSwipeEnd(
      DragEndDetails(
        velocity: details.velocity,
        primaryVelocity: details.velocity.pixelsPerSecond.dx,
      ),
    );
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
          _selectedZoom = CameraStudioConstants.zoomSteps[1].value;
        });
        _faceDetectorService.isFrontCamera = isFront;
        unawaited(_applyZoom(_selectedZoom, force: true));
      } catch (_) {}
      return;
    }
    await _cameraState?.switchCameraSensor();
    if (mounted) {
      setState(() {
        _isFrontCamera = !_isFrontCamera;
        _selectedZoom = CameraStudioConstants.zoomSteps[1].value;
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
  }

  void _toggleLayoutPicker() {
    setState(() {
      _layoutPickerOpen = !_layoutPickerOpen;
    });
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
      filtersPanelOpen: _showFilters,
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
      _layoutPickerOpen = false;
      if (mode == CameraLayoutMode.off) return;
      // Live has no grid capture — fall back to photo. Photo/video keep mode.
      if (_studioMode == CameraStudioMode.live) {
        _studioMode = CameraStudioMode.photo;
      }
      _layoutActiveCell = 0;
      _layoutCellPhotos = List<String?>.filled(mode.cellCount, null);
      _recordSeconds = 0;
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

    final index = _layoutActiveCell.clamp(0, mode.cellCount - 1);
    final next = List<String?>.from(_layoutCellPhotos);
    if (next.length != mode.cellCount) {
      next
        ..clear()
        ..addAll(List<String?>.filled(mode.cellCount, null));
    }
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
      _layoutActiveCell = next.indexWhere((p) => p == null);
      _recordSeconds = 0;
    });
  }

  /// Removes the captured media from [index] so the user can re-shoot that
  /// frame. Only valid while the grid is still being filled.
  void _deleteLayoutCell(int index) {
    if (_layoutMode == CameraLayoutMode.off) return;
    if (index < 0 || index >= _layoutCellPhotos.length) return;
    final next = List<String?>.from(_layoutCellPhotos);
    final path = next[index];
    if (path == null) return;
    next[index] = null;
    try {
      File(path).deleteSync();
    } catch (_) {}
    setState(() {
      _layoutCellPhotos = next;
      // Shoot the freed frame next.
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
      if (_recordSeconds >= _selectedDuration) return;
      _startRecordingWithOptionalTimer();
    }
  }

  void _onRecordHoldStart() {
    if (_studioMode == CameraStudioMode.live) return;
    if (_countdownValue != null) return;
    if (_isBusy || _isRecording) return;

    if (_studioMode == CameraStudioMode.photo) {
      // Photo mode: press-and-hold records a TikTok-style quick video
      // (auto-stops at 15s, releasing early stops sooner). Skip while a
      // layout grid is active — that flow captures per-cell clips itself.
      if (_layoutMode != CameraLayoutMode.off) return;
      _quickVideoMode = true;
      unawaited(_beginVideoRecording());
      return;
    }

    if (_recordSeconds >= _selectedDuration) return;
    _startRecordingWithOptionalTimer();
  }

  void _onRecordHoldEnd() {
    if (_studioMode == CameraStudioMode.live) return;

    // Photo-mode quick video: releasing finishes and opens the editor.
    if (_quickVideoMode) {
      unawaited(_finishQuickVideo());
      return;
    }

    if (_studioMode == CameraStudioMode.photo) return;
    // Timed countdown keeps running after release (step-back selfie).
    if (_countdownValue != null) return;
    if (_isRecording) {
      unawaited(_pauseRecordingSegment());
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
          if (_showShutterFlash)
            const IgnorePointer(child: ColoredBox(color: Color(0xE6FFFFFF))),
          if (_isProcessingCapture)
            CameraAppLoading(message: l10n.promoteProcessing),
          if (_isBusy && !_isProcessingCapture)
            CameraAppLoading(message: l10n.cameraStarting),
        ],
      ),
    );
  }

  Widget _buildNativeArPreviewHost() {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screen = Size(constraints.maxWidth, constraints.maxHeight);
          final Rect frame;
          if (_layoutMode == CameraLayoutMode.off) {
            frame = Offset.zero & screen;
          } else {
            final mode = _layoutMode;
            final last = mode.cellCount - 1;
            final active = last < 0
                ? 0
                : (_layoutActiveCell < 0
                      ? 0
                      : (_layoutActiveCell > last ? last : _layoutActiveCell));
            final cell = mode.cellRect(screen, active);
            frame = CameraLayoutComposer.previewFrameForCell(
              screen: screen,
              cell: cell,
            );
          }
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: frame.left,
                top: frame.top,
                width: frame.width,
                height: frame.height,
                child: ArCameraPreview(key: _arPreviewKey),
              ),
            ],
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
          beautyEnabled:
              _beautyEnabled ||
              ArFilterCatalog.items[_arFilterIndex].id == 'whitening',
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
          onGoLiveTap: () =>
              CameraStudioSheets.showLiveSetup(context, l10n: l10n),
          onRecordTap: _onRecordTap,
          onFlip: _flipCamera,
          onFlash: _toggleFlash,
          onSpeedTap: () => CameraStudioSheets.showSpeedPicker(
            context,
            selectedSpeed: _selectedSpeed,
            onSelected: _onSpeedSelected,
          ),
          onBeautyTap: () {
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
            if (_ratioLetterboxed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(_syncNativePreviewLetterbox());
              });
            }
            if (next) {
              unawaited(ArCameraBridge.prepareShaderPipeline());
            }
          },
          onTimerToggle: _openCountdownSheet,
          onMusicTap: _pickSound,
          onLayoutTap: _toggleLayoutPicker,
          onAspectRatioTap: _toggleRatioLetterbox,
          onTextModeTap: () => _showComingSoon(l10n.cameraLiveComingSoon),
          ratioLetterboxed: _ratioLetterboxed,
          selectedLayoutMode: _layoutMode,
          layoutPickerOpen: _layoutPickerOpen,
          onLayoutModeSelected: _onLayoutModeSelected,
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
                beautyEnabled: _beautyEnabled,
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
                onGoLiveTap: () =>
                    CameraStudioSheets.showLiveSetup(context, l10n: l10n),
                onRecordTap: _onRecordTap,
                onFlip: _flipCamera,
                onFlash: _toggleFlash,
                onSpeedTap: () => CameraStudioSheets.showSpeedPicker(
                  context,
                  selectedSpeed: _selectedSpeed,
                  onSelected: _onSpeedSelected,
                ),
                onBeautyTap: () => _applyBeauty(!_beautyEnabled),
                onFiltersToggle: () =>
                    setState(() => _showFilters = !_showFilters),
                onTimerToggle: _openCountdownSheet,
                onMusicTap: _pickSound,
                onLayoutTap: _toggleLayoutPicker,
                onAspectRatioTap: _toggleRatioLetterbox,
                onTextModeTap: () => _showComingSoon(l10n.cameraLiveComingSoon),
                ratioLetterboxed: _ratioLetterboxed,
                selectedLayoutMode: _layoutMode,
                layoutPickerOpen: _layoutPickerOpen,
                onLayoutModeSelected: _onLayoutModeSelected,
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
