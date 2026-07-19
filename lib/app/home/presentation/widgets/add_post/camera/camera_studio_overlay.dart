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
    required this.beautyEnabled,
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
    required this.onLayoutTap,
    required this.onAspectRatioTap,
    required this.onTextModeTap,
    required this.onWorkspaceTabSelected,
    required this.workspaceTabIndex,
    this.selectedLayoutMode = CameraLayoutMode.off,
    this.layoutPickerOpen = false,
    this.onLayoutModeSelected,
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
    this.arColorCategoryId = 'portrait',
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
  final bool beautyEnabled;
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
  final VoidCallback onLayoutTap;
  final VoidCallback onAspectRatioTap;
  final VoidCallback onTextModeTap;
  final ValueChanged<int> onWorkspaceTabSelected;
  final int workspaceTabIndex;
  final CameraLayoutMode selectedLayoutMode;
  final bool layoutPickerOpen;
  final ValueChanged<CameraLayoutMode>? onLayoutModeSelected;
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
    final selectedArFilterId = ArFilterCatalog
        .items[arFilterIndex.clamp(0, ArFilterCatalog.items.length - 1)].id;
    // While the timer countdown (3-2-1) is running, hide every control so the
    // frame is clean — only the camera preview + the countdown number show.
    final showControls = countdownValue == null;
    // After a clip is recorded, swap the shutter + carousel for prominent
    // Cancel / Next review buttons (TikTok-style bottom actions).
    final isReviewingDraft =
        hasDraftClips && !isRecording && onFinishRecording != null;

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
        if (ratioLetterboxed) ...[
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: CameraRatioLetterbox.topHeight(topPadding),
            child: const IgnorePointer(
              child: ColoredBox(color: Colors.black),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: CameraRatioLetterbox.bottomHeight(
              useNativeAr: useNativeArFilters,
              filtersPanelOpen:
                  showLegacyFiltersPanel || showArColorFiltersPanel,
            ),
            child: const IgnorePointer(
              child: ColoredBox(color: Colors.black),
            ),
          ),
        ],
        // CamerAwesome / TFLite path — iOS and non-native fallback.
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
          bottom: !(useNativeArFilters && !isLiveMode),
          child: Column(
            children: [
              CameraTopBar(
                onClose: onClose,
                soundLabel: soundLabel ?? l10n.cameraOriginalSound,
                addSoundLabel: l10n.cameraAddSound,
                onSoundTap: onMusicTap,
                isLiveMode: isLiveMode,
              ),
              const Spacer(),
              if (!showLegacyFiltersPanel) ...[
                if (!isLiveMode &&
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
                    !showArColorFiltersPanel)
                  _BottomInsetPanel(
                    bottomInset: MediaQuery.paddingOf(context).bottom,
                    child: isReviewingDraft
                        ? _ReviewActionsRow(
                            cancelLabel: l10n.cancel,
                            nextLabel: l10n.nextAction,
                            onCancel: onDiscardDraft,
                            onNext: onFinishRecording!,
                          )
                        : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 4),
                        ArFilterCarousel(
                          items: ArFilterCatalog.effectItems,
                          selectedIndex: ArFilterCatalog.effectCarouselIndex(
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
                        ),
                        const SizedBox(height: 6),
                        if (selectedLayoutMode == CameraLayoutMode.off)
                          _BottomWorkspaceRow(
                            showGallery: showGalleryUpload,
                            onUploadTap: onUploadTap,
                            uploadLabel: isStoryMode
                                ? l10n.importFromLibrary
                                : l10n.uploadFromLibrary,
                            postLabel: l10n.cameraTabPost,
                            creativeLabel: l10n.cameraTabCreative,
                            workspaceTabIndex: workspaceTabIndex,
                            onWorkspaceTabSelected: onWorkspaceTabSelected,
                          )
                        else if (showGalleryUpload)
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: onUploadTap,
                                child: Icon(
                                  Icons.photo_library_outlined,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  )
                else if (!useNativeArFilters || isLiveMode) ...[
                  if (!isLiveMode) ...[
                    const SizedBox(height: 10),
                    if (isReviewingDraft)
                      _ReviewActionsRow(
                        cancelLabel: l10n.cancel,
                        nextLabel: l10n.nextAction,
                        onCancel: onDiscardDraft,
                        onNext: onFinishRecording!,
                      )
                    else
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
                    const SizedBox(height: 6),
                    CameraWorkspaceTabs(
                      postLabel: l10n.cameraTabPost,
                      creativeLabel: l10n.cameraTabCreative,
                      selectedIndex: workspaceTabIndex,
                      onSelected: onWorkspaceTabSelected,
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
              ] else
                const SizedBox(height: 180),
            ],
          ),
        ),
        if (showControls)
          Positioned.fill(
          child: Align(
            alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                left: isRtl ? 10 : 0,
                right: isRtl ? 0 : 10,
                top: topPadding + 52,
                bottom: showLegacyFiltersPanel || showArColorFiltersPanel
                    ? 220
                    : (useNativeArFilters ? 228 : 168),
              ),
              child: CameraSideToolbar(
                iconOnStartEdge: isRtl,
                onFlip: onFlip,
                onFlash: onFlash,
                onTimer: onTimerToggle,
                onLayout: onLayoutTap,
                onAspectRatio: onAspectRatioTap,
                onBeauty: onBeautyTap,
                onFilters: onFiltersToggle,
                onSpeed: onSpeedTap,
                flashEnabled: flashEnabled,
                beautyEnabled: beautyEnabled,
                filtersEnabled: showFilters,
                timerEnabled: timerEnabled,
                speedLabel: '${selectedSpeed}x',
                showSpeed: studioMode == CameraStudioMode.video,
                showAspectRatio: studioMode != CameraStudioMode.video,
                aspectRatioEnabled:
                    selectedLayoutMode == CameraLayoutMode.off,
                ratioLetterboxed: ratioLetterboxed,
                selectedLayoutMode: selectedLayoutMode,
                layoutPickerOpen: layoutPickerOpen,
                onLayoutModeSelected: onLayoutModeSelected,
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
        // Native AR — TikTok-style Filters sheet (color / white grades only).
        // No dim scrim — live preview stays bright so filter changes are visible.
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
              ),
            ),
          ),
        ],
        if (isRecording || hasDraftClips)
          CameraRecordingBadge(
            topPadding: topPadding,
            label: '${l10n.cameraRecording} ${recordSeconds}s',
            onTap: hasDraftClips && !isRecording ? onFinishRecording : null,
          ),
      ],
    );
  }
}

class _BottomInsetPanel extends StatelessWidget {
  const _BottomInsetPanel({
    required this.child,
    required this.bottomInset,
  });

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
      child: Stack(
        alignment: Alignment.center,
        children: [
          CameraWorkspaceTabs(
            postLabel: postLabel,
            creativeLabel: creativeLabel,
            selectedIndex: workspaceTabIndex,
            onSelected: onWorkspaceTabSelected,
          ),
          if (showGallery)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
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

/// Prominent Cancel / Next review actions shown after a clip is recorded —
/// full-width pills that replace the shutter + carousel, matching the editor's
/// bottom actions on the next screen.
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
