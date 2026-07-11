import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_ar_effects_layer.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_bottom_controls.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detector_service.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filters_panel.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_overlays.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_side_toolbar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_top_bar.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

class CameraStudioOverlay extends StatelessWidget {
  const CameraStudioOverlay({
    super.key,
    required this.l10n,
    required this.filters,
    required this.filterCategorySlug,
    required this.selectedFilter,
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
    required this.selectedEffectSlug,
    required this.onClose,
    required this.onFilterCategorySelected,
    required this.onFilterSelected,
    required this.onClearFilter,
    required this.onDurationSelected,
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
    required this.onLayoutTap,
    required this.onAspectRatioTap,
    required this.onZoomTap,
    required this.onTextModeTap,
    required this.onWorkspaceTabSelected,
    required this.workspaceTabIndex,
    this.soundLabel,
    this.isStoryMode = false,
    this.showGalleryUpload = true,
    this.onLongPressStart,
    this.onLongPressEnd,
    required this.filterLabelBuilder,
  });

  final AppLocalizations l10n;
  final List<CameraFilterPreset> filters;
  final String filterCategorySlug;
  final AwesomeFilter selectedFilter;
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
  final String? selectedEffectSlug;
  final VoidCallback onClose;
  final ValueChanged<String> onFilterCategorySelected;
  final ValueChanged<CameraFilterPreset> onFilterSelected;
  final VoidCallback onClearFilter;
  final ValueChanged<int> onDurationSelected;
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
  final VoidCallback onLayoutTap;
  final VoidCallback onAspectRatioTap;
  final VoidCallback onZoomTap;
  final VoidCallback onTextModeTap;
  final ValueChanged<int> onWorkspaceTabSelected;
  final int workspaceTabIndex;
  final String? soundLabel;
  final bool isStoryMode;
  final bool showGalleryUpload;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final String Function(CameraFilterPreset preset) filterLabelBuilder;

  bool get isLiveMode => studioMode == CameraStudioMode.live;
  bool get isPhotoMode => studioMode == CameraStudioMode.photo;
  bool get isVideoMode => studioMode == CameraStudioMode.video;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final activeEffect = CameraEffectsCatalog.bySlug(selectedEffectSlug);

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
                onFlip: onFlip,
                onClose: onClose,
                soundLabel: soundLabel ?? l10n.cameraOriginalSound,
                addSoundLabel: l10n.cameraAddSound,
                onSoundTap: onMusicTap,
                isLiveMode: isLiveMode,
              ),
              const Spacer(),
              if (!showFilters) ...[
                if (!isLiveMode)
                  CameraModeDurationBar(
                    studioMode: studioMode,
                    selectedDuration: selectedDuration,
                    photoLabel: l10n.cameraModePhoto,
                    textLabel: l10n.cameraModeText,
                    liveLabel: l10n.cameraModeLive,
                    duration10mLabel: l10n.cameraDuration10m,
                    showLive: !isStoryMode,
                    showText: !isStoryMode,
                    onPhotoSelected: () =>
                        onStudioModeSelected(CameraStudioMode.photo),
                    onDurationSelected: (seconds) {
                      onDurationSelected(seconds);
                      onStudioModeSelected(CameraStudioMode.video);
                    },
                    onLiveSelected: () =>
                        onStudioModeSelected(CameraStudioMode.live),
                    onTextSelected: onTextModeTap,
                  ),
                const SizedBox(height: 10),
                CameraCaptureControls(
                  isLiveMode: isLiveMode,
                  isPhotoMode: isPhotoMode,
                  isRecording: isRecording,
                  isBusy: isBusy,
                  recordProgress: selectedDuration == 0
                      ? 0
                      : recordSeconds / selectedDuration,
                  effectsLabel: l10n.cameraEffects,
                  uploadLabel: isStoryMode
                      ? l10n.importFromLibrary
                      : l10n.uploadFromLibrary,
                  goLiveLabel: l10n.cameraGoLive,
                  selectedEffect: activeEffect,
                  onEffectsTap: onEffectsTap,
                  onUploadTap: onUploadTap,
                  onGoLiveTap: onGoLiveTap,
                  onRecordTap: onRecordTap,
                  showUpload: showGalleryUpload,
                  onLongPressStart: onLongPressStart,
                  onLongPressEnd: onLongPressEnd,
                ),
                const SizedBox(height: 6),
                CameraWorkspaceTabs(
                  postLabel: l10n.cameraTabPost,
                  creativeLabel: l10n.cameraTabCreative,
                  selectedIndex: workspaceTabIndex,
                  onSelected: onWorkspaceTabSelected,
                ),
                const SizedBox(height: 6),
              ] else
                const SizedBox(height: 180),
            ],
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                left: isRtl ? 10 : 0,
                right: isRtl ? 0 : 10,
                top: topPadding + 52,
                bottom: showFilters ? 240 : 168,
              ),
              child: CameraSideToolbar(
                iconOnStartEdge: isRtl,
                onFlash: onFlash,
                onTimer: onTimerToggle,
                onLayout: onLayoutTap,
                onAspectRatio: onAspectRatioTap,
                onBeauty: onBeautyTap,
                onFilters: onFiltersToggle,
                onSpeed: onSpeedTap,
                onZoom: onZoomTap,
                beautyEnabled: beautyEnabled,
                filtersEnabled: showFilters,
                timerEnabled: timerEnabled,
                speedLabel: '${selectedSpeed}x',
                labels: CameraSideToolbarLabels(
                  flash: l10n.cameraFlash,
                  timer: l10n.cameraTimer,
                  layout: l10n.cameraLayout,
                  aspectRatio: l10n.cameraAspectRatio,
                  beauty: l10n.cameraBeauty,
                  filters: l10n.cameraFilters,
                  speed: l10n.cameraSpeed,
                  zoom: l10n.cameraZoom,
                ),
              ),
            ),
          ),
        ),
        if (showFilters && !isLiveMode) ...[
          Positioned.fill(
            child: CameraFiltersScrim(onDismiss: onFiltersToggle),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CameraFiltersPanel(
              categories: CameraFilterCatalog.filterCategories,
              selectedCategorySlug: filterCategorySlug,
              categoryLabelBuilder: (category) =>
                  CameraFilterCatalog.labelForCategory(l10n, category),
              onCategorySelected: onFilterCategorySelected,
              presets: filters,
              selectedFilter: selectedFilter,
              filterLabelBuilder: filterLabelBuilder,
              onFilterSelected: onFilterSelected,
              onClearFilter: onClearFilter,
            ),
          ),
        ],
        if (isRecording)
          CameraRecordingBadge(
            topPadding: topPadding,
            label: '${l10n.cameraRecording} ${recordSeconds}s',
          ),
      ],
    );
  }
}
