import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/home/presentation/utils/media_gallery_import_flow.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_camera_editor.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_app_loading.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_compositor.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_compositor.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detector_service.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_sheets.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddPostCameraScreen extends StatefulWidget {
  const AddPostCameraScreen({
    super.key,
    this.isStory = false,
    this.initialSound,
    this.returnMediaOnDone = false,
  });

  final bool isStory;
  final SoundEntity? initialSound;
  final bool returnMediaOnDone;

  @override
  State<AddPostCameraScreen> createState() => _AddPostCameraScreenState();
}

class _AddPostCameraScreenState extends State<AddPostCameraScreen> {
  CameraState? _cameraState;
  bool _pendingVideoStart = false;
  bool _returnToPhotoAfterVideo = false;
  bool _showFilters = true;
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
  AwesomeFilter _selectedFilter = AwesomeFilter.None;
  double _selectedZoom = CameraStudioConstants.zoomSteps[1].value;
  int _selectedDuration = CameraStudioConstants.durationOptions.first;
  double _selectedSpeed = CameraStudioConstants.speedOptions[1];
  CameraEffectId? _selectedEffect;
  CameraStudioMode _studioMode = CameraStudioMode.video;
  SoundEntity? _selectedSound;
  File? _storyCapturedFile;
  String? _storyCapturedType;
  late final CameraFaceDetectorService _faceDetectorService;

