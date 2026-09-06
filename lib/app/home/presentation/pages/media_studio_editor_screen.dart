import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/ar_camera/ar_color_filter_matrix.dart';
import 'package:bimobondapp/app/ar_camera/ar_color_filters_panel.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/pages/media_crop_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/video_segment_editor_screen.dart';
import 'package:bimobondapp/app/home/presentation/utils/camera_capture_utils.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_import_flow.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_skin_smooth.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_baker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_font_styles.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_layout.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_app_loading.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_photo_editor_panel.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_studio_editor_chrome.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_studio_preview.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_text_editor_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/media_text_overlay_layer.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_camera_editor.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_file.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_pick_result.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_sheet.dart';
import 'package:bimobondapp/app/video_templates/composition/composition_preview_controller.dart';
import 'package:bimobondapp/app/video_templates/composition/composition_session.dart';
import 'package:bimobondapp/app/video_templates/composition/template_composition_engine.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/domain/usecases/video_templates_usecases.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/di/video_templates_injector.dart'
    as vt_di;
import 'package:bimobondapp/app/video_templates/project/models/user_template_project_draft.dart';
import 'package:bimobondapp/app/video_templates/project/template_project_controller.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/video_template_client_renderer.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_look_baker.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/video_template_slot_filler.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/template_gpu_preview.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/template_selector_bottom_panel.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/video_template_composed_preview.dart';
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/app/video_templates/presentation/pages/video_template_editor_screen.dart';
import 'package:bimobondapp/app/video_templates/presentation/utils/template_export_l10n.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_export_overlay.dart';
import 'package:bimobondapp/app/video_templates/preview/media_texture_cache.dart';
import 'package:bimobondapp/app/video_templates/preview/template_preview_renderer.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:share_plus/share_plus.dart';

/// TikTok-style editor — same AR filters / effects / beauty behavior as camera.
class MediaStudioEditorScreen extends StatefulWidget {
  const MediaStudioEditorScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.isStory = false,
    this.initialSound,
    this.initialSoundOffset = Duration.zero,
    this.initialMuteOriginal = false,
    this.popOnDone = false,
    this.initialEdit,
    this.initialVideoTemplateId,
    this.initialVideoTemplateName,
    this.initialVideoTemplateSlotCount,
    this.initialTemplateProjectId,
  });

  final List<GalleryMediaItem> items;
  final int initialIndex;
  final bool isStory;
  final SoundEntity? initialSound;
  final Duration initialSoundOffset;
  final bool initialMuteOriginal;
  final bool popOnDone;
  final MediaEditorSeed? initialEdit;
  final String? initialVideoTemplateId;
  final String? initialVideoTemplateName;
  final int? initialVideoTemplateSlotCount;
  final String? initialTemplateProjectId;

  @override
  State<MediaStudioEditorScreen> createState() =>
      _MediaStudioEditorScreenState();
}

