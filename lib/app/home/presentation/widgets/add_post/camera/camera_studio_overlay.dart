import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_ar_effects_layer.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_bottom_controls.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detector_service.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_strip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_overlays.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_side_toolbar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_top_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_zoom_selector.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

class CameraStudioOverlay extends StatelessWidget {
  const CameraStudioOverlay({
    super.key,
    required this.l10n,
    required this.filters,
    required this.filterCategory,
    required this.selectedFilter,
    required this.selectedZoom,
    required this.selectedDuration,
    required this.selectedSpeed,
    required this.studioMode,
    required this.showFilters,
    required this.beautyEnabled,
    required this.timerEnabled,
    required this.isRecording,
    required this.isBusy,
    required this.recordSeconds,
    required this.countdownValue,
    required this.cameraState,
    required this.preview,
    required this.faceStream,
    required this.selectedEffect,
    required this.onClose,
    required this.onDurationTap,
    required this.onFilterCategorySelected,
    required this.onFilterSelected,
    required this.onZoomSelected,
    required this.onStudioModeSelected,
    required this.onEffectsTap,
    required this.onUploadTap,
    required this.onGoLiveTap,
    required this.onRecordTap,
    required this.onFlip,
    required this.onFlash,
    required this.onSpeedTap,
    required this.onBeautyTap,
    required this.onFiltersToggle,
    required this.onTimerToggle,
    required this.onMusicTap,
    this.soundLabel,
    this.onLongPressStart,
    this.onLongPressEnd,
    required this.filterCategoryLabelBuilder,
    required this.filterLabelBuilder,
    required this.studioModeLabelBuilder,
  });

  final AppLocalizations l10n;
  final List<CameraFilterPreset> filters;
  final CameraFilterCategory filterCategory;
  final AwesomeFilter selectedFilter;
  final double selectedZoom;
  final int selectedDuration;
  final double selectedSpeed;
  final CameraStudioMode studioMode;
  final bool showFilters;
  final bool beautyEnabled;
  final bool timerEnabled;
  final bool isRecording;
  final bool isBusy;
  final int recordSeconds;
  final int? countdownValue;
  final CameraState cameraState;
  final AnalysisPreview preview;
  final Stream<CameraFaceDetectionFrame> faceStream;
  final CameraEffectId? selectedEffect;
  final VoidCallback onClose;
  final VoidCallback onDurationTap;
  final ValueChanged<CameraFilterCategory> onFilterCategorySelected;
  final ValueChanged<CameraFilterPreset> onFilterSelected;
  final ValueChanged<double> onZoomSelected;
  final ValueChanged<CameraStudioMode> onStudioModeSelected;
  final VoidCallback onEffectsTap;
  final VoidCallback onUploadTap;
  final VoidCallback onGoLiveTap;
  final VoidCallback onRecordTap;
  final VoidCallback onFlip;
  final VoidCallback onFlash;
  final VoidCallback onSpeedTap;
  final VoidCallback onBeautyTap;
  final VoidCallback onFiltersToggle;
  final VoidCallback onTimerToggle;
  final VoidCallback onMusicTap;
  final String? soundLabel;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final String Function(CameraFilterCategory category)
  filterCategoryLabelBuilder;
  final String Function(CameraFilterPreset preset) filterLabelBuilder;
  final String Function(CameraStudioMode mode) studioModeLabelBuilder;

  bool get isLiveMode => studioMode == CameraStudioMode.live;
  bool get isPhotoMode => studioMode == CameraStudioMode.photo;
  bool get isVideoMode => studioMode == CameraStudioMode.video;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final activeEffect = CameraEffectsCatalog.byId(selectedEffect);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (activeEffect != null && activeEffect.requiresFaceDetection)
          CameraArEffectsLayer(
            cameraState: cameraState,
            preview: preview,
            faceStream: faceStream,
            effect: activeEffect,
          ),
        if (activeEffect != null && activeEffect.isScreenEffect)
          CameraScreenEffectsLayer(effect: activeEffect),
        if (countdownValue != null)
          CameraCountdownOverlay(value: countdownValue!),
        SafeArea(
          child: Column(
            children: [
              CameraTopBar(
                onClose: onClose,
                durationLabel: '${selectedDuration}s',
                onDurationTap: onDurationTap,
                soundLabel: soundLabel ?? l10n.cameraOriginalSound,
                onSoundTap: onMusicTap,
                showDuration: isVideoMode,
                isLiveMode: isLiveMode,
              ),
              const Spacer(),
              if (showFilters && !isLiveMode) ...[
                CameraFilterCategoryTabs(
                  selected: filterCategory,
                  labelBuilder: filterCategoryLabelBuilder,
                  onSelected: onFilterCategorySelected,
                ),
                const SizedBox(height: 10),
                CameraFilterStrip(
                  presets: filters,
                  selected: selectedFilter,
                  labelBuilder: filterLabelBuilder,
                  onSelected: onFilterSelected,
                ),
                const SizedBox(height: 12),
              ],
              CameraZoomSelector(
                steps: CameraStudioConstants.zoomSteps,
                selected: selectedZoom,
                onSelected: onZoomSelected,
              ),
              const SizedBox(height: 16),
              CameraCaptureControls(
                isLiveMode: isLiveMode,
                isPhotoMode: isPhotoMode,
                isRecording: isRecording,
                isBusy: isBusy,
                recordProgress: selectedDuration == 0
                    ? 0
                    : recordSeconds / selectedDuration,
                effectsLabel: l10n.cameraEffects,
                uploadLabel: l10n.cameraUpload,
                goLiveLabel: l10n.cameraGoLive,
                onEffectsTap: onEffectsTap,
                onUploadTap: onUploadTap,
                onGoLiveTap: onGoLiveTap,
                onRecordTap: onRecordTap,
                onLongPressStart: onLongPressStart,
                onLongPressEnd: onLongPressEnd,
              ),
              const SizedBox(height: 8),
              CameraModeSelector(
                modes: CameraStudioConstants.studioModes,
                selected: studioMode,
                labelBuilder: studioModeLabelBuilder,
                onSelected: onStudioModeSelected,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Positioned(
          right: 12,
          top: topPadding + 72,
          child: CameraSideToolbar(
            onFlip: onFlip,
            onFlash: onFlash,
            onSpeed: onSpeedTap,
            onBeauty: onBeautyTap,
            onFilters: onFiltersToggle,
            onTimer: onTimerToggle,
            onMusic: onMusicTap,
            beautyEnabled: beautyEnabled,
            filtersEnabled: showFilters,
            timerEnabled: timerEnabled,
            speedLabel: '${selectedSpeed}x',
            labels: CameraSideToolbarLabels(
              flip: l10n.cameraFlip,
              flash: l10n.cameraFlash,
              speed: l10n.cameraSpeed,
              beauty: l10n.cameraBeauty,
              filters: l10n.cameraFilters,
              timer: l10n.cameraTimer,
              music: l10n.cameraMusic,
            ),
          ),
        ),
        if (isRecording)
          CameraRecordingBadge(
            topPadding: topPadding,
            label: '${l10n.cameraRecording} ${recordSeconds}s',
          ),
      ],
    );
  }
}
