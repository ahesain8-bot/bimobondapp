import 'package:bimobondapp/app/ar_camera/ar_color_filters_panel.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_carousel.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_ar_effects_layer.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_bottom_controls.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detector_service.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filter_preset.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_filters_panel.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_layout_picker.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_layout_stage.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_overlays.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_side_toolbar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_tool_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_top_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_photo_editor_panel.dart';
import 'package:bimobondapp/app/home/presentation/utils/camera_capture_utils.dart';
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
    this.showPhotoEditor = false,
    required this.beautyEnabled,
    this.photoEditorTab = MediaPhotoEditorTab.face,
    this.photoEditorTool = MediaPhotoEditorTool.magic,
    this.photoEditorMagicOn = false,
    this.photoEditorAdjustments = const {},
    this.onPhotoEditorTabChanged,
    this.onPhotoEditorToolSelected,
    this.onPhotoEditorMagicToggled,
    this.onPhotoEditorAdjustmentChanged,
    this.onPhotoEditorReset,
    this.photoEditorColorFilterId = 'none',
    this.photoEditorColorFilterIntensity = 1.0,
    this.onPhotoEditorColorFilterSelected,
    this.onPhotoEditorColorFilterIntensityChanged,
    required this.timerEnabled,
    this.flashEnabled = false,
    required this.isRecording,
    required this.isBusy,
    required this.recordSeconds,
    required this.countdownValue,
    this.hasDraftClips = false,
    this.onFinishRecording,
    this.onDiscardDraft,
    this.cameraState,
    this.preview,
    this.faceStream,
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
    this.onClearSound,
    required this.onLayoutTap,
    required this.onAspectRatioTap,
    required this.onTextModeTap,
    required this.onWorkspaceTabSelected,
    required this.workspaceTabIndex,
    this.selectedLayoutMode = CameraLayoutMode.off,
    this.layoutPickerOpen = false,
    this.onLayoutModeSelected,
    this.speedPickerOpen = false,
    this.onSpeedSelected,
    this.onDismissToolPopups,
    this.layoutCellPhotos = const [],
    this.layoutActiveCellIndex = 0,
    this.onLayoutCellDelete,
    this.onLayoutCellDuplicate,
    this.onLayoutCellImport,
    this.ratioLetterboxed = false,
    this.soundLabel,
    this.isStoryMode = false,
    this.showGalleryUpload = true,
    this.onLongPressStart,
    this.onLongPressEnd,
    required this.filterLabelBuilder,
    this.useNativeArFilters = false,
    this.arFilterIndex = 0,
    this.onArFilterSelected,
    this.arColorCategoryId = 'beauty',
    this.onArColorCategorySelected,
    this.arFilterIntensity = 1.0,
    this.onArFilterIntensityChanged,
  });

  final AppLocalizations l10n;
  final List<CameraFilterPreset> filters;
  final String filterCategorySlug;
  final AwesomeFilter selectedFilter;
  final int selectedDuration;
  final double selectedSpeed;
  final CameraStudioMode studioMode;
  final bool showFilters;
  final bool showPhotoEditor;
  final bool beautyEnabled;
  final MediaPhotoEditorTab photoEditorTab;
  final MediaPhotoEditorTool photoEditorTool;
  final bool photoEditorMagicOn;
  final Map<MediaPhotoEditorTool, double> photoEditorAdjustments;
  final ValueChanged<MediaPhotoEditorTab>? onPhotoEditorTabChanged;
  final ValueChanged<MediaPhotoEditorTool>? onPhotoEditorToolSelected;
  final VoidCallback? onPhotoEditorMagicToggled;
  final void Function(MediaPhotoEditorTool tool, double value)?
      onPhotoEditorAdjustmentChanged;
  final VoidCallback? onPhotoEditorReset;
  final String photoEditorColorFilterId;
  final double photoEditorColorFilterIntensity;
  final ValueChanged<String>? onPhotoEditorColorFilterSelected;
  final ValueChanged<double>? onPhotoEditorColorFilterIntensityChanged;
  final bool timerEnabled;
  final bool flashEnabled;
  final bool isRecording;
  final bool isBusy;
  final int recordSeconds;
  final int? countdownValue;
  final bool hasDraftClips;
  final VoidCallback? onFinishRecording;
  final VoidCallback? onDiscardDraft;
  final CameraState? cameraState;
  final AnalysisPreview? preview;
  final Stream<CameraFaceDetectionFrame>? faceStream;
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
  final VoidCallback? onClearSound;
  final VoidCallback onLayoutTap;
  final VoidCallback onAspectRatioTap;
  final VoidCallback onTextModeTap;
  final ValueChanged<int> onWorkspaceTabSelected;
  final int workspaceTabIndex;
  final CameraLayoutMode selectedLayoutMode;
  final bool layoutPickerOpen;
  final ValueChanged<CameraLayoutMode>? onLayoutModeSelected;
  final bool speedPickerOpen;
  final ValueChanged<double>? onSpeedSelected;
  final VoidCallback? onDismissToolPopups;
  final List<String?> layoutCellPhotos;
  final int layoutActiveCellIndex;
  final ValueChanged<int>? onLayoutCellDelete;
  final ValueChanged<int>? onLayoutCellDuplicate;
  final ValueChanged<int>? onLayoutCellImport;
  final bool ratioLetterboxed;
  final String? soundLabel;
  final bool isStoryMode;
  final bool showGalleryUpload;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;
  final String Function(CameraFilterPreset preset) filterLabelBuilder;
  final bool useNativeArFilters;
  final int arFilterIndex;
  final ValueChanged<int>? onArFilterSelected;
  final String arColorCategoryId;
  final ValueChanged<String>? onArColorCategorySelected;
  final double arFilterIntensity;
  final ValueChanged<double>? onArFilterIntensityChanged;

  bool get isLiveMode => studioMode == CameraStudioMode.live;
  bool get isPhotoMode => studioMode == CameraStudioMode.photo;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final activeEffect = CameraEffectsCatalog.bySlug(selectedEffectSlug);
    final showLegacyFiltersPanel =
        showFilters && !useNativeArFilters && !isLiveMode;
    final showArColorFiltersPanel =
        showFilters && useNativeArFilters && !isLiveMode;
    final showRetouchPanel = showPhotoEditor && !isLiveMode;
    final showBottomSheet =
        showLegacyFiltersPanel || showArColorFiltersPanel || showRetouchPanel;
    final selectedArFilterId = ArFilterCatalog
        .items[arFilterIndex.clamp(0, ArFilterCatalog.items.length - 1)]
        .id;
    final hasActiveFilter = useNativeArFilters
        ? selectedArFilterId != 'none'
        : selectedFilter != AwesomeFilter.None;
    final showControls = countdownValue == null;
    final isReviewingDraft =
        hasDraftClips && !isRecording && onFinishRecording != null;

    final topChromeHeight = ratioLetterboxed
        ? CameraRatioLetterbox.topHeight(topPadding)
        : CameraRatioLetterbox.tikTokTopChromeHeight(
            topPadding,
            photoMode: isPhotoMode,
          );
    final bottomChromeHeight = ratioLetterboxed
        ? CameraRatioLetterbox.bottomHeight(
            useNativeAr: useNativeArFilters,
            filtersPanelOpen: showBottomSheet,
          )
        : CameraRatioLetterbox.tikTokBottomChromeHeight(
            MediaQuery.paddingOf(context).bottom,
            photoMode: isPhotoMode,
          );
    final controlsTop =
        CameraRatioLetterbox.tikTokTopChromeHeight(topPadding) + 16.0;
    final sideToolbarTop = controlsTop + 48.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (selectedLayoutMode != CameraLayoutMode.off)
          Positioned.fill(
            child: CameraLayoutStage(
              mode: selectedLayoutMode,
              cellPhotos: layoutCellPhotos,
              activeCellIndex: layoutActiveCellIndex,
              onDeleteCell: onLayoutCellDelete,
              onDuplicateCell: onLayoutCellDuplicate,
              onImportCell: onLayoutCellImport,
            ),
          ),
        TikTokChromeBarsOverlay(
          topHeight: topChromeHeight,
          bottomHeight: bottomChromeHeight,
        ),
        if (!useNativeArFilters &&
            activeEffect != null &&
            activeEffect.requiresFaceDetection &&
            cameraState != null &&
            preview != null &&
            faceStream != null)
          CameraArEffectsLayer(
            cameraState: cameraState!,
            preview: preview!,
            faceStream: faceStream!,
            effect: activeEffect,
          ),
        if (!useNativeArFilters &&
            activeEffect != null &&
            activeEffect.isScreenEffect)
          CameraScreenEffectsLayer(effect: activeEffect),
        if (countdownValue != null)
          CameraCountdownOverlay(value: countdownValue!),
        if (showControls)
          SafeArea(
            top: false,
            bottom: !(useNativeArFilters && !isLiveMode),
            child: Padding(
              padding: EdgeInsets.only(top: controlsTop),
              child: Column(
                children: [
                  CameraTopBar(
                    onClose: onClose,
                    soundLabel: soundLabel ?? l10n.cameraOriginalSound,
                    addSoundLabel: l10n.cameraAddSound,
                    onSoundTap: onMusicTap,
                    onClearSound: onClearSound,
                    isLiveMode: isLiveMode,
                    showSound: !isRecording,
                  ),
                  const Spacer(),
                if (!showLegacyFiltersPanel && !showRetouchPanel) ...[
                  if (!isLiveMode &&
                      !isRecording &&
                      !isReviewingDraft &&
                      selectedLayoutMode == CameraLayoutMode.off)
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
                  if (useNativeArFilters &&
                      !isLiveMode &&
                      onArFilterSelected != null &&
                      !showArColorFiltersPanel &&
                      !showRetouchPanel)
                    _BottomInsetPanel(
                      bottomInset: MediaQuery.paddingOf(context).bottom + 48,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isRecording)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                _formatRecordClock(recordSeconds),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Transform.translate(
                            offset: const Offset(0, -14),
                            child: ArFilterCarousel(
                              items: ArFilterCatalog.effectItems,
                              selectedIndex:
                                  ArFilterCatalog.effectCarouselIndex(
                                selectedArFilterId,
                              ),
                              onSelected: (index) {
                                final id =
                                    ArFilterCatalog.effectItems[index].id;
                                onArFilterSelected!(
                                  ArFilterCatalog.indexOfId(id),
                                );
                              },
                              isRecording: isRecording,
                              isBusy: isBusy,
                              recordProgress: selectedDuration == 0
                                  ? 0
                                  : recordSeconds / selectedDuration,
                              isPhotoMode: isPhotoMode,
                              onShutterTap: onRecordTap,
                              onHoldStart: onLongPressStart,
                              onHoldEnd: onLongPressEnd,
                              showSideActions: isReviewingDraft ||
                                  (isRecording && recordSeconds >= 1),
                              soloShutter: isRecording ||
                                  isReviewingDraft ||
                                  selectedLayoutMode != CameraLayoutMode.off,
                              onCancel: onDiscardDraft,
                              onConfirm: onFinishRecording,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 44,
                            child: (isRecording || isReviewingDraft)
                                ? null
                                : selectedLayoutMode == CameraLayoutMode.off
                                    ? _BottomWorkspaceRow(
                                        showGallery: showGalleryUpload,
                                        onUploadTap: onUploadTap,
                                        uploadLabel: isStoryMode
                                            ? l10n.importFromLibrary
                                            : l10n.uploadFromLibrary,
                                        postLabel: l10n.cameraTabPost,
                                        creativeLabel: l10n.cameraTabCreative,
                                        workspaceTabIndex: workspaceTabIndex,
                                        onWorkspaceTabSelected:
                                            onWorkspaceTabSelected,
                                      )
                                    : showGalleryUpload
                                        ? Align(
                                            alignment:
                                                AlignmentDirectional.centerStart,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .only(start: 16),
                                              child: GestureDetector(
                                                onTap: onUploadTap,
                                                child: Icon(
                                                  Icons
                                                      .photo_library_outlined,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                          )
                                        : null,
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    )
                  else if (!useNativeArFilters || isLiveMode) ...[
                    if (!isLiveMode) ...[
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
                        showEffectsTool: true,
                        onLongPressStart: onLongPressStart,
                        onLongPressEnd: onLongPressEnd,
                      ),
                      if (isReviewingDraft)
                        _ReviewActionsRow(
                          cancelLabel: l10n.cancel,
                          nextLabel: l10n.nextAction,
                          onCancel: onDiscardDraft,
                          onNext: onFinishRecording!,
                        ),
                    ],
                    if (isLiveMode) ...[
                      const SizedBox(height: 10),
                      CameraCaptureControls(
                        isLiveMode: true,
                        isPhotoMode: false,
                        isRecording: false,
                        isBusy: isBusy,
                        recordProgress: 0,
                        effectsLabel: l10n.cameraEffects,
                        uploadLabel: l10n.uploadFromLibrary,
                        goLiveLabel: l10n.cameraGoLive,
                        onEffectsTap: onEffectsTap,
                        onUploadTap: onUploadTap,
                        onGoLiveTap: onGoLiveTap,
                        onRecordTap: onRecordTap,
                        showUpload: false,
                        showEffectsTool: false,
                      ),
                    ],
                    if (!isReviewingDraft) ...[
                      const SizedBox(height: 10),
                      CameraWorkspaceTabs(
                        postLabel: l10n.cameraTabPost,
                        creativeLabel: l10n.cameraTabCreative,
                        selectedIndex: workspaceTabIndex,
                        onSelected: onWorkspaceTabSelected,
                      ),
                      SizedBox(
                        height: 10 + MediaQuery.paddingOf(context).bottom,
                      ),
                    ],
                  ],
                ] else
                  const SizedBox(height: 180),
              ],
            ),
            ),
          ),
        if (showControls &&
            !isRecording &&
            !isReviewingDraft &&
            (layoutPickerOpen || speedPickerOpen) &&
            onDismissToolPopups != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismissToolPopups,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
        if (showControls && !isRecording && !isReviewingDraft)
          Positioned.fill(
            child: Align(
              alignment: isRtl ? Alignment.topLeft : Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(
                  left: isRtl ? 10 : 0,
                  right: isRtl ? 0 : 10,
                  top: sideToolbarTop,
                  bottom: showBottomSheet
                      ? 220
                      : (useNativeArFilters ? 228 : 168),
                ),
                child: CameraSideToolbar(
                  iconOnStartEdge: isRtl,
                  showFlip: true,
                  onFlip: onFlip,
                  onFlash: onFlash,
                  onTimer: onTimerToggle,
                  onLayout: onLayoutTap,
                  onAspectRatio: onAspectRatioTap,
                  onBeauty: onBeautyTap,
                  onFilters: onFiltersToggle,
                  onSpeed: onSpeedTap,
                  flashEnabled: flashEnabled,
                  beautyEnabled: beautyEnabled || showRetouchPanel,
                  filtersEnabled: showFilters || hasActiveFilter,
                  timerEnabled: timerEnabled,
                  speedLabel: '${selectedSpeed}x',
                  showSpeed: studioMode == CameraStudioMode.video,
                  speedEnabled: selectedLayoutMode == CameraLayoutMode.off,
                  showAspectRatio: studioMode != CameraStudioMode.video,
                  aspectRatioEnabled:
                      selectedLayoutMode == CameraLayoutMode.off,
                  ratioLetterboxed: ratioLetterboxed,
                  selectedLayoutMode: selectedLayoutMode,
                  layoutPickerOpen: layoutPickerOpen,
                  onLayoutModeSelected: onLayoutModeSelected,
                  speedPickerOpen: speedPickerOpen,
                  selectedSpeed: selectedSpeed,
                  onSpeedSelected: onSpeedSelected,
                  offLabel: l10n.settingsOff,
                  labels: CameraSideToolbarLabels(
                    flash: l10n.cameraFlash,
                    timer: l10n.cameraTimer,
                    layout: l10n.cameraLayout,
                    aspectRatio: l10n.cameraAspectRatio,
                    beauty: l10n.cameraBeauty,
                    filters: l10n.cameraFilters,
                    speed: l10n.cameraSpeed,
                    switchCamera: l10n.cameraSwitch,
                  ),
                ),
              ),
            ),
          ),
        if (showControls &&
            showRetouchPanel &&
            onPhotoEditorTabChanged != null &&
            onPhotoEditorToolSelected != null &&
            onPhotoEditorMagicToggled != null &&
            onPhotoEditorAdjustmentChanged != null &&
            onPhotoEditorReset != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: onBeautyTap,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {},
              child: MediaPhotoEditorPanel(
                l10n: l10n,
                tab: photoEditorTab,
                selectedTool: photoEditorTool,
                magicOn: photoEditorMagicOn,
                adjustmentValues: photoEditorAdjustments,
                onTabChanged: onPhotoEditorTabChanged!,
                onToolSelected: onPhotoEditorToolSelected!,
                onMagicToggled: onPhotoEditorMagicToggled!,
                onAdjustmentChanged: onPhotoEditorAdjustmentChanged!,
                onReset: onPhotoEditorReset!,
                selectedColorFilterId: photoEditorColorFilterId,
                colorFilterIntensity: photoEditorColorFilterIntensity,
                onColorFilterSelected: onPhotoEditorColorFilterSelected,
                onColorFilterIntensityChanged:
                    onPhotoEditorColorFilterIntensityChanged,
              ),
            ),
          ),
        ],
        if (showControls && showLegacyFiltersPanel) ...[
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
        if (showControls &&
            showArColorFiltersPanel &&
            onArFilterSelected != null &&
            onArColorCategorySelected != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: onFiltersToggle,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {}, // absorb taps so sheet itself doesn't dismiss
              child: ArColorFiltersPanel(
                selectedFilterId: selectedArFilterId,
                selectedCategoryId: arColorCategoryId,
                intensity: arFilterIntensity,
                onCategorySelected: onArColorCategorySelected!,
                onFilterSelected: (id) =>
                    onArFilterSelected!(ArFilterCatalog.indexOfId(id)),
                onIntensityChanged: onArFilterIntensityChanged ?? (_) {},
                onClear: () => onArFilterSelected!(0),
                onApply: onFiltersToggle,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _formatRecordClock(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _BottomInsetPanel extends StatelessWidget {
  const _BottomInsetPanel({required this.child, required this.bottomInset});

  final Widget child;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: child,
    );
  }
}

class _BottomWorkspaceRow extends StatelessWidget {
  const _BottomWorkspaceRow({
    required this.showGallery,
    required this.onUploadTap,
    required this.uploadLabel,
    required this.postLabel,
    required this.creativeLabel,
    required this.workspaceTabIndex,
    required this.onWorkspaceTabSelected,
  });

  final bool showGallery;
  final VoidCallback onUploadTap;
  final String uploadLabel;
  final String postLabel;
  final String creativeLabel;
  final int workspaceTabIndex;
  final ValueChanged<int> onWorkspaceTabSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          CameraWorkspaceTabs(
            postLabel: postLabel,
            creativeLabel: creativeLabel,
            selectedIndex: workspaceTabIndex,
            onSelected: onWorkspaceTabSelected,
          ),
          if (showGallery)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 16),
                child: CameraGalleryTool(
                  onTap: onUploadTap,
                  label: uploadLabel,
                  compact: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewActionsRow extends StatelessWidget {
  const _ReviewActionsRow({
    required this.cancelLabel,
    required this.nextLabel,
    required this.onNext,
    this.onCancel,
  });

  final String cancelLabel;
  final String nextLabel;
  final VoidCallback onNext;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _ReviewPill(
              onTap: onCancel,
              background: Colors.black.withValues(alpha: 0.45),
              borderColor: Colors.white.withValues(alpha: 0.7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      cancelLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ReviewPill(
              onTap: onNext,
              background: const Color(0xFFFE2C55),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      nextLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPill extends StatelessWidget {
  const _ReviewPill({
    required this.child,
    required this.background,
    required this.onTap,
    this.borderColor,
  });

  final Widget child;
  final Color background;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: borderColor == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor!, width: 1.4),
                ),
          child: Opacity(opacity: onTap == null ? 0.5 : 1, child: child),
        ),
      ),
    );
  }
}