class _MediaStudioEditorScreenState extends State<MediaStudioEditorScreen>
    with FeedPlaybackBlocker, WidgetsBindingObserver {
  late List<MediaItemEditState> _states;
  late int _currentIndex;
  SoundEntity? _selectedSound;

  /// Editable local draft (mediaIds + slot/layer state). Not a baked MP4.
  TemplateProjectController? _templateProject;

  /// Where playback starts inside the selected track (TikTok-style trim).
  Duration _soundStartOffset = Duration.zero;

  /// Selected sound period length (typically 15s).
  Duration _soundWindow = const Duration(seconds: 15);

  /// Mute the video's own audio when mixing the selected music in.
  bool _muteOriginalAudio = false;

  /// True after [MediaStudioPreview.onReady] — soundtrack must not start earlier.
  bool _studioMediaReady = false;

  /// True when the user confirmed a trim range (Mode B2: soundId + ms).
  bool _soundDidTrim = false;

  /// Explicit clip id for Mode A (“use this sound”), when known.
  String? _pickedSoundSegmentId;

  /// Template chosen in studio (photos and/or videos → server slots on publish).
  String? _videoTemplateId;
  String? _videoTemplateName;
  int? _videoTemplateSlotCount;
  /// True only after the user picks a catalog template (shelf / panel / camera).
  bool _catalogTemplateApplied = false;
  String? _templateProjectId;
  VideoTemplateRecipeEntity? _templateRecipe;

  /// Original slot media (photos and/or videos) for UserProjectSlot fill.
  List<File> _templateSourceFiles = const [];

  /// Downloaded server-export MP4 for composer preview (not mobile-encoded).
  File? _templatePreviewFile;

  /// `/uploads/...` from backend export — publish posts this URL.
  String? _templateServerExportUrl;

  /// `draft` (fast Next) or `standard` (publish-ready). Null when server URL.
  String? _templateClientExportQuality;

  /// Live TikTok-style look on the studio preview (not a separate page).
  CompositionPreviewController? _templateLivePreview;
  CompositionSession? _templateLiveSession;

  /// Android shared GPU composer preview (same path as export).
  TemplateGpuPreviewController? _templateGpuPreview;

  /// Captures the on-screen composed preview (WYSIWYG save).
  final GlobalKey _templateCaptureKey = GlobalKey();

  /// When true, [dispose] must not delete [_templatePreviewFile] (handed to
  /// add-post / publish).
  bool _templatePreviewHandedOff = false;

  /// Bumped after sound picker/trim closes so [MediaStudioPreview] remounts a
  /// fresh ExoPlayer if Android left the previous one frozen.
  int _previewEpoch = 0;

  /// Length of the video generated from a still photo when music is added.
  static const _photoMusicMaxSeconds = 15;

  String _arFilterId = 'none';
  String _arColorCategoryId = 'beauty';
  double _arFilterIntensity = 1.0;
  bool _alreadyBaked = false;
  String _bakedFilterId = 'none';
  bool _showFilters = false;
  bool _showPhotoEditor = false;

  /// In-editor template carousel (same screen — never a new route).
  bool _showTemplateSelector = false;

  /// Keeps the panel mounted so close/open can animate smoothly.
  bool _templateSelectorMounted = false;
  bool _templateApplying = false;

  /// Bumps when the user switches templates so stale apply work is ignored.
  int _templateApplyGen = 0;
  MediaPhotoEditorTab _photoEditorTab = MediaPhotoEditorTab.face;
  MediaPhotoEditorTool _photoEditorTool = MediaPhotoEditorTool.magic;
  bool _magicOn = false;
  bool _preserveNeutralAdjustments = false;

  static const Map<MediaPhotoEditorTool, double> _magicBeautyDefaults = {
    MediaPhotoEditorTool.smooth: 0.50, // 50
    MediaPhotoEditorTool.contrast: 0.39, // 39
    MediaPhotoEditorTool.shape: -0.83, // -83
    MediaPhotoEditorTool.nose: 0.05, // 5
    MediaPhotoEditorTool.eyes: 0.05, // 5
    MediaPhotoEditorTool.tooth: 0.42, // cleaner
    MediaPhotoEditorTool.mouth: 0.28, // fuller / more open
    MediaPhotoEditorTool.saturation: -0.07, // -7
    MediaPhotoEditorTool.brightness: -0.15, // -15
    MediaPhotoEditorTool.exposure: -0.53, // -53
    MediaPhotoEditorTool.whiteBalance: -0.04, // -4
    MediaPhotoEditorTool.highlights: -0.22, // -22
    MediaPhotoEditorTool.shadows: -0.50, // -50
  };

  /// Bipolar tone/color adjustments (−1.5…1.5) keyed by tool.
  final Map<MediaPhotoEditorTool, double> _adjustments = {
    MediaPhotoEditorTool.smooth: 0.50,
    MediaPhotoEditorTool.contrast: 0.39,
    MediaPhotoEditorTool.shape: -0.83,
    MediaPhotoEditorTool.nose: 0.05,
    MediaPhotoEditorTool.eyes: 0.05,
    MediaPhotoEditorTool.tooth: 0.42,
    MediaPhotoEditorTool.mouth: 0.28,
    MediaPhotoEditorTool.saturation: -0.07,
    MediaPhotoEditorTool.brightness: -0.15,
    MediaPhotoEditorTool.exposure: -0.53,
    MediaPhotoEditorTool.whiteBalance: -0.04,
    MediaPhotoEditorTool.highlights: -0.22,
    MediaPhotoEditorTool.shadows: -0.50,
    MediaPhotoEditorTool.lipstick: 0.0,
    MediaPhotoEditorTool.foundation: 0.0,
    MediaPhotoEditorTool.eyeshadow: 0.0,
    MediaPhotoEditorTool.contour: 0.0,
    MediaPhotoEditorTool.blush: 0.0,
    MediaPhotoEditorTool.underEye: 0.0,
    MediaPhotoEditorTool.brightenEye: 0.0,
    MediaPhotoEditorTool.eyeliner: 0.0,
  };
  File? _smoothPreviewFile;
  Timer? _smoothDebounce;
  int _smoothGen = 0;
  bool _isProcessing = false;

  /// Template Next/export progress in `0..1` (null = indeterminate).
  double? _templateExportProgress;
  String? _templateExportLabel;

  /// Shows the TikTok-style exit confirmation (Discard / Save draft / Continue).
  bool _showExitMenu = false;

  /// True while a full-screen sub-editor (Trim / Text) is open on top, so the
  /// main video preview pauses and its audio doesn't play behind it.
  bool _subEditorOpen = false;

  /// Set once the user confirms Discard so [PopScope] lets the route pop.
  bool _leaving = false;

  /// Preview box size used to scale text when baking export.
  Size _previewSize = Size.zero;

  /// Pixel size of the current source media (image or video frame).
  Size _mediaPixelSize = Size.zero;
  String? _mediaPixelSizePath;

  MediaItemEditState get _currentState => _states[_currentIndex];

  double _adj(MediaPhotoEditorTool tool) =>
      _magicOn ? (_adjustments[tool] ?? 0.0) : 0.0;

  bool get _hasFaceEdits =>
      _magicOn && _adjustments.values.any((v) => v.abs() > 0.02);

  static bool _stateHasFaceEdits(MediaItemEditState s) =>
      s.faceSaturation.abs() > 0.02 ||
      s.faceBrightness.abs() > 0.02 ||
      s.faceContrast.abs() > 0.02 ||
      s.faceExposure.abs() > 0.02 ||
      s.faceWhiteBalance.abs() > 0.02 ||
      s.faceHighlights.abs() > 0.02 ||
      s.faceShadows.abs() > 0.02 ||
      s.faceNose.abs() > 0.02;

  bool get _beautyEnabled => _arFilterId == 'whitening';

  bool get _hasActiveEffect =>
      _arFilterId != 'none' && !ArFilterCatalog.isColorFilter(_arFilterId);

  bool get _hasActiveColorFilter => ArFilterCatalog.isColorFilter(_arFilterId);

  /// Whether the selected filter has an actual color grade (brightness/
  /// contrast/saturation/warmth) to preview — gates [MediaStudioPreview]'s
  /// `applyArColorPreview` (see build()) so a picked filter's color grade
  /// actually shows up live in the editor, and [ArColorFilterMatrix] bakes
  /// it into the exported video. Beauty-only filters (no color grade fields
  /// set) return false here — those fields aren't supported post-capture.
  /// Also skips the preview overlay when the capture already baked this same
  /// filter into the source pixels natively (`_alreadyBaked`) — otherwise the
  /// editor would layer the color grade on top of an already-graded image,
  /// doubling the effect (e.g. warmth looking much stronger than what was
  /// selected live). `_exportCurrentWithColorIfNeeded`/
  /// `_exportVideoWithEditsIfNeeded` already guard the same way for the
  /// exported file — this brings the live preview in line with them.
  bool get _needsColorFilterPreview =>
      _hasActiveColorFilter &&
      (ArFilterCatalog.colorFilterById(_arFilterId)?.params?.hasColorGrade ??
          false) &&
      (!_alreadyBaked || _arFilterId != _bakedFilterId);

  /// Any photo edit that requires a native-baked preview file (tone/geometry).
  bool get _hasPreviewEdits => _hasFaceEdits || _needsColorFilterPreview;

  bool get _usesCatalogTemplate =>
      _catalogTemplateApplied &&
      VideoTemplateProjectIds.isServerId(_videoTemplateId);

  /// True when previewing a fully rendered template MP4 video file.
  /// The exported video file already contains the template soundtrack muxed into it,
  /// so SoundAudioPreview must be stopped to avoid playing duplicate/repeated audio.
  bool get _isRenderedTemplatePreview {
    if (_templatePreviewFile != null) return true;
    if (_videoTemplateId != null &&
        _states.length == 1 &&
        _states.first.isVideo &&
        _templateServerExportUrl != null &&
        _templateServerExportUrl!.isNotEmpty) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedSound = widget.initialSound;
    _soundStartOffset = widget.initialSoundOffset;
    _muteOriginalAudio = widget.initialMuteOriginal;
    // Gallery / free edit: do not treat navigation extras as a catalog pick.
    // templateId is only sent after an explicit shelf pick in this session.
    _templateProjectId = VideoTemplateProjectIds.normalizeServerId(
      widget.initialTemplateProjectId,
    );
    _states = widget.items.map(MediaItemEditState.fromItem).toList();
    if (widget.initialEdit != null && _states.isNotEmpty) {
      _states[0] = MediaItemEditState.fromItemWithSeed(
        _states[0].item,
        widget.initialEdit!,
      );
    }
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _applyStateToUi(_states[_currentIndex]);
    unawaited(_resolveMediaPixelSize());
    // Warm fancy fonts in the background so Aa opens without a hitch.
    unawaited(MediaTextFontStyles.preload());
    if (_hasPreviewEdits) {
      _scheduleFacePreview();
    }
    // Soundtrack starts from [MediaStudioPreview.onReady] so it does not
    // lead the video while the player is still loading.
  }

  Future<void> _resolveMediaPixelSize() async {
    final file = _currentState.sourceFile;
    final path = file.path;
    if (_mediaPixelSizePath == path && _mediaPixelSize != Size.zero) return;

    Size size = Size.zero;
    try {
      if (_currentState.isVideo) {
        size = await NativeVideoProcessor.videoResolution(file) ?? Size.zero;
      } else {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        size = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
        frame.image.dispose();
      }
    } catch (_) {
      size = Size.zero;
    }
    if (!mounted || _currentState.sourceFile.path != path) return;
    setState(() {
      _mediaPixelSizePath = path;
      _mediaPixelSize = size;
    });
  }

  /// Soft template bed is active — never layer camera/video audio under it.
  bool get _muteMediaForTemplateBed {
    if (_isRenderedTemplatePreview) return false;
    if (_videoTemplateId == null) {
      return _selectedSound != null && _muteOriginalAudio;
    }
    return _selectedSound != null;
  }

  /// Keeps the selected track audible under the studio preview (video or photo).
  /// Stops while a sub-editor / sound picker is open so players don't fight.
  ///
  /// When [requireMediaReady] is true (default), waits for [MediaStudioPreview]
  /// so music never leads a still-loading video.
  Future<void> _syncStudioSoundPreview({bool requireMediaReady = true}) async {
    final sound = _selectedSound;
    if (sound == null ||
        _subEditorOpen ||
        _isProcessing ||
        _isRenderedTemplatePreview) {
      await SoundAudioPreview.stop();
      return;
    }
    if (requireMediaReady && !_studioMediaReady) {
      // onReady will start the bed once the surface is playing / painted.
      return;
    }
    final url = sound.resolvedAudioUrl;
    if (url.isEmpty) {
      await SoundAudioPreview.stop();
      return;
    }
    // Ensure original media stays silent under the bed (video + music = 2 tracks).
    if (!_muteOriginalAudio) {
      _muteOriginalAudio = true;
      if (mounted) setState(() {});
    }
    await SoundAudioPreview.playAt(
      sound.id,
      url,
      startOffset: _soundStartOffset,
      window: _soundWindow,
      loop: true,
    );
  }

  /// Called when the preview surface is ready — start music with the media.
  /// Idempotent: only the first ready signal starts (or stops) the bed.
  void _onStudioMediaReady() {
    if (_studioMediaReady) return;
    _studioMediaReady = true;
    if (!mounted || _subEditorOpen || _isProcessing) return;
    // Rendered MP4 already has muxed template audio — never layer SoundAudioPreview.
    if (_isRenderedTemplatePreview) {
      unawaited(SoundAudioPreview.stop());
      return;
    }
    unawaited(_syncStudioSoundPreview(requireMediaReady: false));
  }

  /// Video looped back to 0:00 — keep music bed playing continuously.
  /// [SoundAudioPreview] manages its own audio loop window natively.
  void _onStudioMediaLoopRestart() {
    if (!mounted || _selectedSound == null || _subEditorOpen || _isProcessing) {
      return;
    }
    // Do not interrupt or seek audio back to start when short video clips loop.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_templateProject?.saveDraftNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_templateProject?.saveDraftNow());
    _templateProject?.dispose();
    _templateProject = null;
    _smoothDebounce?.cancel();
    unawaited(SoundAudioPreview.stop());
    _disposeLiveTemplatePreview();
    MediaTextureCache.shared.clear();
    try {
      _smoothPreviewFile?.deleteSync();
    } catch (_) {}
    // Only delete if we still own the file (not passed to add-post).
    if (!_templatePreviewHandedOff) {
      try {
        _templatePreviewFile?.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  /// Detach live preview from the tree, then dispose after the frame so
  /// [ListenableBuilder] can drop its listener (avoids `_dependents` asserts).
  ///
  /// Pass [disposeGpu]: false when swapping Flutter soft preview off while
  /// keeping an active [TemplateGpuPreviewController] (GPU soft path).
  void _disposeLiveTemplatePreview({
    bool deferRelease = true,
    bool disposeGpu = true,
  }) {
    TemplateGpuPreviewController? gpu;
    if (disposeGpu) {
      gpu = _templateGpuPreview;
      _templateGpuPreview = null;
      try {
        gpu?.dispose();
      } catch (_) {}
    }

    final preview = _templateLivePreview;
    final session = _templateLiveSession;
    _templateLivePreview = null;
    _templateLiveSession = null;
    if (preview == null && session == null && gpu == null) return;

    void release() {
      preview?.dispose();
      unawaited(session?.dispose() ?? Future<void>.value());
    }

    if (!mounted || !deferRelease) {
      release();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => release());
  }

  /// Gallery/camera `type: VIDEO` beats path extension (some captures omit `.mp4`).
  List<bool> _videoHintsForFiles(List<File> files) {
    final anyStudioVideo = _states.any((s) => s.isVideo);
    // Single capture that is a video → every padded slot is that clip.
    if (anyStudioVideo && files.length == 1) {
      return const [true];
    }
    return files
        .map((f) {
          for (final s in _states) {
            if (s.sourceFile.path == f.path || s.item.file.path == f.path) {
              return s.isVideo;
            }
          }
          // If studio session is video-only, treat all sources as video.
          if (anyStudioVideo && _states.every((s) => s.isVideo)) return true;
          return _isVideoPath(f) || VideoThumbnailUtils.isVideoFile(f);
        })
        .toList(growable: false);
  }

  Future<bool> _attachLiveTemplatePreview(
    VideoTemplateRecipeEntity recipe, {
    List<File>? sourceOverride,
    int? applyGen,
  }) async {
    final gen = applyGen ?? _templateApplyGen;
    final sw = Stopwatch()..start();
    var sourceFiles =
        sourceOverride ??
        (_templateSourceFiles.isNotEmpty
            ? _templateSourceFiles
            : _states.map((s) => s.sourceFile).toList(growable: false));
    final project = _templateProject;
    // Only resolve durable project media when the caller did not pass sources.
    if (project != null && (sourceOverride == null || sourceOverride.isEmpty)) {
      final durable = await project.resolveSlotFiles();
      if (durable.isNotEmpty) {
        sourceFiles = durable;
        _templateSourceFiles = durable;
      }
    }
    if (!mounted || gen != _templateApplyGen) return false;
    if (sourceFiles.isEmpty) return false;

    final videoHints = _videoHintsForFiles(sourceFiles);
    final hasVideo = videoHints.any((v) => v);

    // GPU / on-device encode preview disabled — soft Flutter preview only;
    // final MP4 always comes from server export on Next.

    // Hold previous look until the new controller is ready.
    final previousPreview = _templateLivePreview;
    final previousSession = _templateLiveSession;

    try {
      // Keep downscaled stills for the current sources across Template A→B→C.
      MediaTextureCache.shared.retainPaths(
        sourceFiles.map((f) => f.absolute.path),
      );

      final engine = vt_di.sl<TemplateCompositionEngine>();
      final slotEngine = SlotEngine(recipe: recipe);
      Map<String, SlotFillEntry> fills;
      // Prefer explicit sources for soft-apply (avoids waiting on project I/O
      // and prevents stale fills from a previous template).
      Map<String, SlotFillEntry> fillsFromSources() {
        var mapped = slotEngine.fillsFromFiles(
          sourceFiles,
          isVideoHints: videoHints,
        );
        // Retag only files that are actually video — never force IMAGE slots
        // (or stills in a mixed session) to VIDEO (blank / broken preview).
        mapped = mapped.map((key, fill) {
          final file = fill.localFile;
          if (file == null) return MapEntry(key, fill);
          final idx = sourceFiles.indexWhere((f) => f.path == file.path);
          final hintedVideo =
              idx >= 0 && idx < videoHints.length && videoHints[idx];
          final isVideo =
              hintedVideo ||
              VideoThumbnailUtils.isVideoFile(file) ||
              fill.isLocalVideo;
          final kind = isVideo ? 'VIDEO' : 'IMAGE';
          if (fill.mediaKind?.toUpperCase() == kind) {
            return MapEntry(key, fill);
          }
          return MapEntry(key, fill.copyWith(mediaKind: kind));
        });
        return slotEngine.applyBeatSyncTrims(mapped);
      }

      if (sourceOverride != null && sourceOverride.isNotEmpty) {
        fills = fillsFromSources();
      } else if (project != null) {
        fills = await project.buildFills();
        if (!mounted || gen != _templateApplyGen) return false;
        if (fills.isEmpty || fills.values.every((f) => !f.hasMedia)) {
          fills = fillsFromSources();
        } else if (hasVideo) {
          // Durable fills may drop VIDEO kind — re-tag from studio hints.
          fills = fillsFromSources();
        }
      } else {
        fills = fillsFromSources();
      }
      if (fills.isEmpty || fills.values.every((f) => !f.hasMedia)) {
        fills = fillsFromSources();
      }
      if (fills.isEmpty || fills.values.every((f) => !f.hasMedia)) {
        debugPrint('Live template preview: no slot fills for ${recipe.id}');
        return false;
      }
      if (!mounted || gen != _templateApplyGen) return false;

      final session = engine.open(recipe, projectId: _templateProjectId);
      session.fills = fills;
      session.seedDefaultsFromRecipe();
      final preview = CompositionPreviewController(
        engine: engine,
        session: session,
      );
      // Soft preview: skip full still decode / video probe so the look
      // appears immediately (Image.file / MediaStudioPreview).
      await preview.attach(prepareMedia: false);
      if (!mounted || gen != _templateApplyGen) {
        preview.dispose();
        unawaited(session.dispose());
        return false;
      }

      _templateLiveSession = session;
      _templateLivePreview = preview;
      // Video always uses studio MediaStudioPreview (composition VideoPlayer is
      // flaky on camera clips; layout panes need separate player instances).
      if (hasVideo) {
        await preview.detachMediaSurface();
      }
      if (!mounted || gen != _templateApplyGen) {
        preview.dispose();
        unawaited(session.dispose());
        if (_templateLivePreview == preview) {
          _templateLivePreview = previousPreview;
          _templateLiveSession = previousSession;
        }
        return false;
      }
      preview.play();

      // Drop the previous controller after the new one is wired.
      if (previousPreview != null || previousSession != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          previousPreview?.dispose();
          unawaited(previousSession?.dispose() ?? Future<void>.value());
        });
      }

      if (mounted) setState(() {});
      debugPrint(
        'TemplatePreview: attach=${sw.elapsedMilliseconds}ms '
        'recipe=${recipe.id}',
      );
      return true;
    } catch (e, st) {
      debugPrint('Live template preview failed: $e\n$st');
      // Restore previous look if the new attach failed.
      if (_templateLivePreview == null) {
        _templateLivePreview = previousPreview;
        _templateLiveSession = previousSession;
      } else {
        previousPreview?.dispose();
        unawaited(previousSession?.dispose() ?? Future<void>.value());
      }
      return false;
    }
  }

  Future<bool> _attachGpuTemplatePreview(
    VideoTemplateRecipeEntity recipe,
    List<File> sourceFiles, {
    List<bool>? isVideoHints,
    int? applyGen,
  }) async {
    final gen = applyGen ?? _templateApplyGen;
    final previousGpu = _templateGpuPreview;
    try {
      // Reuse controller so Template A→B keeps the native texture when sources match.
      final gpu = previousGpu ?? TemplateGpuPreviewController();
      final ok = await gpu.open(
        recipe: recipe,
        localFiles: sourceFiles,
        isVideoHints: isVideoHints ?? _videoHintsForFiles(sourceFiles),
        quality: TemplateClientExportQuality.preview,
      );
      if (!ok || !mounted || gen != _templateApplyGen) {
        if (!identical(gpu, previousGpu)) {
          gpu.dispose();
        }
        return false;
      }
      _templateGpuPreview = gpu;
      // Drop Flutter composition only — keep the GPU controller we just set.
      _disposeLiveTemplatePreview(disposeGpu: false);
      if (mounted) setState(() {});
      debugPrint(
        'TemplatePreview: gpu Soft preview '
        '${gpu.width}x${gpu.height} recipe=${recipe.id}',
      );
      return true;
    } catch (e, st) {
      debugPrint('GPU template preview failed: $e\n$st');
      return false;
    }
  }

  /// Soft-apply live look on the studio preview (same screen).
  ///
  /// Critical path is attach-only. Project disk I/O and MP4 bake run after
  /// Processing is cleared (see [_persistTemplateProjectInBackground]).
  Future<void> _openTemplateAppliedPreview({
    VideoTemplateRecipeEntity? recipeOverride,
    List<File>? sourceOverride,
  }) async {
    if (_states.isEmpty || !_usesCatalogTemplate) return;
    _saveUiToCurrentState();
    final applyGen = _templateApplyGen;
    _templatePreviewFile = null;
    _templateServerExportUrl = null;
    // Avoid a second full-screen "applying" flash when apply already set it.
    if (mounted && !_templateApplying) {
      setState(() {
        _templateApplying = true;
        _studioMediaReady = false;
        _showFilters = false;
        _showPhotoEditor = false;
        _showExitMenu = false;
      });
    } else if (mounted) {
      _studioMediaReady = false;
    }
    // Stop any prior bed before soft attach so we never stack two tracks.
    unawaited(SoundAudioPreview.stop());

    try {
      final sources =
          sourceOverride ??
          (_templateSourceFiles.isNotEmpty
              ? _templateSourceFiles
              : _states.map((s) => s.sourceFile).toList(growable: false));
      if (_templateSourceFiles.isEmpty) {
        _templateSourceFiles = sources;
      }

      final recipe = recipeOverride ?? await _ensureTemplateRecipe();
      if (!mounted || applyGen != _templateApplyGen) return;
      if (recipe == null) {
        setState(() => _templateApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.templateCouldNotLoad),
          ),
        );
        return;
      }
      _templateRecipe = recipe;
      // Keep sound already chosen on apply (panel), else recipe bed.
      _bindTemplateSound(
        recipe,
        preferred: _selectedSound,
        preferredSegmentId: _pickedSoundSegmentId,
      );

      var liveOk = false;
      final preferGpu = TemplatePreviewRenderer.preferGpuSoftPreview(
        recipe: recipe,
        sources: sources,
      );
      if (preferGpu) {
        liveOk = await _attachGpuTemplatePreview(
          recipe,
          sources,
          applyGen: applyGen,
        );
      }
      if (!liveOk) {
        // Layouts / video / GPU fail → Flutter soft compositor.
        if (_templateGpuPreview != null) {
          _templateGpuPreview?.dispose();
          _templateGpuPreview = null;
        }
        liveOk = await _attachLiveTemplatePreview(
          recipe,
          sourceOverride: sources,
          applyGen: applyGen,
        );
      }
      if (!mounted || applyGen != _templateApplyGen) return;

      // Live soft preview only — encode always happens on the server at Next.
      if (mounted && applyGen == _templateApplyGen) {
        setState(() => _templateApplying = false);
        // Image templates draw via CompositionPreviewController (RawImage),
        // not MediaStudioPreview — onReady never fires. Start the bed here.
        // Video templates still wait for MediaStudioPreview.onReady.
        // GPU soft preview also needs the bed started here.
        final live = _templateLivePreview;
        final gpuReady = _templateGpuPreview?.isReady == true;
        final imageSurface =
            live != null && live.hasPreviewSurface && !live.activeSlotIsVideo;
        final sourcesAreImages =
            sources.isNotEmpty &&
            sources.every((f) => !VideoThumbnailUtils.isVideoFile(f));
        if (gpuReady || imageSurface || sourcesAreImages) {
          _onStudioMediaReady();
        } else {
          unawaited(_syncStudioSoundPreview());
        }
        if (liveOk) {
          debugPrint(
            'Template soft preview ready '
            '(gpu=$gpuReady server encode on Next)',
          );
        }
      }
    } catch (e) {
      if (mounted && applyGen == _templateApplyGen) {
        setState(() => _templateApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.templatePreviewFailed}: $e',
            ),
          ),
        );
      }
    }
  }

  /// Post `filterName` — template title when a template is applied, else AR filter.
  String? _filterNameForPost() {
    final templateName = _videoTemplateName?.trim();
    if (_usesCatalogTemplate &&
        templateName != null &&
        templateName.isNotEmpty) {
      return templateName;
    }
    return primaryFilterNameFromStates(_states);
  }

  /// Apply recipe / selection music so preview plays with the template track.
  void _bindTemplateSound(
    VideoTemplateRecipeEntity recipe, {
    SoundEntity? preferred,
    String? preferredSegmentId,
  }) {
    final sound = preferred ?? recipe.effectivePreviewSound;
    if (sound == null) {
      // Template has no bed — stop previous template music under preview.
      _selectedSound = null;
      _pickedSoundSegmentId = null;
      _soundDidTrim = false;
      _soundStartOffset = Duration.zero;
      _soundWindow = const Duration(seconds: 15);
      unawaited(SoundAudioPreview.stop());
      return;
    }

    _selectedSound = sound;
    _pickedSoundSegmentId =
        preferredSegmentId ?? recipe.soundSegmentId ?? _pickedSoundSegmentId;
    _muteOriginalAudio = true;

    final startMs = recipe.soundSegmentStartMs;
    final endMs = recipe.soundSegmentEndMs;
    if (startMs != null && endMs != null && endMs > startMs) {
      _soundStartOffset = Duration(milliseconds: startMs);
      _soundWindow = Duration(milliseconds: endMs - startMs);
      _soundDidTrim = true;
    } else {
      _soundStartOffset = Duration.zero;
      final trackSec = sound.duration > 0 ? sound.duration : 15;
      _soundWindow = Duration(seconds: trackSec.clamp(1, 60));
      _soundDidTrim = _pickedSoundSegmentId != null;
    }
  }

  Future<void> _bakeTemplatePreviewInBackground({required int applyGen}) async {
    // Disabled — IMAGE/VIDEO templates never encode on device.
    debugPrint('Skip client warm (server-only template policy)');
  }

  /// Transfers a durable copy of the preview MP4 to add-post / publish.
  Future<File?> _handoffTemplatePreviewFile() async {
    final src =
        _templatePreviewFile ??
        (_videoTemplateId != null &&
                _states.length == 1 &&
                _states.first.isVideo
            ? _states.first.sourceFile
            : null);
    if (src == null) return null;
    if (!await src.exists()) {
      _templatePreviewFile = null;
      return null;
    }
    try {
      final dir = await getTemporaryDirectory();
      final dest = File(
        '${dir.path}/tpl_export_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await src.copy(dest.path);
      _templatePreviewHandedOff = true;
      _templatePreviewFile = null;
      return dest;
    } catch (_) {
      _templatePreviewHandedOff = true;
      _templatePreviewFile = null;
      return src;
    }
  }

  void _applyStateToUi(MediaItemEditState state) {
    _arFilterId = state.arFilterId;
    _arColorCategoryId = state.arColorCategoryId;
    // Default id doesn't match a real dynamic category (e.g. no filter was
    // ever picked for this item) — fall back to whichever category the
    // catalog lists first, matching the backend's own category order.
    final arCategories = ArFilterCatalog.colorCategories;
    if (arCategories.isNotEmpty &&
        !arCategories.any((c) => c.id == _arColorCategoryId)) {
      _arColorCategoryId = arCategories.first.id;
    }
    _arFilterIntensity = state.arFilterIntensity;
    _alreadyBaked = state.alreadyBaked;
    _bakedFilterId = state.bakedArFilterId;
    _adjustments[MediaPhotoEditorTool.saturation] = state.faceSaturation;
    _adjustments[MediaPhotoEditorTool.brightness] = state.faceBrightness;
    _adjustments[MediaPhotoEditorTool.contrast] = state.faceContrast;
    _adjustments[MediaPhotoEditorTool.exposure] = state.faceExposure;
    _adjustments[MediaPhotoEditorTool.whiteBalance] = state.faceWhiteBalance;
    _adjustments[MediaPhotoEditorTool.highlights] = state.faceHighlights;
    _adjustments[MediaPhotoEditorTool.shadows] = state.faceShadows;
    _adjustments[MediaPhotoEditorTool.nose] = state.faceNose;
    _magicOn = state.arFilterId == 'whitening';
  }

  void _saveUiToCurrentState() {
    _states[_currentIndex] = _states[_currentIndex].copyWith(
      arFilterId: _arFilterId,
      arColorCategoryId: _arColorCategoryId,
      arFilterIntensity: _arFilterIntensity,
      faceSaturation: _adj(MediaPhotoEditorTool.saturation),
      faceBrightness: _adj(MediaPhotoEditorTool.brightness),
      faceContrast: _adj(MediaPhotoEditorTool.contrast),
      faceExposure: _adj(MediaPhotoEditorTool.exposure),
      faceWhiteBalance: _adj(MediaPhotoEditorTool.whiteBalance),
      faceHighlights: _adj(MediaPhotoEditorTool.highlights),
      faceShadows: _adj(MediaPhotoEditorTool.shadows),
      faceNose: _adj(MediaPhotoEditorTool.nose),
      alreadyBaked: _alreadyBaked,
      bakedArFilterId: _bakedFilterId,
      beautyEnabled: _beautyEnabled,
      effectSlug: _hasActiveEffect ? _arFilterId : null,
    );
  }

  Future<File> _exportCurrentWithColorIfNeeded(MediaItemEditState state) async {
    if (state.isVideo) return _exportVideoWithEditsIfNeeded(state);

    var file = state.sourceFile;

    // Face → tone/color adjustments (native OpenCV, full-res).
    if (_stateHasFaceEdits(state)) {
      final adjusted = await MediaSkinSmooth.apply(
        input: file,
        saturation: state.faceSaturation,
        brightness: state.faceBrightness,
        contrast: state.faceContrast,
        exposure: state.faceExposure,
        whiteBalance: state.faceWhiteBalance,
        highlights: state.faceHighlights,
        shadows: state.faceShadows,
        nose: state.faceNose,
      );
      if (adjusted != null) file = adjusted;
    }

    final needsColorExport =
        ArFilterCatalog.isColorFilter(state.arFilterId) &&
        (!state.alreadyBaked || state.arFilterId != state.bakedArFilterId);
    if (needsColorExport) {
      file = await _bakeColorFilterToFile(
        file,
        state.arFilterId,
        state.arFilterIntensity,
      );
    }

    if (state.textOverlays.isNotEmpty && _previewSize != Size.zero) {
      file = await MediaTextBaker.bake(
        input: file,
        overlays: state.textOverlays,
        previewSize: _previewSize,
      );
    }

    return file;
  }

  /// Bakes the video's editor changes (color grade + text overlays) into a new
  /// file in a single native render pass. Returns the source unchanged if there
  /// is nothing to apply or the native render fails.
  Future<File> _exportVideoWithEditsIfNeeded(MediaItemEditState state) async {
    final file = state.sourceFile;

    // Only bake a color grade the user picked in the editor — not one the native
    // capture already baked into the recorded pixels (avoids double-applying).
    final needsColor =
        ArFilterCatalog.isColorFilter(state.arFilterId) &&
        (!state.alreadyBaked || state.arFilterId != state.bakedArFilterId);
    final colorMatrix = needsColor
        ? ArColorFilterMatrix.exportMatrix(
            state.arFilterId,
            intensity: state.arFilterIntensity,
          )
        : null;

    File? overlayPng;
    if (state.textOverlays.isNotEmpty && _previewSize != Size.zero) {
      final frame = await NativeVideoProcessor.videoResolution(file);
      if (frame != null) {
        overlayPng = await MediaTextBaker.bakeOverlayPng(
          overlays: state.textOverlays,
          previewSize: _previewSize,
          frameSize: frame,
        );
      }
    }

    final segments = state.trimSegments.isNotEmpty ? state.trimSegments : null;

    if (colorMatrix == null && overlayPng == null && segments == null) {
      return file;
    }

    final edited = await NativeVideoProcessor.renderVideoEdits(
      input: file,
      segments: segments,
      colorMatrix: colorMatrix,
      overlayPng: overlayPng,
    );

    if (overlayPng != null) {
      try {
        overlayPng.deleteSync();
      } catch (_) {}
    }
    return edited ?? file;
  }

  /// Bakes a filter's color grade (brightness/contrast/saturation/warmth)
  /// into a photo, at [intensity] (0..1). Beauty fields (smooth/whiten/
  /// blush/lipTint) aren't supported here — those need face-landmark
  /// detection, which this post-capture path doesn't run; only the color
  /// grade, same fields [ArColorFilterMatrix] bakes into exported video,
  /// applies. Reuses the same native OpenCV pass as the face retouch
  /// sliders (MediaSkinSmooth.apply / ArCameraBridge.applyBeauty).
  Future<File> _bakeColorFilterToFile(
    File input,
    String filterId,
    double intensity,
  ) async {
    final params = ArFilterCatalog.colorFilterById(filterId)?.params;
    if (params == null || !params.hasColorGrade) return input;
    final t = intensity.clamp(0.0, 1.0);
    final adjusted = await MediaSkinSmooth.apply(
      input: input,
      saturation: params.saturation * t,
      brightness: params.brightness * t,
      contrast: params.contrast * t,
      whiteBalance: params.warmth * t,
    );
    return adjusted ?? input;
  }

  Future<List<File>> _exportAll() async {
    _saveUiToCurrentState();
    // Keep the user's real photos/videos. Template slots are filled on the
    // server (repeated asset URLs) — do not expand into a fake carousel.
    final results = <File>[];
    for (final state in _states) {
      results.add(await _exportCurrentWithColorIfNeeded(state));
    }
    await _bakeMusicInto(results);
    return results;
  }

  /// Bakes the selected music track into exported **photos** only (turns them
  /// into a short music video). Videos skip remux — library sounds attach via
  /// `soundId` and are mixed at playback, which avoids a full re-encode.
  Future<void> _bakeMusicInto(List<File> results) async {
    final sound = _selectedSound;
    if (sound == null) return;
    final audioUrl = sound.resolvedAudioUrl;
    if (audioUrl.isEmpty) return;

    final hasPhoto = results.asMap().entries.any((e) {
      final i = e.key;
      return i < _states.length && !_states[i].isVideo;
    });
    if (!hasPhoto) return;

    final audio = await SoundLocalFile.resolve(audioUrl);
    if (audio == null) return;

    // Use the chosen trim window (capped), not a forced 15s encode.
    final trackSeconds = sound.duration > 0 ? sound.duration : 0;
    var photoSeconds = _soundWindow.inSeconds.clamp(1, _photoMusicMaxSeconds);
    if (trackSeconds > 0) {
      final remaining = trackSeconds - _soundStartOffset.inSeconds;
      if (remaining > 0 && remaining < photoSeconds) {
        photoSeconds = remaining;
      }
    }
    final photoDuration = Duration(
      seconds: photoSeconds.clamp(1, _photoMusicMaxSeconds),
    );

    for (var i = 0; i < results.length; i++) {
      final isVideo = i < _states.length ? _states[i].isVideo : false;
      if (isVideo) continue;
      final file = results[i];
      try {
        final withMusic = await NativeVideoProcessor.renderImageWithMusic(
          file,
          audio: audio,
          duration: photoDuration,
          startOffset: _soundStartOffset,
        );
        if (withMusic != null) results[i] = withMusic;
      } catch (e, st) {
        debugPrint('Music bake failed for ${file.path}: $e\n$st');
      }
    }
  }

  Future<void> _silenceStudioPreviewForRender() async {
    await SoundAudioPreview.stop();
    unawaited(_templateGpuPreview?.pause() ?? Future<void>.value());
    _templateLivePreview?.pause();
  }

  Future<void> _finishAsPost({
    required bool asStory,
    bool continueProcessing = false,
  }) async {
    if (_isProcessing && !continueProcessing) return;
    await _silenceStudioPreviewForRender();
    if (!continueProcessing || !_isProcessing) {
      setState(() {
        _isProcessing = true;
        if (_usesCatalogTemplate) {
          _templateExportProgress = 0;
          _templateExportLabel = 'Rendering';
        } else {
          _templateExportProgress = null;
          _templateExportLabel = null;
        }
      });
    }

    try {
      // Persist editable project before any export/handoff.
      await _templateProject?.saveDraftNow();
      if (_templateProject != null) {
        final durable = await _templateProject!.resolveSlotFiles();
        if (durable.isNotEmpty) {
          _templateSourceFiles = durable;
        }
      }

      // Slot fill needs the original stills; the post body uses the rendered
      // template video when present.
      if (_usesCatalogTemplate && _templateSourceFiles.isEmpty) {
        // Preserve whatever we still have before any late re-render.
        _templateSourceFiles = _states
            .map((s) => s.sourceFile)
            .toList(growable: false);
      }

      // Templates always need a server exportUrl (never an on-device bake).
      if (_usesCatalogTemplate) {
        final hasServer =
            (_templateServerExportUrl?.trim().isNotEmpty ?? false);
        if (!hasServer) {
          final ok = await _exportTemplateForNext();
          if (!mounted) return;
          if (!ok) {
            setState(() {
              _isProcessing = false;
              _templateExportProgress = null;
              _templateExportLabel = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.templateExportFailed,
                ),
              ),
            );
            return;
          }
        } else {
          _reportTemplateExportProgress(1, label: 'Done');
        }
      }

      final slotFiles = _templateSourceFiles.isNotEmpty
          ? List<File>.from(_templateSourceFiles)
          : await _exportAll();
      if (!mounted) return;
      final renderedHandoff = (_usesCatalogTemplate || _templatePreviewFile != null)
          ? await _handoffTemplatePreviewFile()
          : null;
      if (!mounted) return;

      final hasServerUrl = _templateServerExportUrl?.trim().isNotEmpty ?? false;
      if (_usesCatalogTemplate &&
          renderedHandoff == null &&
          !hasServerUrl) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _templateExportProgress = null;
            _templateExportLabel = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.templateHandoffFailed,
              ),
            ),
          );
        }
        return;
      }

      final postFiles = renderedHandoff != null
          ? <File>[renderedHandoff]
          : slotFiles;
      final postType = (_usesCatalogTemplate || renderedHandoff != null)
          ? 'VIDEO'
          : MediaGalleryImportFlow.resolvePostType(slotFiles);

      if (widget.popOnDone) {
        context.pop(
          MediaStudioExportResult(
            // Display / post body: rendered template VIDEO when present.
            // Slot stills stay in [templateSlotFiles] for UserProjectSlot PATCH.
            files: postFiles,
            filterName: _filterNameForPost(),
            filterCategory: primaryFilterCategoryFromStates(_states),
            effectSlug: primaryEffectSlugFromStates(_states),
            beautyEnabled: _states.any((s) => s.beautyEnabled),
            arFilterId: primaryArFilterIdFromStates(_states),
            sound: _selectedSound,
            soundOffset: _soundStartOffset,
            soundWindow: _soundWindow,
            soundDidTrim: _soundDidTrim,
            soundSegmentId: _pickedSoundSegmentId,
            videoTemplateId: _videoTemplateId,
            videoTemplateName: _videoTemplateName,
            videoTemplateSlotCount: _videoTemplateSlotCount,
            templateProjectId: _templateProjectId,
            templateRenderedVideo: renderedHandoff,
            templateSlotFiles: _templateSourceFiles.isNotEmpty
                ? _templateSourceFiles
                : null,
            templateServerExportUrl: _templateServerExportUrl,
            templateClientExportQuality: renderedHandoff != null
                ? _templateClientExportQuality
                : null,
          ),
        );
        return;
      }

      final goStory = asStory || widget.isStory;
      if (goStory) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => StoryCameraEditor(
              file: postFiles.first,
              type: renderedHandoff != null ? 'VIDEO' : widget.items.first.type,
              sound: _selectedSound,
              soundOffset: _soundStartOffset,
              soundWindow: _soundWindow,
              soundDidTrim: _soundDidTrim,
              soundSegmentId: _pickedSoundSegmentId,
              onRetake: () => context.pop(),
            ),
          ),
        );
        return;
      }

      context.pushReplacementNamed(
        'add_post',
        extra: {
          // Composer shows / posts the rendered video; slot stills travel
          // alongside for UserProjectSlot PATCH.
          'files': postFiles,
          'type': postType,
          'isStory': false,
          'initialSound': _selectedSound,
          'initialSoundOffset': _soundStartOffset,
          'initialSoundWindow': _soundWindow,
          'initialSoundDidTrim': _soundDidTrim,
          'initialSoundSegmentId': _pickedSoundSegmentId,
          'filterName': _filterNameForPost(),
          'filterCategory': primaryFilterCategoryFromStates(_states).name,
          'effectSlug': primaryEffectSlugFromStates(_states),
          'beautyEnabled': _states.any((s) => s.beautyEnabled),
          'arFilterId': primaryArFilterIdFromStates(_states),
          if (_usesCatalogTemplate) 'videoTemplateId': _videoTemplateId,
          if (_videoTemplateName != null)
            'videoTemplateName': _videoTemplateName,
          if (_videoTemplateSlotCount != null)
            'videoTemplateSlotCount': _videoTemplateSlotCount,
          if (_templateProjectId != null)
            'templateProjectId': _templateProjectId,
          if (renderedHandoff != null) 'templateRenderedVideo': renderedHandoff,
          if (_templateSourceFiles.isNotEmpty)
            'templateSlotFiles': _templateSourceFiles,
          if (_templateServerExportUrl != null)
            'templateServerExportUrl': _templateServerExportUrl,
          if (renderedHandoff != null && _templateClientExportQuality != null)
            'templateClientExportQuality': _templateClientExportQuality,
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _templateExportProgress = null;
          _templateExportLabel = null;
        });
      }
    }
  }

  Future<void> _onNext() async {
    if (_usesCatalogTemplate) {
      await _confirmTemplatePreviewAndPost(asStory: false);
      return;
    }
    await _finishAsPost(asStory: false);
  }

  Future<void> _onYourStory() async {
    if (_usesCatalogTemplate) {
      await _confirmTemplatePreviewAndPost(asStory: true);
      return;
    }
    await _finishAsPost(asStory: true);
  }

  Future<void> _confirmTemplatePreviewAndPost({required bool asStory}) async {
    // Next → server draft export only (no on-device bake).
    if (_usesCatalogTemplate) {
      await _silenceStudioPreviewForRender();
      if (mounted) {
        setState(() {
          _isProcessing = true;
          _templateExportProgress = 0;
          _templateExportLabel = 'Rendering';
        });
      }

      if (_templateSourceFiles.isEmpty) {
        _templateSourceFiles = _states
            .map((s) => s.sourceFile)
            .toList(growable: false);
      }

      final ok = await _exportTemplateForNext();
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _isProcessing = false;
          _templateExportProgress = null;
          _templateExportLabel = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.templateExportFailed),
          ),
        );
        return;
      }

      _disposeLiveTemplatePreview();

      final preview = _templatePreviewFile;
      if (preview != null && await preview.exists()) {
        // Muxed export audio only — drop the soft-preview bed.
        await SoundAudioPreview.stop();
        setState(() {
          _states = [
            MediaItemEditState(
              item: GalleryMediaItem(file: preview, type: 'VIDEO'),
            ),
          ];
          _currentIndex = 0;
          _previewEpoch++;
          _studioMediaReady = false;
          _smoothPreviewFile = null;
          _applyStateToUi(_states[0]);
        });
      }
      if (mounted) {
        await _finishAsPost(asStory: asStory, continueProcessing: true);
      }
      return;
    } else {
      _disposeLiveTemplatePreview();
    }

    await _finishAsPost(asStory: asStory);
  }

  void _reportTemplateExportProgress(double progress, {String? label}) {
    if (!mounted) return;
    final next = progress.clamp(0.0, 1.0);
    final prev = _templateExportProgress;
    // Avoid noisy rebuilds for sub-1% ticks.
    if (prev != null && (next - prev).abs() < 0.01 && label == null) return;
    setState(() {
      _templateExportProgress = next;
      if (label != null && label.isNotEmpty) {
        _templateExportLabel = label;
      }
    });
  }

  /// Forced policy: server export only (quality=draft). No on-device render.
  Future<bool> _exportTemplateForNext() async {
    final recipe = _templateRecipe ?? await _ensureTemplateRecipe();
    if (recipe == null) return false;
    _templateRecipe = recipe;

    // Drop any prior client bake so Next never ships an on-device MP4.
    _templatePreviewFile = null;
    _templateClientExportQuality = null;
    _templateServerExportUrl = null;

    debugPrint(
      'Next export: server quality=standard '
      '(preferredPath=${recipe.renderHints.preferredPath} '
      'complexity=${recipe.renderHints.complexity})',
    );

    return _exportTemplateOnServer(exportQuality: 'standard');
  }

  Future<bool> _exportTemplateOnClient({
    bool allowServerFallback = false,
  }) async {
    // Prefer server; optional client path via Apply allowClientFallback.
    debugPrint('Client template export → server with fallback');
    if (allowServerFallback) {
      return _exportTemplateOnServer(exportQuality: 'standard');
    }
    return false;
  }

  /// Upload media + one-shot server render (same path as template Edit → Finish).
  Future<bool> _exportTemplateOnServer({
    String exportQuality = 'standard',
  }) async {
    final sources = _templateSourceFiles.isNotEmpty
        ? _templateSourceFiles
        : _states.map((s) => s.sourceFile).toList(growable: false);
    if (sources.isEmpty) return false;

    var recipe = _templateRecipe ?? await _ensureTemplateRecipe();
    if (recipe == null) return false;

    if (_selectedSound != null) {
      recipe = _recipeWithStudioSound(recipe, _selectedSound!);
    }
    _templateRecipe = recipe;

    final videoHints = _videoHintsForFiles(sources);
    final engine = vt_di.sl<TemplateCompositionEngine>();
    final session = engine.open(
      recipe,
      projectId: VideoTemplateProjectIds.normalizeServerId(_templateProjectId),
    );
    final slotEngine = SlotEngine(recipe: recipe);
    var fills = slotEngine.fillsFromFiles(sources, isVideoHints: videoHints);
    fills = await _applyVideoTrimsToFills(
      fills: fills,
      slots: slotEngine.slots,
    );
    fills = slotEngine.applyBeatSyncTrims(fills);
    session.fills = fills;
    // Same as Edit: seed recipe filters / effects / transitions / text / stickers.
    session.seedDefaultsFromRecipe();

    final sound = _selectedSound ?? recipe.effectivePreviewSound;
    if (sound != null) {
      session.setUserSound(
        sound,
        soundSegmentId: _pickedSoundSegmentId ?? recipe.soundSegmentId,
        segmentStartMs: recipe.soundSegmentStartMs ?? 0,
        segmentEndMs: recipe.soundSegmentEndMs,
      );
    }

    final selection = VideoTemplateSelection(
      templateId: '',
      name: _videoTemplateName ?? recipe.name,
      projectId: VideoTemplateProjectIds.normalizeServerId(_templateProjectId),
      recipe: recipe,
      soundSegmentId: _pickedSoundSegmentId ?? recipe.soundSegmentId,
      sound: sound,
    );

    debugPrint(
      'Select template export → OneShotRender (same as Edit) '
      'slots=${session.slots.length} media=${sources.length}',
    );

    final applyResult = await vt_di.sl<OneShotRenderVideoTemplateUseCase>()(
      session: session,
      selection: selection,
      catalogTemplateId: null,
      exportQuality: exportQuality == 'draft' ? 'draft' : 'standard',
      resolution: recipe.width > 0 && recipe.height > 0
          ? '${recipe.width}x${recipe.height}'
          : '1080x1920',
      fps: recipe.fps > 0 ? recipe.fps.toDouble() : 30,
      onProgress: _reportTemplateExportProgress,
    );

    final applied = applyResult.fold<VideoTemplateApplyResult?>((f) {
      debugPrint('OneShot template export failed: ${f.message}');
      return null;
    }, (r) => r);
    if (applied == null) return false;

    _templateProjectId = applied.projectId;
    _templateRecipe = applied.recipe;

    final exportUrl = applied.serverExportUrl;
    if (exportUrl != null && exportUrl.isNotEmpty) {
      _templateServerExportUrl = exportUrl;
      _templateClientExportQuality = null;
      var local = applied.renderedVideo;
      try {
        if (local == null || !(await local.exists())) {
          _reportTemplateExportProgress(0.96, label: 'Downloading');
          local = await AppMediaCacheManager.downloadVideoFile(exportUrl);
        }
        if (local != null && await local.exists()) {
          _templatePreviewFile = local;
        }
        _reportTemplateExportProgress(1, label: 'Done');
      } catch (e, st) {
        debugPrint('Download server export preview: $e\n$st');
      }
      return true;
    }

    final rendered = applied.renderedVideo;
    if (rendered != null && await rendered.exists()) {
      _templatePreviewFile = rendered;
      _templateClientExportQuality = null;
      _reportTemplateExportProgress(1, label: 'Done');
      return true;
    }

    final failed = applied.export;
    debugPrint(
      'OneShot export incomplete: '
      '${failed?.stageLabel ?? failed?.status} '
      '${failed?.errorMessage ?? ''}',
    );
    return false;
  }

  /// Screenshot the on-screen template look → short MP4 for save/publish.
  Future<File?> _captureLiveTemplatePreviewAsVideo() async {
    try {
      // Ensure live look is visible (not a stale plain bake).
      if (_templateLivePreview == null) return null;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return null;

      final boundary =
          _templateCaptureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return null;

      final dir = await getTemporaryDirectory();
      final png = File(
        '${dir.path}/tpl_capture_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await png.writeAsBytes(byteData.buffer.asUint8List());

      final recipe = _templateRecipe;
      final holdSec = recipe?.slots.isNotEmpty == true
          ? recipe!.slots.first.resolvedDurationSeconds
          : (recipe?.duration ?? 3);
      final hold = Duration(
        milliseconds: ((holdSec > 0 ? holdSec : 3) * 1000).round().clamp(
          800,
          8000,
        ),
      );
      return NativeVideoProcessor.imageToVideo(png, duration: hold);
    } catch (e, st) {
      debugPrint('Capture live template preview: $e\n$st');
      return null;
    }
  }

  /// Last-resort: bake preview look onto the first still → short MP4.
  Future<File?> _bakeLookedStillAsVideo() async {
    final recipe = await _ensureTemplateRecipe();
    final sources = _templateSourceFiles.isNotEmpty
        ? _templateSourceFiles
        : _states.map((s) => s.sourceFile).toList(growable: false);
    if (recipe == null || sources.isEmpty) return null;
    try {
      final slot = recipe.slots.isNotEmpty ? recipe.slots.first : null;
      final looked = await TemplateLookBaker.bakeImageFile(
        input: sources.first,
        recipe: recipe,
        slot: slot,
        allSources: sources,
      );
      if (looked == null) return null;
      final hold = Duration(
        milliseconds: ((slot?.resolvedDurationSeconds ?? 3) * 1000)
            .round()
            .clamp(800, 8000),
      );
      return NativeVideoProcessor.imageToVideo(looked, duration: hold);
    } catch (e, st) {
      debugPrint('Looked still fallback: $e\n$st');
      return null;
    }
  }

  Future<VideoTemplateRecipeEntity?> _ensureTemplateRecipe() async {
    var recipe = _templateRecipe;
    if (recipe != null &&
        (recipe.slots.isNotEmpty ||
            recipe.slotCount > 0 ||
            recipe.isPhotoCarousel)) {
      return recipe;
    }
    if (_videoTemplateId == null) return null;
    final fetched = await vt_di.sl<GetVideoTemplateRecipeUseCase>()(
      _videoTemplateId!,
      includeOverlays: true,
    );
    recipe = fetched.fold((_) => null, (r) => r);
    if (recipe != null) _templateRecipe = recipe;
    return recipe;
  }

  bool _isVideoPath(File file) {
    final p = file.path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.m4v') ||
        p.endsWith('.webm') ||
        p.endsWith('.mkv');
  }

  /// Builds the recipe slideshow/video. Returns null on failure.
  Future<File?> _renderTemplateVideo({
    TemplateClientExportQuality quality = TemplateClientExportQuality.draft,
    void Function(double progress)? onProgress,
  }) async {
    // Disabled — IMAGE/VIDEO templates never encode on device.
    debugPrint('On-device template render blocked (server-only policy)');
    return null;
  }

  void _toggleBeauty() {
    setState(() {
      if (_arFilterId == 'whitening') {
        _arFilterId = 'none';
        _magicOn = false;
      } else {
        _arFilterId = 'whitening';
        _arColorCategoryId = 'beauty';
        _magicOn = true;
        if (!_preserveNeutralAdjustments) {
          _adjustments.addAll(_magicBeautyDefaults);
        }
        _showFilters = false;
      }
      _saveUiToCurrentState();
    });
  }

  void _applyPhotoBeautyLook() {
    // Magic = brighten/beauty grade only. Smooth = separate skin-clear pass.
    if (_magicOn) {
      _arFilterId = 'whitening';
      _arColorCategoryId = 'beauty';
      _arFilterIntensity = 0.8;
    } else if (_arFilterId == 'whitening') {
      _arFilterId = 'none';
      _arFilterIntensity = 1.0;
    }
    _saveUiToCurrentState();
  }

  void _togglePhotoEditor(AppLocalizations l10n) {
    if (_currentState.isVideo) {
      _showComingSoon(l10n);
      return;
    }
    setState(() {
      if (_showPhotoEditor) {
        _showPhotoEditor = false;
        return;
      }
      _showPhotoEditor = true;
      _showFilters = false;
      _showTemplateSelector = false;
      if (_arFilterId == 'whitening') {
        _magicOn = true;
      }
    });
  }

  void _onMagicToggled() {
    setState(() {
      _magicOn = !_magicOn;
      if (_magicOn) {
        if (!_preserveNeutralAdjustments) {
          _adjustments.addAll(_magicBeautyDefaults);
        }
        _photoEditorTool = MediaPhotoEditorTool.smooth;
      } else {
        _photoEditorTool = MediaPhotoEditorTool.magic;
      }
      _applyPhotoBeautyLook();
    });
    _scheduleFacePreview();
  }

  void _onPhotoEditorToolSelected(MediaPhotoEditorTool tool) {
    setState(() => _photoEditorTool = tool);
  }

  void _onAdjustmentChanged(MediaPhotoEditorTool tool, double value) {
    _adjustments[tool] = value;
    _saveUiToCurrentState();
    if (mounted) setState(() {});
    _scheduleFacePreview();
  }

  void _scheduleFacePreview() {
    _smoothDebounce?.cancel();
    if (!_hasPreviewEdits) {
      _clearFacePreview();
      return;
    }
    // Wait until finger settles a bit — full OpenCV on every tick never finishes.
    _smoothDebounce = Timer(const Duration(milliseconds: 120), () {
      unawaited(_rebuildFacePreview());
    });
  }

  void _clearFacePreview() {
    final old = _smoothPreviewFile;
    _smoothPreviewFile = null;
    if (old != null) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _deleteTemp(File? file, File source) {
    if (file == null || file.path == source.path) return;
    try {
      file.deleteSync();
    } catch (_) {}
  }

  /// Builds the live preview file natively: tone/geometry adjustments
  /// (OpenCV), then the selected filter's color grade (also OpenCV — see
  /// _bakeColorFilterToFile). Both run on Kotlin — no Flutter matrix (that
  /// path is video-only, see MediaStudioPreview's applyArColorPreview).
  Future<void> _rebuildFacePreview() async {
    if (_currentState.isVideo || !_hasPreviewEdits) {
      _clearFacePreview();
      return;
    }
    final gen = ++_smoothGen;
    final source = _currentState.sourceFile;
    var working = source;
    var produced = false;

    if (_hasFaceEdits) {
      final adjusted = await MediaSkinSmooth.apply(
        input: working,
        saturation: _adj(MediaPhotoEditorTool.saturation),
        brightness: _adj(MediaPhotoEditorTool.brightness),
        contrast: _adj(MediaPhotoEditorTool.contrast),
        exposure: _adj(MediaPhotoEditorTool.exposure),
        whiteBalance: _adj(MediaPhotoEditorTool.whiteBalance),
        highlights: _adj(MediaPhotoEditorTool.highlights),
        shadows: _adj(MediaPhotoEditorTool.shadows),
        nose: _adj(MediaPhotoEditorTool.nose),
        // Fast live preview. Export uses full resolution (no maxEdge).
        maxEdge: 960,
      );
      if (gen != _smoothGen) {
        _deleteTemp(adjusted, source);
        return;
      }
      if (adjusted != null) {
        working = adjusted;
        produced = true;
      }
    }

    if (!mounted || gen != _smoothGen) {
      if (produced) _deleteTemp(working, source);
      return;
    }

    if (_needsColorFilterPreview) {
      final beforeGrade = working;
      final graded = await _bakeColorFilterToFile(
        beforeGrade,
        _arFilterId,
        _arFilterIntensity,
      );
      if (!mounted || gen != _smoothGen) {
        if (produced) _deleteTemp(beforeGrade, source);
        if (graded.path != beforeGrade.path) _deleteTemp(graded, source);
        return;
      }
      if (graded.path != beforeGrade.path) {
        if (produced) _deleteTemp(beforeGrade, source);
        working = graded;
        produced = true;
      }
    }

    if (!produced) {
      // Native step(s) failed — keep last good preview, don't blank the image.
      return;
    }
    final previous = _smoothPreviewFile;
    setState(() => _smoothPreviewFile = working);
    if (previous != null && previous.path != working.path) {
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        try {
          previous.deleteSync();
        } catch (_) {}
      });
    }
  }

  void _resetPhotoEditor() {
    _smoothDebounce?.cancel();
    _smoothGen++;
    setState(() {
      _magicOn = false;
      for (final key in _adjustments.keys) {
        _adjustments[key] = 0.0;
      }
      _arFilterIntensity = 0.0;
      _preserveNeutralAdjustments = true;
      _photoEditorTool = MediaPhotoEditorTool.magic;
      // Clear Makeup Film grade if one is applied.
      if (ArFilterCatalog.isColorFilter(_arFilterId)) {
        _arFilterId = 'none';
      }
      _applyPhotoBeautyLook();
      _saveUiToCurrentState();
    });
    _clearFacePreview();
  }

  void _selectArFilter(String id) {
    setState(() {
      _arFilterId = id;
      if (ArFilterCatalog.isColorFilter(id)) {
        // Keep retouch sheet open when picking Film grades from Makeup.
        if (_showPhotoEditor) {
          _arColorCategoryId = 'beauty';
        } else {
          _showPhotoEditor = false;
        }
      }
      _saveUiToCurrentState();
    });
    // Rebuild the native LUT-baked preview for the newly selected grade (photos).
    if (!_currentState.isVideo) {
      if (_hasPreviewEdits) {
        _scheduleFacePreview();
      } else {
        _clearFacePreview();
      }
    }
  }

  void _onMakeupFilmFilterSelected(String id) {
    setState(() {
      _arFilterId = id;
      if (id == 'none') {
        // Keep category for Makeup UI; clear only the grade.
      } else {
        _arColorCategoryId = 'beauty';
        _arFilterIntensity = 0.50;
        _magicOn = false;
      }
      _saveUiToCurrentState();
    });
    if (!_currentState.isVideo) {
      if (_hasPreviewEdits) {
        _scheduleFacePreview();
      } else {
        _clearFacePreview();
      }
    }
  }

  Future<void> _pickSound() async {
    final hasVideo = _states.any((s) => s.isVideo);
    // Pause the studio video while the sound picker / trimmer is open.
    setState(() => _subEditorOpen = true);
    await _syncStudioSoundPreview();
    if (!mounted) return;

    SoundPickResult? picked;
    try {
      picked = await SoundPickerSheet.show(
        context,
        initialSelection: _selectedSound,
        initialOffset: _soundStartOffset,
        initialWindow: _soundWindow,
        allowMuteOnTrim: hasVideo,
      );
    } catch (_) {
      picked = null;
    }
    if (!mounted) return;
    await SoundAudioPreview.stop();
    // Let modal / trim audio fully tear down before remounting video.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    setState(() {
      _subEditorOpen = false;
      // Fresh VideoPlayer — recovers if a prior ExoPlayer surface froze.
      _previewEpoch++;
      _studioMediaReady = false;
      if (picked == null) return;
      if (picked.cleared) {
        _selectedSound = null;
        _soundStartOffset = Duration.zero;
        _soundWindow = const Duration(seconds: 15);
        _muteOriginalAudio = false;
        _soundDidTrim = false;
        _pickedSoundSegmentId = null;
        return;
      }
      final sound = picked.sound;
      if (sound == null) return;
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

    // Persist audio choice into the editable template draft (debounced).
    if (_templateProject != null) {
      if (_selectedSound == null) {
        _templateProject!.setAudio(null);
      } else {
        _templateProject!.setAudio(
          UserProjectAudioDraft(
            soundId: _selectedSound!.id,
            soundSegmentId: _pickedSoundSegmentId,
            volume: 1,
            startMs: _soundStartOffset.inMilliseconds,
            endMs: (_soundStartOffset + _soundWindow).inMilliseconds,
          ),
        );
      }
    }

    // Warm the track in disk cache (photo→music export / preview).
    final selected = _selectedSound;
    final prefetchUrl = selected?.resolvedAudioUrl;
    if (prefetchUrl != null && prefetchUrl.isNotEmpty) {
      unawaited(SoundLocalFile.resolve(prefetchUrl));
    }

    // Remount clears readiness — bed starts from MediaStudioPreview.onReady.
    unawaited(_syncStudioSoundPreview());
  }

  void _clearSound() {
    setState(() {
      _selectedSound = null;
      _soundStartOffset = Duration.zero;
      _soundWindow = const Duration(seconds: 15);
      _muteOriginalAudio = false;
      _soundDidTrim = false;
      _pickedSoundSegmentId = null;
    });
    _templateProject?.setAudio(null);
    unawaited(_syncStudioSoundPreview());
  }

  Future<void> _shareCurrent() async {
    final file = _currentState.sourceFile;
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  void _showComingSoon(AppLocalizations l10n) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.mediaEditorComingSoon)));
  }

  /// TikTok-style timeline editor — Edit opens this directly (no template sheet).
  Future<void> _openTemplateTimelineEditor() async {
    if (_isProcessing || _states.isEmpty) return;
    _saveUiToCurrentState();

    final sources = _templateSourceFiles.isNotEmpty
        ? List<File>.from(_templateSourceFiles)
        : _states.map((s) => s.sourceFile).toList(growable: false);

    final videoHints = _videoHintsForFiles(sources);
    final singleVideo =
        sources.length == 1 && _isVideoSource(sources, videoHints);

    if (!_usesCatalogTemplate) {
      _disposeLiveTemplatePreview();
    }

    late VideoTemplateRecipeEntity recipe;
    if (_usesCatalogTemplate && !singleVideo) {
      final catalog =
          _templateRecipe ?? await _ensureTemplateRecipe();
      recipe = catalog ??
          await _localGalleryRecipe(sources, videoHints: videoHints);
    } else if (singleVideo) {
      recipe = await _localSingleClipRecipe(sources, videoHints: videoHints);
    } else {
      recipe = await _localGalleryRecipe(sources, videoHints: videoHints);
    }

    if (_selectedSound != null) {
      recipe = _recipeWithStudioSound(recipe, _selectedSound!);
    }

    if (!mounted) return;

    final slotEngine = SlotEngine(recipe: recipe);
    var fills = slotEngine.fillFromFiles(sources, isVideoHints: videoHints);
    fills = await _applyVideoTrimsToFills(
      fills: fills,
      slots: slotEngine.slots,
    );
    fills = slotEngine.applyBeatSyncTrims(fills);

    var projectId = _usesCatalogTemplate
        ? VideoTemplateProjectIds.normalizeServerId(_templateProjectId)
        : null;
    final catalogTemplateIdForRender = _usesCatalogTemplate
        ? VideoTemplateProjectIds.normalizeServerId(_videoTemplateId)
        : null;

    _templateRecipe = recipe;
    _templateSourceFiles = sources;

    setState(() => _subEditorOpen = true);
    await SoundAudioPreview.stop();
    _templateLivePreview?.pause();

    final selection = VideoTemplateSelection.fromRecipe(recipe).copyWith(
      projectId: projectId,
      name: _videoTemplateName ?? recipe.name,
      templateId: catalogTemplateIdForRender ?? '',
    );

    if (!mounted) return;
    final result = await Navigator.of(context)
        .push<VideoTemplateEditorFinishResult>(
          MaterialPageRoute(
            builder: (_) => VideoTemplateEditorScreen(
              recipe: recipe,
              initialSelection: selection,
              initialFills: fills,
              projectId: projectId,
              catalogTemplateId: catalogTemplateIdForRender,
            ),
          ),
        );

    if (!mounted) return;
    setState(() => _subEditorOpen = false);
    unawaited(_syncStudioSoundPreview());

    if (result == null) return;

    final sel = result.selection;
    _templateProjectId =
        VideoTemplateProjectIds.normalizeServerId(sel.projectId) ??
        _templateProjectId;
    final nextRecipe = sel.recipe;
    if (nextRecipe != null) {
      _templateRecipe = nextRecipe;
    }
    final sound = sel.sound ?? nextRecipe?.effectivePreviewSound;
    setState(() {
      _selectedSound = sound;
      _pickedSoundSegmentId = sel.soundSegmentId;
      if (sound != null) {
        final startMs = nextRecipe?.soundSegmentStartMs ?? 0;
        final endMs = nextRecipe?.soundSegmentEndMs;
        _soundStartOffset = Duration(milliseconds: startMs.clamp(0, 3600000));
        if (endMs != null && endMs > startMs) {
          _soundWindow = Duration(milliseconds: endMs - startMs);
        }
      } else {
        _soundStartOffset = Duration.zero;
        _soundWindow = const Duration(seconds: 15);
        _pickedSoundSegmentId = null;
      }
    });
    if (_templateProject != null) {
      if (sound == null) {
        _templateProject!.setAudio(null);
      } else {
        _templateProject!.setAudio(
          UserProjectAudioDraft(
            soundId: sound.id,
            soundSegmentId: _pickedSoundSegmentId,
            volume: 1,
            startMs: _soundStartOffset.inMilliseconds,
            endMs: (_soundStartOffset + _soundWindow).inMilliseconds,
          ),
        );
      }
    }

    // Apply → backend render finished: local preview in studio (before post).
    if (result.proceedToNext) {
      final file = result.renderedFile;
      final url = result.serverExportUrl?.trim();
      // Gallery-style edited export — do not tag post/render with catalog id.
      _catalogTemplateApplied = false;
      _videoTemplateId = null;
      // Keep export URL for post handoff only — preview uses the local MP4.
      if (url != null && url.isNotEmpty) {
        _templateServerExportUrl = url;
      }

      // Drop live compositor — preview uses the rendered file only.
      _templateGpuPreview?.dispose();
      _templateGpuPreview = null;
      _templateLivePreview?.dispose();
      _templateLivePreview = null;
      await SoundAudioPreview.stop();

      File? previewFile = file;
      if ((previewFile == null || !(await previewFile.exists())) &&
          url != null &&
          url.isNotEmpty) {
        try {
          previewFile = await AppMediaCacheManager.downloadVideoFile(url);
        } catch (_) {}
      }

      if (previewFile != null && await previewFile.exists()) {
        _templatePreviewFile = previewFile;
        _templatePreviewHandedOff = false;
        if (!mounted) return;
        setState(() {
          _showTemplateSelector = false;
          _states = [
            MediaItemEditState(
              item: GalleryMediaItem(file: previewFile!, type: 'VIDEO'),
            ),
          ];
          _currentIndex = 0;
          _previewEpoch++;
          _studioMediaReady = false;
          _smoothPreviewFile = null;
          _applyStateToUi(_states[0]);
          _isProcessing = false;
          _templateApplying = false;
          _templateExportProgress = 1;
          _templateExportLabel = 'Preview ready';
        });
      }
      return;
    }

    if (_usesCatalogTemplate) {
      await _openTemplateAppliedPreview(
        recipeOverride: nextRecipe ?? _templateRecipe,
        sourceOverride: sources,
      );
    } else {
      _disposeLiveTemplatePreview();
      if (mounted) setState(() {});
    }
    unawaited(_syncStudioSoundPreview());
  }

  /// Gallery / free-edit recipe — one slot per picked file, no catalog layout.
  Future<VideoTemplateRecipeEntity> _localGalleryRecipe(
    List<File> sources, {
    required List<bool> videoHints,
  }) async {
    if (sources.length == 1) {
      return _localSingleClipRecipe(sources, videoHints: videoHints);
    }

    final slots = <VideoTemplateSlotEntity>[];
    var totalDuration = 0.0;
    for (var i = 0; i < sources.length; i++) {
      final file = sources[i];
      final hintedVideo =
          i < videoHints.length && videoHints[i] ||
          VideoThumbnailUtils.isVideoFile(file);
      final slotType = hintedVideo
          ? TemplateSlotMediaTypes.video
          : TemplateSlotMediaTypes.image;
      var durationSec = hintedVideo ? 5.0 : 3.0;
      if (hintedVideo) {
        durationSec = await _effectiveVideoEditDurationSeconds(file);
      }
      totalDuration += durationSec;
      slots.add(
        VideoTemplateSlotEntity(
          id: 'local_slot_$i',
          slotIndex: i,
          type: slotType,
          acceptedTypes: const [
            TemplateSlotMediaTypes.image,
            TemplateSlotMediaTypes.video,
          ],
          durationSeconds: durationSec,
        ),
      );
    }

    return VideoTemplateRecipeEntity(
      id: 'local_edit',
      name: _videoTemplateName ?? 'Edit',
      templateKind: VideoTemplateKinds.photoCarousel,
      primarySlotType: TemplateSlotMediaTypes.image,
      slotCount: slots.length,
      duration: totalDuration.clamp(1, 600),
      slots: slots,
    );
  }

  /// Fallback recipe so Edit can open without picking a template first.
  Future<VideoTemplateRecipeEntity> _localSingleClipRecipe(
    List<File> sources, {
    required List<bool> videoHints,
  }) async {
    final isVideo = _isVideoSource(sources, videoHints);
    final slotType = isVideo
        ? TemplateSlotMediaTypes.video
        : TemplateSlotMediaTypes.image;
    var durationSec = isVideo ? 15.0 : 5.0;

    if (isVideo && sources.isNotEmpty) {
      durationSec = await _effectiveVideoEditDurationSeconds(sources.first);
    }

    const slotId = 'local_slot_0';
    return VideoTemplateRecipeEntity(
      id: 'local_edit',
      name: _videoTemplateName ?? 'Edit',
      templateKind: isVideo
          ? VideoTemplateKinds.video
          : VideoTemplateKinds.photoCarousel,
      primarySlotType: slotType,
      slotCount: 1,
      duration: durationSec,
      slots: [
        VideoTemplateSlotEntity(
          id: slotId,
          slotIndex: 0,
          type: slotType,
          acceptedTypes: const [
            TemplateSlotMediaTypes.image,
            TemplateSlotMediaTypes.video,
          ],
          durationSeconds: durationSec,
        ),
      ],
    );
  }

  bool _isVideoSource(List<File> sources, List<bool> videoHints) {
    if (sources.isEmpty) return false;
    if (videoHints.isNotEmpty && videoHints.first) return true;
    if (_states.length == 1 && _states.first.isVideo) return true;
    return VideoThumbnailUtils.isVideoFile(sources.first);
  }

  Future<double> _probeVideoDurationSeconds(File file) async {
    try {
      final meta = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(file),
      );
      return (meta.duration.inMilliseconds / 1000.0).clamp(0.5, 600.0);
    } catch (e) {
      debugPrint('Video duration probe failed: $e');
      return 15.0;
    }
  }

  /// Timeline length for a video clip (respects studio trim segments when set).
  Future<double> _effectiveVideoEditDurationSeconds(File file) async {
    final fullSec = await _probeVideoDurationSeconds(file);
    for (final state in _states) {
      if (state.sourceFile.path != file.path &&
          state.item.file.path != file.path) {
        continue;
      }
      if (state.trimSegments.isEmpty) return fullSec;
      return state.trimSegments
          .fold<double>(
            0,
            (sum, seg) => sum + seg.duration.inMilliseconds / 1000.0,
          )
          .clamp(0.5, 600.0);
    }
    return fullSec;
  }

  Future<Map<String, SlotFillEntry>> _applyVideoTrimsToFills({
    required Map<String, SlotFillEntry> fills,
    required List<VideoTemplateSlotEntity> slots,
  }) async {
    final out = Map<String, SlotFillEntry>.from(fills);
    for (final slot in slots) {
      final fill = out[slot.id];
      if (fill == null || !fill.hasMedia || !fill.isLocalVideo) continue;
      final file = fill.localFile;
      if (file == null) continue;

      final fullSec = await _probeVideoDurationSeconds(file);
      var trimStart = 0.0;
      var trimEnd = fullSec;

      for (final state in _states) {
        if (state.sourceFile.path != file.path &&
            state.item.file.path != file.path) {
          continue;
        }
        if (state.trimSegments.isNotEmpty) {
          final seg = state.trimSegments.first;
          trimStart = seg.start.inMilliseconds / 1000.0;
          trimEnd = seg.end.inMilliseconds / 1000.0;
        }
        break;
      }

      out[slot.id] = fill.copyWith(
        trimStart: trimStart,
        trimEnd: trimEnd.clamp(trimStart + 0.05, fullSec),
      );
    }
    return out;
  }

  VideoTemplateRecipeEntity _recipeWithStudioSound(
    VideoTemplateRecipeEntity recipe,
    SoundEntity sound,
  ) {
    return VideoTemplateRecipeEntity(
      id: recipe.id,
      name: recipe.name,
      templateKind: recipe.templateKind,
      primarySlotType: recipe.primarySlotType,
      allowedOutputs: recipe.allowedOutputs,
      slotCount: recipe.slotCount,
      coverUrl: recipe.coverUrl,
      previewVideoUrl: recipe.previewVideoUrl,
      duration: recipe.duration,
      width: recipe.width,
      height: recipe.height,
      fps: recipe.fps,
      version: recipe.version,
      versionInfo: recipe.versionInfo,
      useCount: recipe.useCount,
      categoryId: recipe.categoryId,
      category: recipe.category,
      musicId: recipe.musicId,
      music: recipe.music,
      soundId: sound.id,
      sound: sound,
      soundSegmentId: recipe.soundSegmentId,
      soundSegmentStartMs: recipe.soundSegmentStartMs,
      soundSegmentEndMs: recipe.soundSegmentEndMs,
      slots: recipe.slots,
      beatMap: recipe.beatMap,
      transitions: recipe.transitions,
      tracks: recipe.tracks,
      clips: recipe.clips,
      texts: recipe.texts,
      stickers: recipe.stickers,
      overlays: recipe.overlays,
      assets: recipe.assets,
      keyframes: recipe.keyframes,
      renderHints: recipe.renderHints,
    );
  }

  Future<void> _pickPhotoTemplate() async {
    if (_states.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.templateNeedMediaFirst),
        ),
      );
      return;
    }
    // Open selector on this screen — never push a browser/select route.
    setState(() {
      _showTemplateSelector = true;
      _templateSelectorMounted = true;
      _showFilters = false;
      _showPhotoEditor = false;
    });
  }

  Future<void> _clearSelectedTemplate() async {
    _templateApplyGen++;
    _disposeLiveTemplatePreview();
    unawaited(_templateProject?.saveDraftNow());
    _templateProject?.dispose();
    _templateProject = null;
    setState(() {
      _videoTemplateId = null;
      _videoTemplateName = null;
      _videoTemplateSlotCount = null;
      _catalogTemplateApplied = false;
      _templateProjectId = null;
      _templateRecipe = null;
      _templatePreviewFile = null;
      _templateServerExportUrl = null;
      _templateClientExportQuality = null;
      _templatePreviewHandedOff = false;
      _templateApplying = false;
    });
  }

  Future<void> _onTemplateSelectedFromPanel(
    VideoTemplateSelection picked,
  ) async {
    if (picked.templateId.isEmpty) {
      await _clearSelectedTemplate();
      return;
    }
    await _applyPhotoTemplate(picked);
  }

  Future<void> _applyPhotoTemplate(VideoTemplateSelection picked) async {
    if (_states.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.templateNeedMediaFirst),
        ),
      );
      return;
    }

    final applyGen = ++_templateApplyGen;
    _saveUiToCurrentState();
    if (mounted) {
      setState(() {
        _templateApplying = true;
        _studioMediaReady = false;
        _showTemplateSelector = true;
        _templateSelectorMounted = true;
        _showFilters = false;
        _showPhotoEditor = false;
      });
    }
    unawaited(SoundAudioPreview.stop());

    final need = VideoTemplateSlotFiller.slotsForSelection(
      slotCount: picked.slotCount,
      recipeApplySlotCount: picked.recipe?.applySlotCount,
    );

    // Photos and videos both fill template slots (same apply path).
    // Prefer ORIGINAL capture files for soft-preview — not durable project
    // copies — so we skip disk I/O on the critical path.
    final sources = _states
        .map((s) => s.sourceFile)
        .where((f) => f.path.isNotEmpty)
        .toList(growable: false);

    // Drop any previous bake so we rebuild for the new recipe.
    if (!_templatePreviewHandedOff) {
      try {
        _templatePreviewFile?.deleteSync();
      } catch (_) {}
    }

    // Detach previous durable project off the critical path.
    final previousProject = _templateProject;
    _templateProject = null;
    if (previousProject != null) {
      unawaited(() async {
        try {
          await previousProject.saveDraftNow();
        } catch (_) {}
        previousProject.dispose();
      }());
    }

    VideoTemplateRecipeEntity? recipe = picked.recipe;
    recipe ??= await _ensureTemplateRecipeForId(picked.templateId);
    if (!mounted || applyGen != _templateApplyGen) return;
    if (recipe == null) {
      setState(() => _templateApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.templateCouldNotLoad),
        ),
      );
      return;
    }

    // Update session ids — keep previous live look until attach swaps.
    _videoTemplateId = picked.templateId;
    _videoTemplateName = picked.name;
    _catalogTemplateApplied = true;
    _videoTemplateSlotCount = need;
    _templateProjectId = VideoTemplateProjectIds.normalizeServerId(
      picked.projectId,
    );
    _templateRecipe = recipe;
    _templateSourceFiles = sources;
    _templatePreviewFile = null;
    _templateServerExportUrl = null;
    _templateClientExportQuality = null;
    _templatePreviewHandedOff = false;
    _bindTemplateSound(
      recipe,
      preferred: picked.sound,
      preferredSegmentId: picked.soundSegmentId,
    );
    if (mounted) setState(() {});

    if (!mounted || applyGen != _templateApplyGen) return;

    // Soft live preview first (original files) — no project copy/save yet.
    // Music starts after attach inside [_openTemplateAppliedPreview].
    await _openTemplateAppliedPreview(
      recipeOverride: recipe,
      sourceOverride: sources,
    );
    if (!mounted || applyGen != _templateApplyGen) return;

    // Durable project + bake after the user already sees the look.
    unawaited(
      _persistTemplateProjectInBackground(
        picked: picked,
        recipe: recipe,
        sources: sources,
        applyGen: applyGen,
      ),
    );

    if (mounted && applyGen == _templateApplyGen) {
      setState(() => _templateApplying = false);
    }
  }

  /// Open local draft + import slot media after live preview is already shown.
  ///
  /// Ensures a server `UserTemplateProject` exists (`POST /projects`) so later
  /// slot PATCH / export never use a `local_*` client draft id.
  Future<void> _persistTemplateProjectInBackground({
    required VideoTemplateSelection picked,
    required VideoTemplateRecipeEntity recipe,
    required List<File> sources,
    required int applyGen,
  }) async {
    try {
      var serverProjectId = VideoTemplateProjectIds.normalizeServerId(
        picked.projectId,
      );
      final catalogTemplateId =
          VideoTemplateProjectIds.normalizeServerId(picked.templateId);
      if (serverProjectId == null) {
        if (catalogTemplateId == null) {
          debugPrint(
            'Background template project create skipped — '
            'templateId is not a UUID (got ${picked.templateId})',
          );
          return;
        }
        final created = await vt_di.sl<CreateVideoTemplateProjectUseCase>()(
          templateId: catalogTemplateId,
          title: picked.name.isNotEmpty ? picked.name : recipe.name,
        );
        if (!mounted || applyGen != _templateApplyGen) return;
        serverProjectId = created.fold<String?>((f) {
          debugPrint('Background template project create failed: ${f.message}');
          return null;
        }, (p) => VideoTemplateProjectIds.normalizeServerId(p.id));
      }

      final project = vt_di.sl<TemplateProjectController>();
      await project.openOrCreate(
        recipe: recipe,
        backendProjectId: serverProjectId,
        title: picked.name,
      );
      if (!mounted || applyGen != _templateApplyGen) {
        project.dispose();
        return;
      }
      if (serverProjectId != null && project.backendProjectId == null) {
        await project.bindServerProjectId(serverProjectId);
      }
      await project.assignSlotFiles(
        sources,
        isVideoHints: _videoHintsForFiles(sources),
      );
      if (picked.sound != null || picked.soundSegmentId != null) {
        project.setAudio(
          UserProjectAudioDraft(
            soundId: picked.sound?.id,
            soundSegmentId: picked.soundSegmentId,
            volume: 1,
            startMs: _soundStartOffset.inMilliseconds,
            endMs: (_soundStartOffset + _soundWindow).inMilliseconds,
          ),
        );
      }
      await project.saveDraftNow();
      if (!mounted || applyGen != _templateApplyGen) {
        project.dispose();
        return;
      }
      final resolved = await project.resolveSlotFiles();
      if (!mounted || applyGen != _templateApplyGen) {
        project.dispose();
        return;
      }
      _templateProject = project;
      // Only store server UUID — ApplyVideoTemplate creates one if still null.
      _templateProjectId = project.backendProjectId ?? serverProjectId;
      if (resolved.isNotEmpty) {
        _templateSourceFiles = resolved;
      }
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('Background template project persist failed: $e\n$st');
    }
  }

  Future<VideoTemplateRecipeEntity?> _ensureTemplateRecipeForId(
    String templateId,
  ) async {
    final fetched = await vt_di.sl<GetVideoTemplateRecipeUseCase>()(
      templateId,
      includeOverlays: true,
    );
    return fetched.fold((_) => null, (r) => r);
  }

  void _selectClip(int index) {
    if (index < 0 || index >= _states.length || index == _currentIndex) return;
    _saveUiToCurrentState();
    setState(() {
      _currentIndex = index;
      _smoothPreviewFile = null;
      _previewEpoch++;
      _studioMediaReady = false;
      _applyStateToUi(_states[_currentIndex]);
    });
    unawaited(SoundAudioPreview.stop());
    unawaited(_resolveMediaPixelSize());
  }

  Future<void> _openCrop(AppLocalizations l10n) async {
    if (_isProcessing) return;
    final state = _currentState;
    if (state.isVideo) {
      _showComingSoon(l10n);
      return;
    }
    final bytes = await state.sourceFile.readAsBytes();
    if (!mounted) return;
    await precacheImage(MemoryImage(bytes), context);
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<MediaCropResult>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => MediaCropScreen(imageBytes: bytes),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (cropped == null || !mounted) return;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(cropped.bytes);
    if (!mounted) return;

    final previous = _states[_currentIndex];
    final remapped = MediaTextLayout.remapForCrop(
      overlays: previous.textOverlays,
      sourceSize: cropped.sourceSize == Size.zero
          ? _mediaPixelSize
          : cropped.sourceSize,
      cropRect: cropped.cropRect,
      centerOf: (o) => o.center,
      copyWithCenter: (o, center) => o.copyWith(center: center),
    );

    setState(() {
      _states[_currentIndex] = previous.copyWith(
        croppedFile: file,
        textOverlays: remapped,
        effectSlug: previous.effectSlug,
      );
      _mediaPixelSizePath = null;
      _mediaPixelSize = Size.zero;
    });
    unawaited(_resolveMediaPixelSize());
    if (_hasPreviewEdits) _scheduleFacePreview();
  }

  Future<MediaTextOverlay?> _openTextEditor({MediaTextOverlay? initial}) async {
    // Opaque editor covers the studio — no parent setState needed (that rebuild
    // was the main reason Aa felt slow). We render the current media (photo or
    // video, with its active color grade) behind the editor so the background
    // stays visible instead of turning black while typing.
    final previewFile = (_smoothPreviewFile != null && _hasPreviewEdits)
        ? _smoothPreviewFile!
        : _currentState.sourceFile;
    final selectedColorId = _hasActiveColorFilter ? _arFilterId : 'none';
    final Widget background = MediaStudioPreview(
      file: previewFile,
      isVideo: _currentState.isVideo,
      arFilterId: selectedColorId,
      arFilterIntensity: _arFilterIntensity,
      applyArColorPreview: _currentState.isVideo
          ? _needsColorFilterPreview
          : false,
      muted: _currentState.isVideo,
      trimSegments: _currentState.isVideo
          ? _currentState.trimSegments
          : const [],
    );
    setState(() => _subEditorOpen = true);
    unawaited(_syncStudioSoundPreview());
    final result = await MediaTextEditorOverlay.show(
      context,
      initial: initial,
      background: background,
    );
    if (mounted) {
      setState(() => _subEditorOpen = false);
      unawaited(_syncStudioSoundPreview());
    }
    return result;
  }

  Future<void> _addText(AppLocalizations l10n) async {
    if (_isProcessing) return;
    final overlay = await _openTextEditor();
    if (overlay == null || !mounted) return;
    setState(() {
      final list = List<MediaTextOverlay>.from(_currentState.textOverlays)
        ..add(overlay);
      _states[_currentIndex] = _states[_currentIndex].copyWith(
        textOverlays: list,
        effectSlug: _states[_currentIndex].effectSlug,
      );
    });
  }

  Future<void> _editText(MediaTextOverlay overlay) async {
    final edited = await _openTextEditor(initial: overlay);
    if (!mounted) return;
    setState(() {
      final list = List<MediaTextOverlay>.from(_currentState.textOverlays);
      final idx = list.indexWhere((o) => o.id == overlay.id);
      if (idx < 0) return;
      if (edited == null) {
        list.removeAt(idx);
      } else {
        list[idx] = edited;
      }
      _states[_currentIndex] = _states[_currentIndex].copyWith(
        textOverlays: list,
        effectSlug: _states[_currentIndex].effectSlug,
      );
    });
  }

  void _moveOverlay(MediaTextOverlay overlay) {
    final list = List<MediaTextOverlay>.from(_currentState.textOverlays);
    final idx = list.indexWhere((o) => o.id == overlay.id);
    if (idx < 0) return;
    list[idx] = overlay;
    setState(() {
      _states[_currentIndex] = _states[_currentIndex].copyWith(
        textOverlays: list,
        effectSlug: _states[_currentIndex].effectSlug,
      );
    });
  }

  Future<void> _showSettingsSheet(AppLocalizations l10n) async {
    await GlassBottomSheet.showActions<void>(
      context,
      title: l10n.moreOptionsLabel,
      children: [
        GlassBottomSheetActionTile(
          icon: LucideIcons.sparkles,
          label: l10n.cameraBeauty,
          subtitle: _beautyEnabled ? l10n.settingsOn : l10n.settingsOff,
          isSelected: _beautyEnabled,
          onTap: () {
            Navigator.pop(context);
            _toggleBeauty();
          },
        ),
        GlassBottomSheetActionTile(
          icon: LucideIcons.blend,
          label: l10n.cameraFilters,
          onTap: () {
            Navigator.pop(context);
            setState(() {
              _showFilters = true;
              _showPhotoEditor = false;
              _showTemplateSelector = false;
            });
          },
        ),
        GlassBottomSheetActionTile(
          icon: LucideIcons.wandSparkles,
          label: l10n.cameraEffects,
          onTap: () {
            Navigator.pop(context);
            _togglePhotoEditor(l10n);
          },
        ),
      ],
    );
  }

  List<MediaStudioSideTool> _sideTools(AppLocalizations l10n) {
    final filtersActive = _showFilters || _hasActiveColorFilter;
    final previewOnly = _isRenderedTemplatePreview;
    return [
      // 1. Settings
      MediaStudioSideTool(
        icon: LucideIcons.settings,
        label: 'Settings',
        onTap: _isProcessing ? () {} : () => _showSettingsSheet(l10n),
      ),
      // 2. Share
      MediaStudioSideTool(
        icon: LucideIcons.share2,
        label: l10n.mediaEditorShare,
        customIcon: _sideRailSvg(AppAssets.cameraShareIcon),
        onTap: _isProcessing ? () {} : _shareCurrent,
      ),
      if (!previewOnly) ...[
        // 3. TikTok timeline editor (after capture)
        MediaStudioSideTool(
          icon: LucideIcons.scissors,
          label: l10n.mediaEditorEdit,
          active: _currentState.isVideo || _videoTemplateId != null,
          onTap: _isProcessing
              ? () {}
              : () => unawaited(_openTemplateTimelineEditor()),
        ),
        // 4. Templates (same for photos and videos)
        MediaStudioSideTool(
          icon: LucideIcons.layoutTemplate,
          label: l10n.mediaStudioTemplates,
          active: _videoTemplateId != null,
          onTap: _isProcessing || _templateApplying
              ? () {}
              : () {
                  if (_states.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.templateNeedMediaFirst)),
                    );
                  } else {
                    unawaited(_pickPhotoTemplate());
                  }
                },
        ),
      ],
      // 5. Aa
      MediaStudioSideTool(
        icon: LucideIcons.type,
        label: l10n.mediaEditorText,
        useAa: true,
        active: _currentState.textOverlays.isNotEmpty,
        onTap: _isProcessing ? () {} : () => _addText(l10n),
      ),
      // 6. Stickers
      MediaStudioSideTool(
        icon: LucideIcons.sticker,
        label: l10n.mediaEditorStickers,
        customIcon: _sideRailSvg(AppAssets.cameraStickerIcon),
        onTap: _isProcessing ? () {} : () => _showComingSoon(l10n),
      ),
      // 7. Filters (same panel as camera screen)
      MediaStudioSideTool(
        icon: LucideIcons.blend,
        label: l10n.cameraFilters,
        active: filtersActive,
        customIcon: _sideRailFiltersIcon(),
        onTap: _isProcessing
            ? () {}
            : () {
                setState(() {
                  _showFilters = !_showFilters;
                  if (_showFilters) {
                    _showPhotoEditor = false;
                    _showTemplateSelector = false;
                  }
                });
              },
      ),
      // 8. Crop
      MediaStudioSideTool(
        icon: LucideIcons.crop,
        label: l10n.mediaEditorCrop,
        active: _currentState.croppedFile != null,
        onTap: _isProcessing ? () {} : () => _openCrop(l10n),
      ),
      // Overflow (expand ▼): Voice
      MediaStudioSideTool(
        icon: LucideIcons.mic,
        label: 'Voice',
        onTap: _isProcessing ? () {} : () => _showComingSoon(l10n),
      ),
      // Video only — below Voice
      if (_currentState.isVideo)
        MediaStudioSideTool(
          icon: LucideIcons.captions,
          label: 'Captions',
          onTap: _isProcessing ? () {} : () => _showComingSoon(l10n),
        ),
    ];
  }

  Widget _sideRailFiltersIcon() {
    return _sideRailSvg(AppAssets.cameraFiltersIcon);
  }

  Widget _sideRailSvg(String asset) {
    return SvgPicture.asset(
      asset,
      width: 30,
      height: 30,
      fit: BoxFit.contain,
      colorFilter: ui.ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }

  Future<void> _openTrimEditor() async {
    final state = _currentState;
    if (!state.isVideo) return;
    setState(() => _subEditorOpen = true);
    unawaited(_syncStudioSoundPreview());
    final result = await VideoSegmentEditorScreen.show(
      context,
      file: state.sourceFile,
      initialSegments: state.trimSegments,
    );
    if (!mounted) return;
    setState(() => _subEditorOpen = false);
    unawaited(_syncStudioSoundPreview());
    if (result == null) return;
    setState(() {
      _states[_currentIndex] = _states[_currentIndex].copyWith(
        trimSegments: result,
        effectSlug: _states[_currentIndex].effectSlug,
      );
    });
  }

  /// Called by the back button / system back. Never discards silently — always
  /// surfaces the confirmation menu so captured or edited content is protected.
  void _requestExit() {
    if (_isProcessing) return;
    setState(() => _showExitMenu = true);
  }

  void _continueEditing() {
    if (!_showExitMenu) return;
    setState(() => _showExitMenu = false);
  }

  void _discardAndLeave() {
    unawaited(_templateProject?.saveDraftNow());
    setState(() {
      _showExitMenu = false;
      _leaving = true;
    });
    // Pop on the next frame so [PopScope.canPop] has flipped to true first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  void _saveDraftPlaceholder(AppLocalizations l10n) {
    setState(() => _showExitMenu = false);
    unawaited(() async {
      await _templateProject?.saveDraftNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _templateProject != null
                ? 'Template draft saved'
                : l10n.addPostDraftsComingSoon,
          ),
        ),
      );
    }());
  }

  void _sendToFriends() {
    setState(() => _showExitMenu = false);
    _shareCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentItem = _currentState.item;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final soundLabel = _selectedSound?.name.trim().isNotEmpty == true
        ? _selectedSound!.name
        : l10n.cameraAddSound;
    final authState = context.watch<AuthBloc>().state;
    final avatarUrl = authState is AuthSuccess
        ? authState.user.avatarUrl
        : null;
    final selectedColorId = _hasActiveColorFilter ? _arFilterId : 'none';
    final screenSize = MediaQuery.of(context).size;
    // Same full-screen height as video — no photo letterbox chrome that
    // shrinks the frame after capture.
    const previewChrome = (top: 0.0, bottom: 0.0);
    _previewSize = Size(screenSize.width, screenSize.height);
    final previewFile = (_smoothPreviewFile != null && _hasPreviewEdits)
        ? _smoothPreviewFile!
        : _currentState.sourceFile;
    final controlsTop = CameraRatioLetterbox.controlsTopInset(context);
    final showBottomSheet =
        _showPhotoEditor || _showFilters || _showTemplateSelector;
    final sideRailBottom = showBottomSheet
        ? 220.0 + MediaQuery.paddingOf(context).bottom
        : previewChrome.bottom + 72.0;

    final live = _templateLivePreview;
    final gpuPreview = _templateGpuPreview;
    final bakedTpl = _templatePreviewFile;
    final showTemplateLook =
        _usesCatalogTemplate &&
        (gpuPreview != null || live != null || bakedTpl != null);

    final Widget previewWidget;
    if (showTemplateLook && gpuPreview != null && gpuPreview.isReady) {
      previewWidget = RepaintBoundary(
        key: _templateCaptureKey,
        child: TemplateGpuPreview(controller: gpuPreview),
      );
    } else if (showTemplateLook && live != null) {
      final tplSources = _templateSourceFiles.isNotEmpty
          ? _templateSourceFiles
          : <File>[previewFile];
      previewWidget = RepaintBoundary(
        key: _templateCaptureKey,
        child: ListenableBuilder(
          listenable: live,
          builder: (context, _) {
            // Follow the active slot so multi-slot templates switch media.
            final slotFile = live.activeSlotFile ?? tplSources.first;
            final slotIsVideo =
                live.activeSlotIsVideo ||
                VideoThumbnailUtils.isVideoFile(slotFile);
            final recipe = _templateRecipe ?? live.session.recipe;
            final muteBed = _muteMediaForTemplateBed;

            MediaStudioPreview studioPane({
              required String paneKey,
              bool muted = false,
            }) {
              final isPrimary =
                  paneKey == 'main' ||
                  paneKey == 'pip-fg' ||
                  paneKey == 'circle-fg' ||
                  paneKey == 'mirror-a' ||
                  paneKey == 'grid-l' ||
                  paneKey == 'lyric-t' ||
                  paneKey == 'duo-a' ||
                  paneKey == 'quad-tl' ||
                  paneKey == 'film-t' ||
                  paneKey == 'diag-l' ||
                  paneKey == 'sbs-l' ||
                  paneKey == 'shaped-fg';
              return MediaStudioPreview(
                key: ValueKey(
                  'tpl-$paneKey-${slotIsVideo ? 'vid' : 'img'}-'
                  '${slotFile.path}-$_previewEpoch',
                ),
                file: slotFile,
                isVideo: slotIsVideo,
                fit: BoxFit.cover,
                arFilterId: 'none',
                arFilterIntensity: 1,
                applyArColorPreview: false,
                paused: _subEditorOpen || _isProcessing,
                // Soft template bed owns audio — mute every collage pane.
                muted: muted || muteBed,
                trimSegments: const [],
                onReady: isPrimary ? _onStudioMediaReady : null,
                onLoopRestart: isPrimary ? _onStudioMediaLoopRestart : null,
              );
            }

            // Image soft-preview uses RawImage/Image.file (no MediaStudioPreview).
            // Soundtrack is started once from [_openTemplateAppliedPreview].

            return VideoTemplateComposedPreview(
              frame: live.frame,
              videoController: live.videoController,
              imageFile: live.imageFile,
              decodedImage: live.decodedImage,
              canvasWidth: recipe.width > 0 ? recipe.width : 1080,
              canvasHeight: recipe.height > 0 ? recipe.height : 1920,
              isVideoMedia: slotIsVideo,
              videoLookStill: live.videoLookStill,
              useVideoLookStill: live.useVideoLookStill,
              // One player per collage pane (VideoPlayer cannot be mounted twice).
              mediaPaneBuilder: slotIsVideo
                  ? ({required String paneKey, bool muted = false}) =>
                        studioPane(paneKey: paneKey, muted: muted)
                  : null,
              mediaOverride: slotIsVideo
                  ? null
                  : (!live.hasPreviewSurface
                        ? studioPane(paneKey: 'main')
                        : null),
              emptyLabel: _templateApplying
                  ? l10n.templateApplying
                  : l10n.templateAddMediaToPreview,
            );
          },
        ),
      );
    } else if (showTemplateLook && bakedTpl != null) {
      previewWidget = RepaintBoundary(
        key: _templateCaptureKey,
        child: MediaStudioPreview(
          key: ValueKey('tpl-studio-${bakedTpl.path}-$_previewEpoch'),
          file: bakedTpl,
          isVideo: true,
          arFilterId: 'none',
          arFilterIntensity: 1,
          applyArColorPreview: false,
          paused: _subEditorOpen || _isProcessing,
          muted: _isRenderedTemplatePreview ? false : _muteMediaForTemplateBed,
          trimSegments: const [],
          onReady: _onStudioMediaReady,
          onLoopRestart: _onStudioMediaLoopRestart,
        ),
      );
    } else {
      previewWidget = RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaStudioPreview(
              key: ValueKey('studio-preview-$_currentIndex-$_previewEpoch'),
              file: previewFile,
              isVideo: currentItem.isVideo,
              // Fill full screen height + width like the live camera preview.
              fit: BoxFit.cover,
              arFilterId: selectedColorId,
              arFilterIntensity: _arFilterIntensity,
              applyArColorPreview: currentItem.isVideo
                  ? _needsColorFilterPreview
                  : false,
              paused: _subEditorOpen || _isProcessing,
              muted: _isRenderedTemplatePreview
                  ? false
                  : _muteMediaForTemplateBed,
              trimSegments: currentItem.isVideo
                  ? _currentState.trimSegments
                  : const [],
              onReady: _onStudioMediaReady,
              onLoopRestart: _onStudioMediaLoopRestart,
            ),
            if (_templateApplying)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _requestExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed like live camera — fill height and width, no letterbox.
            Positioned.fill(
              child: ColoredBox(color: Colors.black, child: previewWidget),
            ),
            if (!showTemplateLook && _currentState.textOverlays.isNotEmpty)
              Positioned.fill(
                child: MediaTextOverlayLayer(
                  key: ValueKey('text-overlays-$_currentIndex'),
                  overlays: _currentState.textOverlays,
                  onChanged: _moveOverlay,
                  onEdit: _editText,
                  mediaSize: _mediaPixelSize,
                  fit: BoxFit.cover,
                ),
              ),
            Positioned.fill(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: controlsTop,
                    left: 0,
                    right: 0,
                    child: MediaStudioTopBar(
                      soundLabel: soundLabel,
                      onBack: _isProcessing ? () {} : _requestExit,
                      onSoundTap: _isProcessing ? () {} : _pickSound,
                      onClearSound: _selectedSound == null || _isProcessing
                          ? null
                          : _clearSound,
                    ),
                  ),
                  if (_videoTemplateId != null &&
                      (_videoTemplateName?.trim().isNotEmpty ?? false))
                    Positioned(
                      top: controlsTop + 52,
                      left: 16,
                      right: 72,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.layoutTemplate,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                ),
                                child: Text(
                                  _videoTemplateName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: controlsTop + 48.0,
                    bottom: sideRailBottom,
                    right: isRtl ? null : 0,
                    left: isRtl ? 0 : null,
                    child: MediaStudioSideRail(
                      tools: _sideTools(l10n),
                      collapsedCount: 8,
                      iconOnStartEdge: isRtl,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_states.length > 1) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: MediaStudioClipDock(
                                items: _states.map((s) => s.item).toList(),
                                selectedIndex: _currentIndex,
                                onSelected: _selectClip,
                                onAdd: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _videoTemplateId != null
                                            ? 'Template slots: ${_states.length}'
                                            : 'Slots: ${_states.length}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (_showPhotoEditor)
                            MediaPhotoEditorPanel(
                              l10n: l10n,
                              tab: _photoEditorTab,
                              selectedTool: _photoEditorTool,
                              magicOn: _magicOn,
                              adjustmentValues: _adjustments,
                              onTabChanged: (tab) =>
                                  setState(() => _photoEditorTab = tab),
                              onToolSelected: _onPhotoEditorToolSelected,
                              onMagicToggled: _onMagicToggled,
                              onAdjustmentChanged: _onAdjustmentChanged,
                              onReset: _resetPhotoEditor,
                              selectedColorFilterId: selectedColorId,
                              colorFilterIntensity: _arFilterIntensity,
                              onColorFilterSelected:
                                  _onMakeupFilmFilterSelected,
                              onColorFilterIntensityChanged: (value) {
                                setState(() {
                                  _arFilterIntensity = value;
                                  _saveUiToCurrentState();
                                });
                                if (!_currentState.isVideo &&
                                    _needsColorFilterPreview) {
                                  _scheduleFacePreview();
                                }
                              },
                            )
                          else
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final slide = Tween<Offset>(
                                  begin: const Offset(0, 0.12),
                                  end: Offset.zero,
                                ).animate(animation);
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: slide,
                                    child: child,
                                  ),
                                );
                              },
                              child: _showFilters
                                  ? KeyedSubtree(
                                      key: const ValueKey('filters-sheet'),
                                      child: ArColorFiltersPanel(
                                        selectedFilterId: selectedColorId,
                                        selectedCategoryId: _arColorCategoryId,
                                        intensity: _arFilterIntensity,
                                        onCategorySelected: (id) =>
                                            setState(() {
                                              _arColorCategoryId = id;
                                              _saveUiToCurrentState();
                                            }),
                                        onFilterSelected: _selectArFilter,
                                        onIntensityChanged: (value) {
                                          setState(() {
                                            _arFilterIntensity = value;
                                            _saveUiToCurrentState();
                                          });
                                          if (!_currentState.isVideo &&
                                              _needsColorFilterPreview) {
                                            _scheduleFacePreview();
                                          }
                                        },
                                        onClear: () => _selectArFilter('none'),
                                        onApply: () => setState(
                                          () => _showFilters = false,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('filters-closed'),
                                    ),
                            ),
                          // Hide Next / Your Story while filters / photo editor /
                          // template selector sheet is open.
                          ClipRect(
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOutCubic,
                              alignment: Alignment.topCenter,
                              heightFactor:
                                  (_showFilters ||
                                      _showPhotoEditor ||
                                      _showTemplateSelector)
                                  ? 0
                                  : 1,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                opacity:
                                    (_showFilters ||
                                        _showPhotoEditor ||
                                        _showTemplateSelector)
                                    ? 0
                                    : 1,
                                child: MediaStudioBottomActions(
                                  yourStoryLabel: l10n.messagesYourStory,
                                  nextLabel: l10n.nextAction,
                                  autoCutLabel: l10n.mediaStudioAutoCut,
                                  autoCutActive: _videoTemplateId != null,
                                  avatarUrl: avatarUrl,
                                  enabled: !_isProcessing && !_templateApplying,
                                  onYourStory: _onYourStory,
                                  onNext: _onNext,
                                  onAutoCut: _isRenderedTemplatePreview
                                      ? null
                                      : () => unawaited(_pickPhotoTemplate()),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_templateSelectorMounted) ...[
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showTemplateSelector,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showTemplateSelector ? 1 : 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _showTemplateSelector = false),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 340),
                  curve: _showTemplateSelector
                      ? Curves.easeOutCubic
                      : Curves.easeInCubic,
                  offset: _showTemplateSelector
                      ? Offset.zero
                      : const Offset(0, 1),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _showTemplateSelector ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !_showTemplateSelector,
                      child: TemplateSelectorBottomPanel(
                        selectedTemplateId: _videoTemplateId,
                        applying: _templateApplying,
                        avatarUrl: avatarUrl,
                        nextLabel: l10n.nextAction,
                        yourStoryLabel: l10n.messagesYourStory,
                        onClose: () =>
                            setState(() => _showTemplateSelector = false),
                        onClear: () async {
                          await _clearSelectedTemplate();
                        },
                        onSelected: _onTemplateSelectedFromPanel,
                        onEdit: !_isRenderedTemplatePreview &&
                                _videoTemplateId != null &&
                                _videoTemplateId!.isNotEmpty &&
                                !_templateApplying
                            ? () {
                                setState(() => _showTemplateSelector = false);
                                unawaited(_openTemplateTimelineEditor());
                              }
                            : null,
                        onYourStory: () {
                          setState(() => _showTemplateSelector = false);
                          unawaited(_onYourStory());
                        },
                        onNext: () {
                          setState(() => _showTemplateSelector = false);
                          unawaited(_onNext());
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (_showExitMenu)
              _ExitConfirmMenu(
                isRtl: isRtl,
                onDiscard: _discardAndLeave,
                onSaveDraft: () => _saveDraftPlaceholder(l10n),
                onSendToFriends: _sendToFriends,
                onDismiss: _continueEditing,
                discardLabel: l10n.mediaEditorDiscard,
                saveDraftLabel: l10n.mediaEditorSaveDraft,
                sendLabel: l10n.mediaEditorSendToFriends,
              ),
            if (_isProcessing)
              (_videoTemplateId != null || _templateExportProgress != null)
                  ? TemplateEditorExportOverlay(
                      progress: _templateExportProgress ?? 0,
                      label: localizeTemplateExportLabel(
                        l10n,
                        _templateExportLabel ?? l10n.templateExportRendering,
                      ),
                    )
                  : CameraAppLoading(
                      message: l10n.promoteProcessing,
                    ),
          ],
        ),
      ),
    );
  }
}

