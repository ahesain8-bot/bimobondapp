import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/video_templates/composition/composition_session.dart';
import 'package:bimobondapp/app/video_templates/composition/image_media_source.dart';
import 'package:bimobondapp/app/video_templates/composition/template_composition_engine.dart';
import 'package:bimobondapp/app/video_templates/composition/video_media_source.dart';
import 'package:bimobondapp/app/video_templates/engine/render/render_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/engine/timeline/timeline_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
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
  File? _videoLookStill;
  int _videoLookStillGen = 0;
  int _lastVideoStillRefreshMs = 0;
  String? _audioBedKey;
  int _surfaceEpoch = 0;
  String? _presentedFilePath;

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
    if (_videoLookStill != null) return true;
    final image = _imageFile;
    // A video path set as imageFile is not a real preview surface.
    if (image != null && !VideoThumbnailUtils.isVideoFile(image)) return true;
    return false;
  }

  /// JPEG frame for video slots — [ColorFiltered] does not affect live
  /// [VideoPlayer] textures reliably on mobile; still + matrix does.
  File? get videoLookStill => _videoLookStill;

  bool get useVideoLookStill =>
      activeSlotIsVideo && _lookActiveAtPlayhead(_activeSlotId);

  (double start, double duration)? _slotWindow(String slotId) {
    var cursor = 0.0;
    for (final slot in session.slots) {
      final dur = UserProjectSlotMapper.resolveSlotDuration(
        slot,
        session.fills[slot.id],
      );
      if (slot.id == slotId) return (cursor, dur);
      cursor += dur;
    }
    return null;
  }

  /// Recipe slot active at [time] on the sequential slot timeline.
  String? _slotIdAtPlayhead(double time) {
    var cursor = 0.0;
    for (final slot in session.slots) {
      final dur = UserProjectSlotMapper.resolveSlotDuration(
        slot,
        session.fills[slot.id],
      );
      final end = cursor + dur;
      if (time >= cursor && time < end) return slot.id;
      cursor = end;
    }
    return null;
  }

  TimelineItem? _slotTimelineItem(String slotId) {
    for (final item in session.timeline.items) {
      if (item.slotId == slotId &&
          (item.kind == TimelineLayerKind.imageClip ||
              item.kind == TimelineLayerKind.videoClip)) {
        return item;
      }
    }
    return null;
  }

  TimelineItem? _primaryMediaItem(List<TimelineItem> media) {
    TimelineItem? slotClip;
    for (final item in media) {
      if (!item.id.startsWith('slot_')) continue;
      if (slotClip == null || item.layerOrder >= slotClip.layerOrder) {
        slotClip = item;
      }
    }
    return slotClip ?? (media.isEmpty ? null : media.first);
  }

  bool _isVideoFill(String? slotId, File file, TimelineItem? item) {
    final mediaSource = slotId != null ? session.sourceFor(slotId) : null;
    final fill = slotId != null ? session.fills[slotId] : null;
    if (mediaSource is VideoMediaSource) return true;
    if (fill?.isLocalVideo == true) return true;
    if (fill?.isLocalImage == true) return false;
    return VideoThumbnailUtils.isVideoFile(file);
  }

  double? _slotLocalTime(String? slotId) {
    if (slotId == null) return null;
    final window = _slotWindow(slotId);
    if (window == null) return null;
    final local = _playhead - window.$1;
    if (local < 0 || local >= window.$2) return null;
    return local;
  }

  bool _lookActiveAtPlayhead(String? slotId) {
    if (slotId == null) return false;
    final window = _slotWindow(slotId);
    final local = _slotLocalTime(slotId);
    if (window == null || local == null) return false;

    final slotFilters = session.userFilters.where((f) => f.slotId == slotId);
    for (final filter in slotFilters) {
      if (filter.filterName.isEmpty || filter.filterName == 'none') continue;
      if (SlotLocalTiming.containsLocalTime(
        slotDuration: window.$2,
        localTime: local,
        startTime: filter.startTime,
        endTime: filter.endTime,
      )) {
        return true;
      }
    }

    final slotEffects = session.userEffects.where((e) => e.slotId == slotId);
    for (final effect in slotEffects) {
      if (effect.effectType.isEmpty || effect.effectType == 'none') continue;
      if (SlotLocalTiming.containsLocalTime(
        slotDuration: window.$2,
        localTime: local,
        startTime: effect.startTime,
        endTime: effect.endTime,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Pause, seek, rebuild timeline, and refresh the video still for look edits.
  Future<void> applyLookPreview({
    required String slotId,
    required double targetTime,
  }) async {
    if (_disposed) return;
    pause();
    _playhead = targetTime.clamp(0.0, duration);
    _preview = engine.preview(session);
    _preview!.seek(_sampleTime);
    _lastLookSig = null;
    // Always drop the previous graded still so deleted FX/filters disappear.
    _clearVideoLookStill();
    await _syncSurface(force: true);
    if (activeSlotIsVideo && _lookActiveAtPlayhead(slotId)) {
      await refreshVideoLookStill();
    }
    _safeNotify();
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
    _preview ??= engine.preview(session);
    final d = duration;
    if (d <= 0) return;
    if (_playhead >= d - 0.05) {
      _playhead = 0;
      _preview?.seek(0);
      _audioBedKey = null;
    }
    _playing = true;
    _ticker?.cancel();
    // ~12fps advances playhead for stills, FX, texts; video decodes natively.
    _ticker = Timer.periodic(const Duration(milliseconds: 80), (_) {
      _tick();
    });
    unawaited(_resumeVideoAtPlayhead());
    unawaited(_syncPreviewAudio(force: true));
    _safeNotify();
  }

  Future<void> _resumeVideoAtPlayhead() async {
    if (_disposed || !_playing || _mediaDetached) return;
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    final slotId = _activeSlotId;
    final item = slotId != null ? _slotTimelineItem(slotId) : null;
    var target = Duration.zero;
    if (item != null) {
      final local = (_sampleTime - item.startTime).clamp(0.0, item.duration);
      final source = session.sourceFor(slotId!);
      if (source is VideoMediaSource) {
        target = source.mapLocalTime(
          Duration(milliseconds: (local * 1000).round()),
        );
      } else {
        target = Duration(milliseconds: (local * 1000).round());
      }
    }
    try {
      await video.seekTo(target);
      if (_disposed || !_playing) return;
      await video.play();
    } catch (_) {}
  }

  void pause() {
    _playing = false;
    _ticker?.cancel();
    _ticker = null;
    _video?.pause();
    unawaited(SoundAudioPreview.pause());
    _audioBedKey = null;
    _safeNotify();
  }

  Future<void> seek(double seconds) async {
    if (_disposed) return;
    _playhead = seconds.clamp(0.0, duration);
    _preview?.seek(_sampleTime);
    await _syncSurface(force: true);
    if (useVideoLookStill) {
      await refreshVideoLookStill();
    }
    if (_playing) {
      unawaited(_syncPreviewAudio(force: true));
    }
    _safeNotify();
  }

  /// Rebuild timeline sampling after overlay timing edits (keeps playhead).
  void reloadTimeline() {
    if (_disposed) return;
    _preview = engine.preview(session);
    _preview!.seek(_sampleTime);
    _lastLookSig = null;
    if (useVideoLookStill) {
      unawaited(refreshVideoLookStill());
    } else {
      _clearVideoLookStill();
    }
    if (_playing) {
      unawaited(_syncPreviewAudio(force: true));
    }
    _safeNotify();
  }

  /// Start / pause the selected sound bed under the template preview.
  Future<void> _syncPreviewAudio({bool force = false}) async {
    if (_disposed || !_playing) return;

    if (session.userSoundCleared) {
      await SoundAudioPreview.stop();
      _audioBedKey = null;
      return;
    }

    final tracks = session.resolvedAudioTracks;
    if (tracks.isEmpty) {
      await SoundAudioPreview.stop();
      _audioBedKey = null;
      return;
    }

    final track = tracks.first;
    final sound = track.sound;
    final url = sound.resolvedAudioUrl.trim();
    if (url.isEmpty) {
      await SoundAudioPreview.stop();
      _audioBedKey = null;
      return;
    }

    final ph = _playhead;
    final trackEnd = track.endTime ?? duration;
    if (ph < track.startTime || ph >= trackEnd) {
      await SoundAudioPreview.pause();
      _audioBedKey = null;
      return;
    }

    final bedKey =
        '${sound.id}|${track.segmentStartMs}|${track.segmentEndMs}|'
        '${track.startTime}|$trackEnd';
    if (!force &&
        _audioBedKey == bedKey &&
        SoundAudioPreview.isPlaying(sound.id)) {
      return;
    }
    _audioBedKey = bedKey;

    final elapsedSec = (ph - track.startTime).clamp(0.0, trackEnd);
    final startMs = track.segmentStartMs + (elapsedSec * 1000).round();
    final segEndMs = track.segmentEndMs;
    final windowMs = segEndMs != null
        ? (segEndMs - startMs).clamp(500, 3600000)
        : ((trackEnd - ph) * 1000).round().clamp(500, 3600000);

    await SoundAudioPreview.playAt(
      sound.id,
      url,
      startOffset: Duration(milliseconds: startMs.clamp(0, 3600000)),
      window: Duration(milliseconds: windowMs),
      loop: true,
    );
  }

  /// Grab the current video frame so filters/effects can composite on mobile.
  Future<void> refreshVideoLookStill() async {
    if (_disposed || !_lookActiveAtPlayhead(_activeSlotId)) {
      _clearVideoLookStill();
      return;
    }
    final file = activeSlotFile;
    if (file == null || !VideoThumbnailUtils.isVideoFile(file)) {
      _clearVideoLookStill();
      return;
    }
    final gen = ++_videoLookStillGen;
    final ms = (_sampleTime * 1000).round().clamp(0, 360000000);
    final thumb = await VideoThumbnailUtils.generateThumbnailFile(
      file,
      timeMs: ms,
      maxHeight: 720,
    );
    if (_disposed || gen != _videoLookStillGen) {
      await VideoThumbnailUtils.deleteIfExists(thumb);
      return;
    }
    final prev = _videoLookStill;
    _videoLookStill = thumb;
    await VideoThumbnailUtils.deleteIfExists(prev);
    _lastLookSig = null;
    _safeNotify();
  }

  void _clearVideoLookStill() {
    _videoLookStillGen++;
    final prev = _videoLookStill;
    _videoLookStill = null;
    if (prev != null) {
      unawaited(VideoThumbnailUtils.deleteIfExists(prev));
    }
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
      _audioBedKey = null;
      unawaited(_syncSurface(force: true));
      unawaited(SoundAudioPreview.restartFromStart());
      unawaited(_syncPreviewAudio(force: true));
      _lastLookSig = null;
      _safeNotify();
      return;
    }
    final prevSlot = _activeSlotId;
    _playhead = next;
    _preview?.seek(_playhead);
    final nextSlot = _slotIdAtPlayhead(_playhead);
    // Force surface swap when the playhead crosses into another slot.
    unawaited(_syncSurface(force: nextSlot != null && nextSlot != prevSlot));
    final sample = _preview?.sample(_sampleTime);
    final sig = _lookSignature(sample, prevSlot);
    final wantStill = useVideoLookStill;
    if (_playing && wantStill) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastVideoStillRefreshMs > 450) {
        _lastVideoStillRefreshMs = now;
        unawaited(refreshVideoLookStill());
      }
    } else if (!wantStill && _videoLookStill != null) {
      _clearVideoLookStill();
    }
    // Image/still previews must repaint every tick (FX + timed overlays).
    if (_playing ||
        sig != _lastLookSig ||
        wantStill != (_videoLookStill != null)) {
      _lastLookSig = sig;
      if (_playing) {
        unawaited(_syncPreviewAudio());
      }
      _safeNotify();
    }
  }

  String _lookSignature(PreviewFrame? sample, String? prevSlot) {
    final slot = _activeSlotId ?? prevSlot ?? '';
    if (sample == null) {
      return '$slot|empty|t=${_playhead.toStringAsFixed(2)}';
    }
    final fx = sample.effects
        .map((e) => '${e.effectType}:${e.progress.toStringAsFixed(1)}')
        .join(',');
    final fl = sample.filters.map((f) => f.filterName).join(',');
    final tr = sample.transitions
        .map((t) => '${t.type}:${t.progress.toStringAsFixed(1)}')
        .join(',');
    final textSig = sample.texts
        .map(
          (t) =>
              '${t.text}|${t.fontSize}|${t.color}|${t.positionX.toStringAsFixed(0)}|${t.positionY.toStringAsFixed(0)}|${t.parameters['fontAssetId']}',
        )
        .join(';');
    final stickerSig = sample.stickers
        .map(
          (s) =>
              '${s.assetUrl}|${s.scale.toStringAsFixed(2)}|'
              '${s.positionX.toStringAsFixed(0)}|'
              '${s.positionY.toStringAsFixed(0)}|'
              '${s.parameters['label']}',
        )
        .join(';');
    final overlays = sample.overlays.length;
    return '$slot|t=${_playhead.toStringAsFixed(2)}|fx=$fx|fl=$fl|tr=$tr|tx=$textSig|stk=$stickerSig|ov=$overlays';
  }

  Future<void> _syncSurface({bool force = false}) async {
    if (_disposed) return;
    final t = _sampleTime;
    final playheadSlotId = _slotIdAtPlayhead(t);
    final sample = _preview?.sample(t);
    final item = sample == null ? null : _primaryMediaItem(sample.media);

    if (item != null) {
      final path = item.userMediaPath;
      if (path != null && path.isNotEmpty) {
        final slotId = item.slotId ??
            (item.id.startsWith('slot_') ? item.id.substring(5) : item.id);
        final sameSurface = !force &&
            slotId == _activeSlotId &&
            path == _presentedFilePath;
        if (sameSurface) {
          return;
        }
        if (_disposed) return;
        _activeSlotId = slotId;
        if (_mediaDetached) {
          final file = File(path);
          if (_isVideoFill(slotId, file, item)) {
            _imageFile = null;
            _clearDecoded();
          } else {
            _imageFile = file;
            final src = session.sourceFor(slotId);
            _setDecodedClone(
              src is ImageMediaSource ? src.decodedImage : null,
            );
          }
          _presentedFilePath = path;
          _safeNotify();
          return;
        }
        await _presentFile(
          file: File(path),
          slotId: slotId,
          item: item,
        );
        return;
      }
    }

    // Sample missed the slot clip — bind directly from fills at playhead.
    if (playheadSlotId != null) {
      final fill = session.fills[playheadSlotId];
      final file = fill?.localFile;
      if (fill?.hasMedia == true && file != null && file.path.isNotEmpty) {
        final sameSurface = !force &&
            playheadSlotId == _activeSlotId &&
            file.path == _presentedFilePath;
        if (!sameSurface) {
          _activeSlotId = playheadSlotId;
          if (_mediaDetached) {
            if (_isVideoFill(playheadSlotId, file, _slotTimelineItem(playheadSlotId))) {
              _imageFile = null;
              _clearDecoded();
            } else {
              _imageFile = file;
              final src = session.sourceFor(playheadSlotId);
              _setDecodedClone(
                src is ImageMediaSource ? src.decodedImage : null,
              );
            }
            _presentedFilePath = file.path;
            _safeNotify();
          } else {
            await _presentFile(
              file: file,
              slotId: playheadSlotId,
              item: _slotTimelineItem(playheadSlotId),
            );
          }
        }
        return;
      }

      // Empty slot at playhead — do not keep showing a previous slot.
      if (_activeSlotId != playheadSlotId || hasPreviewSurface) {
        await _clearVideo();
        _imageFile = null;
        _clearDecoded();
        _clearVideoLookStill();
        _activeSlotId = playheadSlotId;
        _presentedFilePath = null;
        _safeNotify();
      }
      return;
    }

    if (!_mediaDetached && hasPreviewSurface) return;
    await _syncFallbackFromFills();
  }

  /// When the timeline has no active media, show media for the playhead slot.
  Future<void> _syncFallbackFromFills() async {
    if (_disposed) return;
    final atPlayhead = _slotIdAtPlayhead(_sampleTime);
    if (atPlayhead != null) {
      final fill = session.fills[atPlayhead];
      final file = fill?.localFile;
      if (fill?.hasMedia == true && file != null && file.path.isNotEmpty) {
        if (await file.exists()) {
          _activeSlotId = atPlayhead;
          await _presentFile(
            file: file,
            slotId: atPlayhead,
            item: _slotTimelineItem(atPlayhead),
          );
          return;
        }
      }
    }
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
    _presentedFilePath = null;
  }

  Future<void> _presentFile({
    required File file,
    String? slotId,
    TimelineItem? item,
  }) async {
    final epoch = ++_surfaceEpoch;
    final mediaSource =
        slotId != null ? session.sourceFor(slotId) : null;
    final asVideo = _isVideoFill(slotId, file, item);

    if (!asVideo) {
      await _clearVideo();
      _clearVideoLookStill();
      if (_disposed || epoch != _surfaceEpoch) return;
      _imageFile = file;
      _presentedFilePath = file.path;
      final src =
          mediaSource is ImageMediaSource ? mediaSource.decodedImage : null;
      _setDecodedClone(src);
      if (_decodedImage == null) {
        unawaited(_warmStillTexture());
      }
      _safeNotify();
      return;
    }

    // Video clip — never use Image.file on an mp4 (blank / empty UI).
    _imageFile = null;
    _clearDecoded();
    await _clearVideo();
    if (_disposed || epoch != _surfaceEpoch) return;
    try {
      if (!await file.exists()) {
        debugPrint('CompositionPreview: video missing ${file.path}');
        return;
      }
      final c = VideoPlayerController.file(file);
      await c.initialize();
      if (_disposed || epoch != _surfaceEpoch) {
        await c.dispose();
        return;
      }
      c.setLooping(false);
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
      _presentedFilePath = file.path;
      c.addListener(_onVideoControllerUpdate);
      if (useVideoLookStill) {
        unawaited(refreshVideoLookStill());
      }
      _safeNotify();
    } catch (e, st) {
      if (epoch != _surfaceEpoch) return;
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
    _audioBedKey = null;
    unawaited(SoundAudioPreview.stop());
    _clearDecoded();
    _clearVideoLookStill();
    // Fire-and-forget video teardown — do not await in dispose.
    unawaited(_clearVideo());
    _preview = null;
    super.dispose();
  }
}