  @override
  void initState() {
    super.initState();
    _selectedSound = widget.initialSound;
    if (widget.isStory) {
      _selectedDuration = CameraStudioConstants.durationOptions.first;
      _studioMode = CameraStudioMode.photo;
    }
    _faceDetectorService = CameraFaceDetectorService();
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

  void _returnPickedMedia(List<File> files) {
    if (files.isEmpty) return;
    context.pop(
      CameraMediaPickResult(
        files: files,
        type: MediaGalleryImportFlow.resolvePostType(files),
      ),
    );
  }

  MediaEditorSeed get _captureEditSeed => MediaEditorSeed(
    filterName: _selectedFilter.name,
    effect: _selectedEffect,
    beautyEnabled: _beautyEnabled,
    filterCategory: _filterCategory,
  );

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
    if (!mounted || edited == null || edited.isEmpty) return;

    if (widget.returnMediaOnDone) {
      _returnPickedMedia(edited);
      return;
    }

    context.pushReplacementNamed(
      'add_post',
      extra: {
        'files': edited,
        'type': MediaGalleryImportFlow.resolvePostType(edited),
        'isStory': false,
        'initialSound': _selectedSound,
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
        _selectedEffect != null && _selectedEffect != CameraEffectId.none;
    var file = File(path);
    final isVideo = capture.isVideo;

    if (widget.isStory && (hasFilter || hasEffect)) {
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
            effectId: _selectedEffect,
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

    if (widget.isStory) {
      setState(() {
        _storyCapturedFile = file;
        _storyCapturedType = capture.isPicture ? 'IMAGE' : 'VIDEO';
      });
      return;
    }

    if (capture.isPicture) {
      await _openCapturedMediaEditor(file, type: 'IMAGE');
      return;
    }

    final type = 'VIDEO';
    if (widget.returnMediaOnDone) {
      _returnPickedMedia([file]);
      return;
    }

    context.pushReplacementNamed(
      'add_post',
      extra: {
        'files': [file],
        'type': type,
        'isStory': false,
        'initialSound': _selectedSound,
      },
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
          await videoState.startRecording();
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

    final state = _cameraState;
    if (state == null) return;

    await state.when(
      onPhotoMode: (photoState) async {
        _returnToPhotoAfterVideo = true;
        _pendingVideoStart = true;
        photoState.setState(CaptureMode.video);
      },
      onVideoMode: (videoState) async {
        await videoState.startRecording();
        _startRecordTimer();
      },
      onVideoRecordingMode: (_) async {},
      onPreparingCamera: (_) async {},
      onPreviewMode: (_) async {},
      onAnalysisOnlyMode: (_) async {},
    );
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
    await _cameraState?.setFilter(preset.filter);
  }

  Future<void> _applyBeauty(bool enabled) async {
    setState(() => _beautyEnabled = enabled);
    final state = _cameraState;
    if (state == null) return;

    if (enabled) {
      state.sensorConfig.setBrightness(0.35);
      if (_selectedFilter == AwesomeFilter.None) {
        await state.setFilter(CameraFilterCatalog.beautyFilter.filter);
      }
    } else {
      state.sensorConfig.setBrightness(0.0);
      if (_selectedFilter == AwesomeFilter.None) {
        await state.setFilter(AwesomeFilter.None);
      }
    }
  }

  Future<void> _applyZoom(double zoom) async {
    final state = _cameraState;
    if (state == null) return;
    await state.sensorConfig.setZoom(zoom.clamp(0.0, 1.0));
    if (mounted) setState(() => _selectedZoom = zoom);
  }

  Future<void> _flipCamera() async {
    await _cameraState?.switchCameraSensor();
  }

  void _toggleFlash() {
    _cameraState?.sensorConfig.switchCameraFlash();
  }

  String _filterLabel(AppLocalizations l10n, CameraFilterPreset preset) {
    return preset.label(originalLabel: l10n.cameraFilterOriginal);
  }

  String _categoryLabel(AppLocalizations l10n, CameraFilterCategory category) {
    return switch (category) {
      CameraFilterCategory.trending => l10n.cameraCategoryTrending,
      CameraFilterCategory.newFilters => l10n.cameraCategoryNew,
      CameraFilterCategory.portrait => l10n.cameraCategoryPortrait,
      CameraFilterCategory.vibe => l10n.cameraCategoryVibe,
      CameraFilterCategory.landscape => l10n.cameraCategoryLandscape,
    };
  }

  String _studioModeLabel(AppLocalizations l10n, CameraStudioMode mode) {
    return switch (mode) {
      CameraStudioMode.photo => l10n.cameraModePhoto,
      CameraStudioMode.video => l10n.cameraModeVideo,
      CameraStudioMode.live => l10n.cameraModeLive,
    };
  }

  void _onStudioModeSelected(CameraStudioMode mode) {
    if (_isRecording) return;
    if (widget.isStory && mode == CameraStudioMode.live) return;

    setState(() => _studioMode = mode);

    _cameraState?.when(
      onPhotoMode: (state) {
        if (mode == CameraStudioMode.video) {
          state.setState(CaptureMode.video);
        }
      },
      onVideoMode: (state) {
        if (mode == CameraStudioMode.photo) {
          state.setState(CaptureMode.photo);
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

    final filters = CameraFilterCatalog.forCategory(_filterCategory);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraAwesomeBuilder.custom(
            saveConfig: SaveConfig.photoAndVideo(
              initialCaptureMode: CaptureMode.photo,
            ),
            sensorConfig: SensorConfig.single(
              sensor: Sensor.position(SensorPosition.back),
              flashMode: FlashMode.none,
              zoom: _selectedZoom,
              aspectRatio: CameraAspectRatios.ratio_16_9,
            ),
            filter: _selectedFilter,
            filters: CameraFilterCatalog.allGpuFilters,
            previewFit: CameraPreviewFit.cover,
            onMediaCaptureEvent: _onMediaCapture,
            onImageForAnalysis: _onImageForAnalysis,
            imageAnalysisConfig: AnalysisConfig(
              androidOptions: const AndroidAnalysisOptions.nv21(width: 250),
              maxFramesPerSecond: 8,
            ),
            progressIndicator: CameraAppLoading(message: l10n.cameraStarting),
            builder: (state, preview) {
              _cameraState = state;
              _handlePendingVideoStart(state);

              return CameraStudioOverlay(
                l10n: l10n,
                isStoryMode: widget.isStory,
                showGalleryUpload: !widget.returnMediaOnDone,
                cameraState: state,
                preview: preview,
                faceStream: _faceDetectorService.stream,
                filters: filters,
                filterCategory: _filterCategory,
                selectedFilter: _selectedFilter,
                selectedZoom: _selectedZoom,
                selectedDuration: _selectedDuration,
                selectedSpeed: _selectedSpeed,
                studioMode: _studioMode,
                showFilters: _showFilters,
                beautyEnabled: _beautyEnabled,
                timerEnabled: _timerEnabled,
                isRecording: _isRecording,
                isBusy: _isBusy || _isProcessingCapture,
                recordSeconds: _recordSeconds,
                countdownValue: _countdownValue,
                selectedEffect: _selectedEffect,
                onClose: () => context.pop(),
                onDurationTap: () => CameraStudioSheets.showDurationPicker(
                  context,
                  l10n: l10n,
                  selectedDuration: _selectedDuration,
                  onSelected: (seconds) =>
                      setState(() => _selectedDuration = seconds),
                ),
                onFilterCategorySelected: (category) =>
                    setState(() => _filterCategory = category),
                onFilterSelected: _applyFilter,
                onZoomSelected: _applyZoom,
                onStudioModeSelected: _onStudioModeSelected,
                onEffectsTap: () => CameraStudioSheets.showEffectsPicker(
                  context,
                  l10n: l10n,
                  selectedEffect: _selectedEffect,
                  onSelected: (effect) =>
                      setState(() => _selectedEffect = effect),
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
                onFiltersToggle: () =>
                    setState(() => _showFilters = !_showFilters),
                onTimerToggle: () =>
                    setState(() => _timerEnabled = !_timerEnabled),
                onMusicTap: _pickSound,
                soundLabel: _studioMode == CameraStudioMode.live
                    ? l10n.cameraLiveTitleHint
                    : (_selectedSound?.name ?? l10n.cameraOriginalSound),
                onLongPressStart: (_) => _startRecordingWithOptionalTimer(),
                onLongPressEnd: (_) {
                  if (_isRecording) _stopRecording();
                },
                filterCategoryLabelBuilder: (category) =>
                    _categoryLabel(l10n, category),
                filterLabelBuilder: (preset) => _filterLabel(l10n, preset),
                studioModeLabelBuilder: (mode) => _studioModeLabel(l10n, mode),
              );
            },
          ),
          if (_isProcessingCapture)
            CameraAppLoading(message: l10n.promoteProcessing),
          if (_isBusy && !_isProcessingCapture)
            CameraAppLoading(message: l10n.cameraStarting),
        ],
      ),
    );
  }

  Future<void> _onImageForAnalysis(AnalysisImage image) async {
    if (!CameraEffectsCatalog.needsFaceDetection(_selectedEffect)) return;
    await _faceDetectorService.analyze(image);
  }
}
