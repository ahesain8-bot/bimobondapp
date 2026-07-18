import 'dart:ui';

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
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_overlays.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_side_toolbar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_tool_icons.dart';
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
        .items[arFilterIndex.clamp(0, ArFilterCatalog.items.length - 1)]
        .id;

    return Stack(
      fit: StackFit.expand,
      children: [
        // OLD CamerAwesome / TFLite face stickers — kept for iOS / fallback.
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
        SafeArea(
          bottom: !(useNativeArFilters && !isLiveMode),
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
              if (!showLegacyFiltersPanel) ...[
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
                if (useNativeArFilters &&
                    !isLiveMode &&
                    onArFilterSelected != null &&
                    !showArColorFiltersPanel)
                  _BottomFrostPanel(
                    bottomInset: MediaQuery.paddingOf(context).bottom,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasDraftClips &&
                            !isRecording &&
                            onFinishRecording != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Row(
                              children: [
                                const Spacer(),
                                _DraftNextButton(
                                  label: l10n.nextAction,
                                  onTap: onFinishRecording!,
                                  onDiscard: onDiscardDraft,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        ArFilterCarousel(
                          items: ArFilterCatalog.effectItems,
                          selectedIndex: ArFilterCatalog.effectCarouselIndex(
                            selectedArFilterId,
                          ),
                          onSelected: (index) {
                            final id = ArFilterCatalog.effectItems[index].id;
                            onArFilterSelected!(ArFilterCatalog.indexOfId(id));
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
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  )
                else if (!useNativeArFilters || isLiveMode) ...[
                  if (!isLiveMode) ...[
                    const SizedBox(height: 10),
                    if (hasDraftClips &&
                        !isRecording &&
                        onFinishRecording != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            const Spacer(),
                            _DraftNextButton(
                              label: l10n.nextAction,
                              onTap: onFinishRecording!,
                              onDiscard: onDiscardDraft,
                            ),
                          ],
                        ),
                      ),
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
                  const SizedBox(height: 6),
                  CameraWorkspaceTabs(
                    postLabel: l10n.cameraTabPost,
                    creativeLabel: l10n.cameraTabCreative,
                    selectedIndex: workspaceTabIndex,
                    onSelected: onWorkspaceTabSelected,
                  ),
                  const SizedBox(height: 6),
                ],
              ] else
                const SizedBox(height: 180),
            ],
          ),
        ),
        Positioned.fill(
          child: Align(
            // Edge follows language: left in RTL, right in LTR.
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
        // OLD CamerAwesome color-filter sheet — skipped when native AR carousel is on.
        if (showLegacyFiltersPanel) ...[
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
        if (showArColorFiltersPanel &&
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

/// Soft light wash from the AR carousel through the home-indicator edge.
class _BottomFrostPanel extends StatelessWidget {
  const _BottomFrostPanel({required this.child, required this.bottomInset});

  final Widget child;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.07),
                const Color(0xFFF2F2F2).withValues(alpha: 0.11),
                const Color(0xFFF2F2F2).withValues(alpha: 0.14),
              ],
              stops: const [0.0, 0.18, 0.55, 1.0],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// TikTok-style bottom row: gallery/upload on the left, Post | Creative centered.
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

class _DraftNextButton extends StatelessWidget {
  const _DraftNextButton({
    required this.label,
    required this.onTap,
    this.onDiscard,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onDiscard != null) ...[
          GestureDetector(
            onTap: onDiscard,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsetsDirectional.only(end: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFE2C55),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
