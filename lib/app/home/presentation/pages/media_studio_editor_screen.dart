import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/app/ar_camera/ar_color_filter_matrix.dart';
import 'package:bimobondapp/app/ar_camera/ar_color_filters_panel.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/pages/media_crop_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/video_segment_editor_screen.dart';
import 'package:bimobondapp/app/home/presentation/utils/camera_capture_utils.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_picker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_color_lut.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_item_edit_state.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_gallery_import_flow.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_skin_smooth.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_baker.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_font_styles.dart';
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
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_sheet.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
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
  });

  final List<GalleryMediaItem> items;
  final int initialIndex;
  final bool isStory;
  final SoundEntity? initialSound;
  final Duration initialSoundOffset;
  final bool initialMuteOriginal;
  final bool popOnDone;
  final MediaEditorSeed? initialEdit;

  @override
  State<MediaStudioEditorScreen> createState() =>
      _MediaStudioEditorScreenState();
}

class _MediaStudioEditorScreenState extends State<MediaStudioEditorScreen>
    with FeedPlaybackBlocker {
  late List<MediaItemEditState> _states;
  late int _currentIndex;
  SoundEntity? _selectedSound;

  /// Where playback starts inside the selected track (TikTok-style trim).
  Duration _soundStartOffset = Duration.zero;

  /// Selected sound period length (typically 15s).
  Duration _soundWindow = const Duration(seconds: 15);

  /// Mute the video's own audio when mixing the selected music in.
  bool _muteOriginalAudio = false;

  /// Length of the video generated from a still photo when music is added.
  static const _photoMusicMaxSeconds = 15;

  String _arFilterId = 'none';
  String _arColorCategoryId = 'portrait';
  double _arFilterIntensity = 1.0;
  bool _alreadyBaked = false;
  String _bakedFilterId = 'none';
  bool _showFilters = false;
  bool _showPhotoEditor = false;
  MediaPhotoEditorTab _photoEditorTab = MediaPhotoEditorTab.face;
  MediaPhotoEditorTool _photoEditorTool = MediaPhotoEditorTool.magic;
  bool _magicOn = false;

  /// Bipolar tone/color adjustments (-1…1) keyed by tool.
  final Map<MediaPhotoEditorTool, double> _adjustments = {
    MediaPhotoEditorTool.saturation: 0.0,
    MediaPhotoEditorTool.brightness: 0.0,
    MediaPhotoEditorTool.contrast: 0.0,
    MediaPhotoEditorTool.exposure: 0.0,
    MediaPhotoEditorTool.whiteBalance: 0.0,
    MediaPhotoEditorTool.highlights: 0.0,
    MediaPhotoEditorTool.shadows: 0.0,
    MediaPhotoEditorTool.nose: 0.0,
  };
  File? _smoothPreviewFile;
  Timer? _smoothDebounce;
  int _smoothGen = 0;
  bool _isProcessing = false;

  /// Shows the TikTok-style exit confirmation (Discard / Save draft / Continue).
  bool _showExitMenu = false;

  /// True while a full-screen sub-editor (Trim / Text) is open on top, so the
  /// main video preview pauses and its audio doesn't play behind it.
  bool _subEditorOpen = false;

  /// Set once the user confirms Discard so [PopScope] lets the route pop.
  bool _leaving = false;

  /// Full-screen preview box size, used to map text overlays onto the export.
  Size _previewSize = Size.zero;

  MediaItemEditState get _currentState => _states[_currentIndex];

  double _adj(MediaPhotoEditorTool tool) => _adjustments[tool] ?? 0.0;

  bool get _hasFaceEdits => _adjustments.values.any((v) => v.abs() > 0.02);

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

  /// True when a color grade needs to be applied in the editor because it isn't
  /// already baked into the source pixels (gallery import, or the user changed
  /// away from the baked id). We bake it natively via the PNG LUT — no matrix.
  bool get _needsColorLutPreview {
    if (!_hasActiveColorFilter) return false;
    if (!_alreadyBaked) return true;
    return _arFilterId != _bakedFilterId;
  }

  /// Any photo edit that requires a native-baked preview file (tone/geometry
  /// adjustments or a LUT color grade).
  bool get _hasPreviewEdits => _hasFaceEdits || _needsColorLutPreview;

  @override
  void initState() {
    super.initState();
    _selectedSound = widget.initialSound;
    _soundStartOffset = widget.initialSoundOffset;
    _muteOriginalAudio = widget.initialMuteOriginal;
    _states = widget.items.map(MediaItemEditState.fromItem).toList();
    if (widget.initialEdit != null && _states.isNotEmpty) {
      _states[0] = MediaItemEditState.fromItemWithSeed(
        _states[0].item,
        widget.initialEdit!,
      );
    }
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _applyStateToUi(_states[_currentIndex]);
    // Warm fancy fonts in the background so Aa opens without a hitch.
    unawaited(MediaTextFontStyles.preload());
    if (_hasPreviewEdits) {
      _scheduleFacePreview();
    }
    if (_selectedSound != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_syncStudioSoundPreview());
      });
    }
  }

  /// Keeps the selected track audible under the studio preview (video or photo).
  /// Stops while a sub-editor / sound picker is open so players don't fight.
  Future<void> _syncStudioSoundPreview() async {
    final sound = _selectedSound;
    if (sound == null || _subEditorOpen || _isProcessing) {
      await SoundAudioPreview.stop();
      return;
    }
    final url = sound.resolvedAudioUrl;
    if (url.isEmpty) {
      await SoundAudioPreview.stop();
      return;
    }
    await SoundAudioPreview.playAt(
      sound.id,
      url,
      startOffset: _soundStartOffset,
      window: _soundWindow,
      loop: true,
    );
  }

  @override
  void dispose() {
    _smoothDebounce?.cancel();
    unawaited(SoundAudioPreview.stop());
    try {
      _smoothPreviewFile?.deleteSync();
    } catch (_) {}
    super.dispose();
  }

  void _applyStateToUi(MediaItemEditState state) {
    _arFilterId = state.arFilterId;
    _arColorCategoryId = state.arColorCategoryId;
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

  /// Bakes the color grade onto a photo using the native PNG-LUT engine (the
  /// same lookup the live camera uses). Full resolution — no [maxEdge].
  Future<File> _bakeColorFilterToFile(
    File input,
    String filterId,
    double intensity,
  ) async {
    final out = await MediaColorLut.apply(
      input: input,
      filterId: filterId,
      intensity: intensity,
    );
    return out ?? input;
  }

  Future<List<File>> _exportAll() async {
    _saveUiToCurrentState();
    final results = <File>[];
    for (final state in _states) {
      results.add(await _exportCurrentWithColorIfNeeded(state));
    }
    await _bakeMusicInto(results);
    return results;
  }

  /// Bakes the selected music track into every exported file so the uploaded
  /// media actually contains the sound (TikTok-style). Videos get the track
  /// muxed in; still photos are turned into a short music video.
  Future<void> _bakeMusicInto(List<File> results) async {
    final sound = _selectedSound;
    if (sound == null) return;
    final audioUrl = sound.resolvedAudioUrl;
    if (audioUrl.isEmpty) return;

    final audio = await SoundLocalFile.resolve(audioUrl);
    if (audio == null) return;

    // Photo + music → 15s clip from the chosen start (TikTok-style).
    final trackSeconds = sound.duration > 0 ? sound.duration : 0;
    var photoSeconds = _soundWindow.inSeconds.clamp(1, _photoMusicMaxSeconds);
    if (photoSeconds < _photoMusicMaxSeconds) {
      photoSeconds = _photoMusicMaxSeconds;
    }
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
      final file = results[i];
      try {
        final File? withMusic;
        if (isVideo) {
          withMusic = await NativeVideoProcessor.muxAudioIntoVideo(
            file,
            audio: audio,
            startOffset: _soundStartOffset,
            audioEnd: _soundStartOffset + _soundWindow,
            keepOriginalAudio: !_muteOriginalAudio,
          );
        } else {
          withMusic = await NativeVideoProcessor.renderImageWithMusic(
            file,
            audio: audio,
            duration: photoDuration,
            startOffset: _soundStartOffset,
          );
        }
        if (withMusic != null) results[i] = withMusic;
      } catch (e, st) {
        debugPrint('Music bake failed for ${file.path}: $e\n$st');
      }
    }
  }

  Future<void> _finishAsPost({required bool asStory}) async {
    if (_isProcessing) return;
    unawaited(SoundAudioPreview.stop());
    setState(() => _isProcessing = true);

    try {
      final files = await _exportAll();
      if (!mounted) return;

      if (widget.popOnDone) {
        context.pop(
          MediaStudioExportResult(
            files: files,
            filterName: primaryFilterNameFromStates(_states),
            filterCategory: primaryFilterCategoryFromStates(_states),
            effectSlug: primaryEffectSlugFromStates(_states),
            beautyEnabled: _states.any((s) => s.beautyEnabled),
            arFilterId: primaryArFilterIdFromStates(_states),
            sound: _selectedSound,
            soundOffset: _soundStartOffset,
            soundWindow: _soundWindow,
          ),
        );
        return;
      }

      final goStory = asStory || widget.isStory;
      if (goStory) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => StoryCameraEditor(
              file: files.first,
              type: widget.items.first.type,
              sound: _selectedSound,
              soundOffset: _soundStartOffset,
              soundWindow: _soundWindow,
              onRetake: () => context.pop(),
            ),
          ),
        );
        return;
      }

      final type = MediaGalleryImportFlow.resolvePostType(files);
      context.pushReplacementNamed(
        'add_post',
        extra: {
          'files': files,
          'type': type,
          'isStory': false,
          'initialSound': _selectedSound,
          'initialSoundOffset': _soundStartOffset,
          'initialSoundWindow': _soundWindow,
          'filterName': primaryFilterNameFromStates(_states),
          'filterCategory': primaryFilterCategoryFromStates(_states).name,
          'effectSlug': primaryEffectSlugFromStates(_states),
          'beautyEnabled': _states.any((s) => s.beautyEnabled),
          'arFilterId': primaryArFilterIdFromStates(_states),
        },
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _onNext() => _finishAsPost(asStory: false);

  Future<void> _onYourStory() => _finishAsPost(asStory: true);

  void _toggleBeauty() {
    setState(() {
      if (_arFilterId == 'whitening') {
        _arFilterId = 'none';
        _magicOn = false;
      } else {
        _arFilterId = 'whitening';
        _arColorCategoryId = 'portrait';
        _magicOn = true;
        _showFilters = false;
      }
      _saveUiToCurrentState();
    });
  }

  void _applyPhotoBeautyLook() {
    // Magic = brighten/beauty grade only. Smooth = separate skin-clear pass.
    if (_magicOn) {
      _arFilterId = 'whitening';
      _arColorCategoryId = 'portrait';
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
      if (_arFilterId == 'whitening') {
        _magicOn = true;
      }
    });
  }

  void _onMagicToggled() {
    setState(() {
      _magicOn = !_magicOn;
      _applyPhotoBeautyLook();
    });
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

  /// Builds the live preview file natively: tone/geometry adjustments (OpenCV)
  /// then the color grade (PNG LUT). Both run on Kotlin — no Flutter matrix.
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

    if (_needsColorLutPreview) {
      final graded = await MediaColorLut.apply(
        input: working,
        filterId: _arFilterId,
        intensity: _arFilterIntensity,
        maxEdge: 960,
      );
      if (gen != _smoothGen) {
        _deleteTemp(graded, source);
        if (produced) _deleteTemp(working, source);
        return;
      }
      if (graded != null) {
        if (produced) _deleteTemp(working, source);
        working = graded;
        produced = true;
      }
    }

    if (!mounted || gen != _smoothGen) {
      if (produced) _deleteTemp(working, source);
      return;
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
    setState(() {
      _magicOn = false;
      for (final key in _adjustments.keys) {
        _adjustments[key] = 0.0;
      }
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
          _arColorCategoryId = kMediaPhotoEditorFilmCategoryId;
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
        _arColorCategoryId = kMediaPhotoEditorFilmCategoryId;
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
    // Pause the studio video while the sound picker (and its own
    // VideoPlayer-based audio preview) is open — two players at once
    // freeze the preview on Android after the sheet closes.
    setState(() => _subEditorOpen = true);
    await _syncStudioSoundPreview();
    final picked = await SoundPickerSheet.show(
      context,
      initialSelection: _selectedSound,
      initialOffset: _soundStartOffset,
      initialWindow: _soundWindow,
      allowMuteOnTrim: hasVideo,
    );
    if (!mounted) return;
    await SoundAudioPreview.stop();
    setState(() => _subEditorOpen = false);
    if (picked == null) {
      unawaited(_syncStudioSoundPreview());
      return;
    }
    if (picked.cleared) {
      _clearSound();
      return;
    }
    final sound = picked.sound;
    if (sound == null) {
      unawaited(_syncStudioSoundPreview());
      return;
    }

    setState(() {
      _selectedSound = sound;
      _soundStartOffset = picked.offset;
      _soundWindow = picked.window > Duration.zero
          ? picked.window
          : const Duration(seconds: 15);
      _muteOriginalAudio = picked.muteOriginal;
    });
    // Resume video first, then start the studio music bed under it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncStudioSoundPreview());
    });
  }

  void _clearSound() {
    setState(() {
      _selectedSound = null;
      _soundStartOffset = Duration.zero;
      _soundWindow = const Duration(seconds: 15);
      _muteOriginalAudio = false;
    });
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

  Future<void> _openCrop(AppLocalizations l10n) async {
    if (_isProcessing) return;
    final state = _currentState;
    if (state.isVideo) {
      _showComingSoon(l10n);
      return;
    }
    final bytes = await state.sourceFile.readAsBytes();
    if (!mounted) return;
    // Decode into the image cache first so the crop screen paints the photo on
    // frame 1 instead of flashing black while Crop parses the bytes.
    await precacheImage(MemoryImage(bytes), context);
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
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
    await file.writeAsBytes(cropped);
    if (!mounted) return;
    setState(() {
      _states[_currentIndex] = _states[_currentIndex].copyWith(
        croppedFile: file,
        effectSlug: _states[_currentIndex].effectSlug,
      );
    });
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
          ? _needsColorLutPreview
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
      // 3. Video edit
      MediaStudioSideTool(
        icon: LucideIcons.clapperboard,
        label: l10n.mediaEditorEdit,
        active: _currentState.trimSegments.isNotEmpty,
        onTap: _isProcessing
            ? () {}
            : () {
                if (_currentState.isVideo) {
                  _openTrimEditor();
                } else {
                  _showComingSoon(l10n);
                }
              },
      ),
      // 4. Templates
      MediaStudioSideTool(
        icon: LucideIcons.layoutTemplate,
        label: 'Templates',
        onTap: _isProcessing ? () {} : () => _showComingSoon(l10n),
      ),
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
                  if (_showFilters) _showPhotoEditor = false;
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
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.addPostDraftsComingSoon)));
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
    _previewSize = MediaQuery.of(context).size;
    final previewFile = (_smoothPreviewFile != null && _hasPreviewEdits)
        ? _smoothPreviewFile!
        : _currentState.sourceFile;
    final isPhoto = !currentItem.isVideo;
    final previewChrome = CameraRatioLetterbox.tikTokChromeHeights(
      context,
      photoMode: isPhoto,
    );
    final controlsTop = CameraRatioLetterbox.controlsTopInset(context);
    final showBottomSheet = _showPhotoEditor || _showFilters;
    final sideRailBottom = showBottomSheet
        ? 220.0 + MediaQuery.paddingOf(context).bottom
        : previewChrome.bottom + 72.0;

    final previewWidget = RepaintBoundary(
      child: MediaStudioPreview(
        // Stable key — do NOT key on beauty preview path (that blinks).
        key: ValueKey('studio-preview-$_currentIndex'),
        file: previewFile,
        isVideo: currentItem.isVideo,
        arFilterId: selectedColorId,
        arFilterIntensity: _arFilterIntensity,
        // Photos: the grade is baked into previewFile via the native LUT.
        // Videos: still previewed with the matrix path (matches export).
        applyArColorPreview: currentItem.isVideo ? _needsColorLutPreview : false,
        paused: _subEditorOpen,
        muted: _selectedSound != null && _muteOriginalAudio,
        trimSegments: currentItem.isVideo
            ? _currentState.trimSegments
            : const [],
      ),
    );

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
            TikTokPhotoPreviewClip(
              topHeight: previewChrome.top,
              bottomHeight: previewChrome.bottom,
              child: previewWidget,
            ),
            if (_currentState.textOverlays.isNotEmpty)
              Positioned.fill(
                child: TikTokPhotoPreviewClip(
                  topHeight: previewChrome.top,
                  bottomHeight: previewChrome.bottom,
                  child: MediaTextOverlayLayer(
                    key: ValueKey('text-overlays-$_currentIndex'),
                    overlays: _currentState.textOverlays,
                    onChanged: _moveOverlay,
                    onEdit: _editText,
                  ),
                ),
              ),
            TikTokChromeBarsOverlay(
              topHeight: previewChrome.top,
              bottomHeight: previewChrome.bottom,
              animated: false,
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
                  Positioned(
                    top: controlsTop,
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
                                    _needsColorLutPreview) {
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
                                              _needsColorLutPreview) {
                                            _scheduleFacePreview();
                                          }
                                        },
                                        onClear: () =>
                                            _selectArFilter('none'),
                                        onApply: () => setState(
                                          () => _showFilters = false,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('filters-closed'),
                                    ),
                            ),
                          // Hide Next / Your Story while filters (or photo editor)
                          // sheet is open — slide + fade so the sheet sits cleanly.
                          ClipRect(
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOutCubic,
                              alignment: Alignment.topCenter,
                              heightFactor:
                                  (_showFilters || _showPhotoEditor) ? 0 : 1,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                opacity:
                                    (_showFilters || _showPhotoEditor) ? 0 : 1,
                                child: MediaStudioBottomActions(
                                  yourStoryLabel: l10n.messagesYourStory,
                                  nextLabel: l10n.nextAction,
                                  avatarUrl: avatarUrl,
                                  enabled: !_isProcessing,
                                  onYourStory: _onYourStory,
                                  onNext: _onNext,
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
              CameraAppLoading(message: l10n.promoteProcessing),
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
