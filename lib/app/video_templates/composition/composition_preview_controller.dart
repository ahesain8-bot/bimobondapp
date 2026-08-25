import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/video_templates/composition/composition_session.dart';
import 'package:bimobondapp/app/video_templates/composition/image_media_source.dart';
import 'package:bimobondapp/app/video_templates/composition/template_composition_engine.dart';
import 'package:bimobondapp/app/video_templates/composition/video_media_source.dart';
import 'package:bimobondapp/app/video_templates/engine/render/render_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/timeline/timeline_engine.dart';
import 'package:bimobondapp/app/video_templates/preview/media_texture_cache.dart';
import 'package:bimobondapp/app/video_templates/preview/template_preview_perf.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Soft live preview over the composition timeline (Phase 6).
///
/// Uses native [VideoPlayerController] decode (no Dart frame pixels over
/// MethodChannel). Image slots hold a still for the slot duration.
///
/// Full GPU Texture host can replace the video_player surface later without
/// changing [TemplateCompositionEngine].
class CompositionPreviewController extends ChangeNotifier {
  CompositionPreviewController({
    required this.engine,
    required this.session,
  });

  final TemplateCompositionEngine engine;
  final CompositionSession session;

  PreviewEngine? _preview;
  VideoPlayerController? _video;
  File? _imageFile;
  /// Controller-owned clone — safe if [ImageMediaSource] disposes its original.
  ui.Image? _decodedImage;
  String? _activeSlotId;
  Timer? _ticker;
  bool _playing = false;
  double _playhead = 0;
  bool _disposed = false;
  String? _lastLookSig;
  /// When true, studio supplies the video surface; we only advance overlay frames.
  bool _mediaDetached = false;

  double get playhead => _playhead;
  double get duration => _preview?.duration ?? session.timeline.totalDuration;
  bool get isPlaying => _playing;
  VideoPlayerController? get videoController => _video;
  File? get imageFile => _imageFile;
  /// Prepared still texture for preview ([RawImage]).
  ui.Image? get decodedImage => _decodedImage;
  String? get activeSlotId => _activeSlotId;
  bool get mediaDetached => _mediaDetached;
  bool get hasVideoSurface =>
      _video != null && _video!.value.isInitialized;

  /// Local file for the active timeline slot (works while media is detached).
  File? get activeSlotFile {
    final id = _activeSlotId;
    if (id != null) {
      final fill = session.fills[id];
      final file = fill?.localFile;
      if (file != null && file.path.isNotEmpty) return file;
    }
    for (final fill in session.fills.values) {
      final file = fill.localFile;
      if (file != null && file.path.isNotEmpty) return file;
    }
    return null;
  }

  bool get activeSlotIsVideo {
    if (_video != null && _video!.value.isInitialized) return true;
    final id = _activeSlotId;
    if (id != null) {
      final fill = session.fills[id];
      if (fill != null) return fill.isLocalVideo;
    }
    final file = activeSlotFile;
    return file != null && VideoThumbnailUtils.isVideoFile(file);
  }

  bool get hasPreviewSurface {
    if (hasVideoSurface) return true;
    if (_decodedImage != null) return true;
    final image = _imageFile;
    // A video path set as imageFile is not a real preview surface.
    if (image != null && !VideoThumbnailUtils.isVideoFile(image)) return true;
    return false;
  }

  /// Drop decode surfaces but keep timeline sampling for overlay frames.
  Future<void> detachMediaSurface() async {
    if (_disposed) return;
    _mediaDetached = true;
    await _clearVideo();
    // Keep still path when active slot is an image so hybrid UI can show it.
    if (activeSlotIsVideo) {
      _imageFile = null;
      _clearDecoded();
    }
    // Do not clear [_activeSlotId] — studio override switches with the timeline.
    _safeNotify();
  }

  /// Sample slightly before the exclusive end so the last slot stays visible.
  double get _sampleTime {
    final d = duration;
    if (d <= 0) return 0;
    if (_playhead >= d) return (d - 0.001).clamp(0.0, d);
    return _playhead;
  }

  PreviewFrame? get frame =>
      _disposed ? null : _preview?.sample(_sampleTime);

  Future<void> attach({bool prepareMedia = true}) async {
    if (_disposed) return;
    final sw = TemplatePreviewPerf.start();
    // Soft studio preview can skip still/video probe decode and show
    // Image.file / MediaStudioPreview immediately (big win on camera photos).
    if (prepareMedia) {
      await session.prepareSources();
      if (_disposed) return;
    }
    _preview = engine.preview(session);
    _preview!.seek(0);
    _playhead = 0;
    await _syncSurface(force: true);
    // If timeline sample was empty, still show first filled slot media.
    if (!hasPreviewSurface) {
      await _syncFallbackFromFills();
    }
    _safeNotify();
    TemplatePreviewPerf.end(sw, 'firstFrame');

    // Upgrade IMAGE soft path: decode once @540 into shared cache → RawImage.
    if (!prepareMedia) {
      unawaited(_warmStillTexture());
    }
  }