/// TikTok-style confirmation shown when the user tries to leave the editor with
/// captured/edited content. Renders a translucent barrier plus a small card
/// anchored under the back button (mirrored for RTL).
class _ExitConfirmMenu extends StatelessWidget {
  const _ExitConfirmMenu({
    required this.isRtl,
    required this.onDiscard,
    required this.onSaveDraft,
    required this.onSendToFriends,
    required this.onDismiss,
    required this.discardLabel,
    required this.saveDraftLabel,
    required this.sendLabel,
  });

  final bool isRtl;
  final VoidCallback onDiscard;
  final VoidCallback onSaveDraft;
  final VoidCallback onSendToFriends;
  final VoidCallback onDismiss;
  final String discardLabel;
  final String saveDraftLabel;
  final String sendLabel;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        // Tap anywhere outside the card to dismiss (keeps editing).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const ColoredBox(color: Color(0x33000000)),
          ),
        ),
        Positioned(
          top: topInset + 56,
          left: isRtl ? null : 12,
          right: isRtl ? 12 : null,
          child: Material(
            color: Colors.white,
            elevation: 12,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ExitMenuItem(
                    icon: Icons.delete_outline_rounded,
                    label: discardLabel,
                    color: const Color(0xFFFE2C55),
                    onTap: onDiscard,
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  _ExitMenuItem(
                    icon: Icons.bookmark_outline_rounded,
                    label: saveDraftLabel,
                    color: Colors.black87,
                    onTap: onSaveDraft,
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  _ExitMenuItem(
                    icon: Icons.send_rounded,
                    label: sendLabel,
                    color: Colors.black87,
                    onTap: onSendToFriends,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExitMenuItem extends StatelessWidget {
  const _ExitMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