  /// Decode (or reuse) a downscaled still so collage panes share one texture.
  Future<void> _warmStillTexture() async {
    final file = _imageFile;
    if (file == null || VideoThumbnailUtils.isVideoFile(file)) return;
    final cached = MediaTextureCache.shared.peek(file);
    if (cached != null) {
      _setDecodedClone(cached);
      _safeNotify();
      return;
    }
    final sw = TemplatePreviewPerf.start();
    final image = await MediaTextureCache.shared.obtain(file);
    TemplatePreviewPerf.end(sw, 'textureUpload');
    if (_disposed || image == null) return;
    if (_imageFile?.path != file.path) return;
    _setDecodedClone(image);
    _safeNotify();
  }

  void play() {
    if (_disposed || _playing) return;
    _playing = true;
    _ticker?.cancel();
    // ~12fps is enough for still + effect progress; video plays natively.
    _ticker = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _tick();
    });
    if (!_mediaDetached) _video?.play();
    _safeNotify();
  }

  void pause() {
    _playing = false;
    _ticker?.cancel();
    _ticker = null;
    _video?.pause();
    _safeNotify();
  }

  Future<void> seek(double seconds) async {
    if (_disposed) return;
    _playhead = seconds.clamp(0.0, duration);
    _preview?.seek(_sampleTime);
    await _syncSurface(force: true);
    _safeNotify();
  }

  /// Rebuild timeline sampling after overlay timing edits (keeps playhead).
  void reloadTimeline() {
    if (_disposed) return;
    _preview = engine.preview(session);
    _preview!.seek(_sampleTime);
    _lastLookSig = null;
    _safeNotify();
  }

  void replay() {
    seek(0).then((_) {
      if (!_disposed) play();
    });
  }

  void _tick() {
    if (_disposed) return;
    final d = duration;
    if (d <= 0) {
      _safeNotify();
      return;
    }
    var next = _playhead + 0.08;
    // Loop so multi-slot / overlay-timed templates keep previewing.
    if (next >= d) {
      next = 0;
      _playhead = 0;
      _preview?.seek(0);
      unawaited(_syncSurface(force: true));
      _lastLookSig = null;
      _safeNotify();
      return;
    }
    final prevSlot = _activeSlotId;
    _playhead = next;
    _preview?.seek(_playhead);
    // Swap surface only on slot change — never fight video_player with seeks.
    unawaited(_syncSurface());
    // Dirty-only: skip Flutter rebuilds when look signature is unchanged
    // (static still + no timed overlays/effects).
    final sample = _preview?.sample(_sampleTime);
    final sig = _lookSignature(sample, prevSlot);
    if (_playing || sig != _lastLookSig) {
      _lastLookSig = sig;
      _safeNotify();
    }
  }

  String _lookSignature(PreviewFrame? sample, String? prevSlot) {
    final slot = _activeSlotId ?? prevSlot ?? '';
    if (sample == null) return '$slot|empty';
    final fx = sample.effects
        .map((e) => '${e.effectType}:${e.progress.toStringAsFixed(1)}')
        .join(',');
    final fl = sample.filters.map((f) => f.filterName).join(',');
    final tr = sample.transitions
        .map((t) => '${t.type}:${t.progress.toStringAsFixed(1)}')
        .join(',');
    final overlays = sample.texts.length +
        sample.stickers.length +
        sample.overlays.length;
    return '$slot|fx=$fx|fl=$fl|tr=$tr|ov=$overlays';
  }

  Future<void> _syncSurface({bool force = false}) async {
    if (_disposed) return;
    var sample = _preview?.sample(_sampleTime);
    if (sample == null || sample.media.isEmpty) {
      // Keep existing surface if we already have one (end-of-timeline).
      if (!_mediaDetached && hasPreviewSurface) return;
      await _syncFallbackFromFills();
      return;
    }
    final item = sample.media.first;
    final path = item.userMediaPath;
    if (path == null || path.isEmpty) {
      if (!_mediaDetached && !hasPreviewSurface) {
        await _syncFallbackFromFills();
      }
      return;
    }

    final slotId = item.slotId ?? item.id;
    if (!force && slotId == _activeSlotId) {
      // Same slot: do not seek video every tick (kills performance).
      // Native VideoPlayer advances on its own while playing.
      return;
    }

    if (_disposed) return;
    _activeSlotId = slotId;
    final file = File(path);

    // Studio owns the player — still track slot + still image for hybrid UI.
    if (_mediaDetached) {
      final fill = session.fills[slotId];
      final asVideo = fill?.isLocalVideo == true ||
          VideoThumbnailUtils.isVideoFile(file) ||
          item.kind == TimelineLayerKind.videoClip;
      if (asVideo) {
        _imageFile = null;
        _clearDecoded();
      } else {
        _imageFile = file;
        final src = session.sourceFor(slotId);
        _setDecodedClone(
          src is ImageMediaSource ? src.decodedImage : null,
        );
      }
      _safeNotify();
      return;
    }

    await _presentFile(
      file: file,
      slotId: item.slotId,
      item: item,
    );
  }

  /// When the timeline has no active media, show the first filled slot.
  Future<void> _syncFallbackFromFills() async {
    if (_disposed) return;
    for (final fill in session.fills.values) {
      final file = fill.localFile;
      if (file == null || file.path.isEmpty) continue;
      if (!await file.exists()) continue;
      _activeSlotId = fill.slotId;
      if (_mediaDetached) {
        if (fill.isLocalVideo) {
          _imageFile = null;
          _clearDecoded();
        } else {
          _imageFile = file;
        }
        _safeNotify();
        return;
      }
      await _presentFile(file: file, slotId: fill.slotId, item: null);
      return;
    }
    await _clearVideo();
    _imageFile = null;
    _clearDecoded();
    _activeSlotId = null;
  }

  Future<void> _presentFile({
    required File file,
    String? slotId,
    TimelineItem? item,
  }) async {
    final fill = slotId != null ? session.fills[slotId] : null;
    final mediaSource =
        slotId != null ? session.sourceFor(slotId) : null;
    final asVideo = mediaSource is VideoMediaSource ||
        fill?.isLocalVideo == true ||
        VideoThumbnailUtils.isVideoFile(file) ||
        item?.kind == TimelineLayerKind.videoClip;

    if (!asVideo) {
      await _clearVideo();
      if (_disposed) return;
      _imageFile = file;
      final src =
          mediaSource is ImageMediaSource ? mediaSource.decodedImage : null;
      _setDecodedClone(src);
      return;
    }

    // Video clip — never use Image.file on an mp4 (blank / empty UI).
    _imageFile = null;
    _clearDecoded();
    await _clearVideo();
    if (_disposed) return;
    try {
      if (!await file.exists()) {
        debugPrint('CompositionPreview: video missing ${file.path}');
        return;
      }
      final c = VideoPlayerController.file(file);
      await c.initialize();
      if (_disposed) {
        await c.dispose();
        return;
      }
      c.setLooping(true);
      final source = slotId != null ? session.sourceFor(slotId) : null;
      Duration target = Duration.zero;
      if (item != null) {
        final local = (_sampleTime - item.startTime).clamp(0.0, item.duration);
        if (source is VideoMediaSource) {
          target = source.mapLocalTime(
            Duration(milliseconds: (local * 1000).round()),
          );
        } else {
          target = Duration(milliseconds: (local * 1000).round());
        }
      } else if (source is VideoMediaSource) {
        target = source.mapLocalTime(Duration.zero);
      }
      await c.seekTo(target);
      // Soft preview bed (SoundAudioPreview) owns audio — never mix clip audio.
      await c.setVolume(0);
      if (_playing) await c.play();
      _video = c;
      c.addListener(_onVideoControllerUpdate);
      _safeNotify();
    } catch (e, st) {
      debugPrint('CompositionPreviewController surface: $e\n$st');
      // Signal studio hybrid to take over — do not leave a blank surface.
      _imageFile = null;
      _clearDecoded();
      _mediaDetached = true;
      _safeNotify();
    }
  }

  void _onVideoControllerUpdate() {
    if (_disposed) return;
    _safeNotify();
  }

  void _setDecodedClone(ui.Image? src) {
    if (identical(_decodedImage, src)) return;
    _clearDecoded();
    if (src == null) return;
    try {
      _decodedImage = src.clone();
    } catch (_) {
      _decodedImage = null;
    }
  }

  void _clearDecoded() {
    _decodedImage?.dispose();
    _decodedImage = null;
  }

  Future<void> _clearVideo() async {
    final c = _video;
    _video = null;
    if (c != null) {
      try {
        c.removeListener(_onVideoControllerUpdate);
        await c.pause();
        await c.dispose();
      } catch (_) {}
    }
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    _playing = false;
    _clearDecoded();
    // Fire-and-forget video teardown — do not await in dispose.
    unawaited(_clearVideo());
    _preview = null;
    super.dispose();
  }
}
