import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/services/feed_video_disk_prefetcher.dart';
import 'package:bimobondapp/core/services/feed_video_prewarmer.dart';
import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:bimobondapp/core/widgets/blurred_icon_badge.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/video_loading_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

class CustomVideoPlayerController {
  _CustomVideoPlayerState? _state;

  bool get isPlaying => _state?.isPlaying ?? false;

  Future<void> togglePlayback() async {
    await _state?._togglePlayback();
  }

  void _attach(_CustomVideoPlayerState state) => _state = state;

  void _detach(_CustomVideoPlayerState state) {
    if (_state == state) _state = null;
  }
}

class CustomVideoPlayer extends StatefulWidget {
  const CustomVideoPlayer({
    super.key,
    required this.url,
    this.posterUrl,
    this.isActive = true,
    this.respectFeedPlaybackGate = true,
    this.controller,
    this.onPlaybackChanged,
    this.onLongPress,
  });

  final String url;
  final String? posterUrl;
  final bool isActive;

  /// When false, playback is not paused by [FeedPlaybackGate] (e.g. auction detail).
  final bool respectFeedPlaybackGate;
  final CustomVideoPlayerController? controller;
  final VoidCallback? onPlaybackChanged;
  final VoidCallback? onLongPress;

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer>
    with WidgetsBindingObserver {
  static const Duration _initTimeout = Duration(seconds: 20);

  VideoPlayerController? _controller;
  VoidCallback? _playbackListener;
  FeedVideoProgressNotifier? _progressNotifier;
  String? _errorMessage;
  bool _isInitializing = false;
  bool _playbackMuted = false;

  /// True only after the user tapped to pause. Auto states (starting up,
  /// buffering, adopting a prewarmed controller) must not show the pause UI.
  bool _userPaused = false;

  /// Whether the current controller has started playing at least once. Once
  /// it has, the poster is never overlaid again (the video's own frame is
  /// always better than flashing the thumbnail during brief buffering).
  bool _hasEverPlayed = false;
  int _initGeneration = 0;
  int _seekGeneration = 0;

  /// One silent MediaCodec recovery per video before showing the error UI.
  bool _codecRetryAttempted = false;

  /// True when this open came from park/disk — never flash the loader.
  bool _openedFromCache = false;

  /// False while the phone is locked / app backgrounded — stops audio then.
  bool _appInForeground = true;
  Uint8List? _generatedPosterBytes;
  bool _posterGenerationStarted = false;

  String get _resolvedUrl => MediaUtils.resolveAbsoluteUrl(widget.url);

  String? get _resolvedPosterUrl {
    final raw = widget.posterUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final resolved = MediaUtils.resolveAbsoluteUrl(raw);
    if (!MediaUtils.isLikelyImageUrl(resolved)) return null;
    return isValidNetworkImageUrl(resolved) ? resolved : null;
  }

  bool get _hasPosterVisual => _generatedPosterBytes != null;

  bool get _hasNetworkPosterAttempt => _resolvedPosterUrl != null;

  bool _isAudioFailure(Object? error) {
    final text = error?.toString().toLowerCase() ?? '';
    return text.contains('audiotrack') ||
        text.contains('audioflinger') ||
        text.contains('mediacodecaudiorenderer') ||
        (text.contains('exoplaybackexception') && text.contains('audio')) ||
        text.contains('error -12') ||
        text.contains('audio/3gpp');
  }

  bool _isVideoCodecFailure(Object? error) {
    final text = error?.toString().toLowerCase() ?? '';
    if (_isAudioFailure(error)) return false;
    return text.contains('mediacodec') ||
        text.contains('videorenderer') ||
        text.contains('decoder init') ||
        text.contains('videoerror') ||
        text.contains('format_supported') ||
        (text.contains('exoplayer') && text.contains('video'));
  }

  String _userFacingError(Object? error) {
    if (_isVideoCodecFailure(error)) {
      return 'Couldn\'t play this video. Tap Retry.';
    }
    if (_isAudioFailure(error)) {
      return 'Playing without sound on this device';
    }
    final text = error?.toString() ?? 'Video playback failed';
    // Strip raw PlatformException noise for the UI.
    if (text.contains('PlatformException') || text.length > 120) {
      return 'Couldn\'t play this video. Tap Retry.';
    }
    return text;
  }

  bool get isPlaying {
    final controller = _controller;
    if (controller == null || !_ownsController(controller)) return false;
    try {
      return controller.value.isInitialized && controller.value.isPlaying;
    } catch (_) {
      return false;
    }
  }

  bool get _shouldPlay =>
      widget.isActive &&
      _appInForeground &&
      (!widget.respectFeedPlaybackGate || FeedPlaybackGate.instance.allowed);

  bool _ownsController(VideoPlayerController? controller) {
    return controller != null && identical(controller, _controller);
  }

  bool _isControllerReady(VideoPlayerController? controller) {
    if (controller == null || !_ownsController(controller)) return false;
    try {
      return controller.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  /// Clears [_controller] synchronously so [build] never mounts [VideoPlayer]
  /// with a controller that is being torn down.
  (VideoPlayerController controller, VoidCallback listener)?
  _detachControllerSync() {
    final controller = _controller;
    if (controller == null) return null;
    final listener = _playbackListener ?? () {};
    _controller = null;
    _playbackListener = null;
    return (controller, listener);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.respectFeedPlaybackGate) {
      FeedPlaybackGate.instance.addListener(_onFeedPlaybackGateChanged);
    }
    widget.controller?._attach(this);
    _maybeGeneratePoster();
    if (_shouldPlay) {
      unawaited(_initController());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inForeground = state == AppLifecycleState.resumed;
    if (inForeground == _appInForeground) return;
    _appInForeground = inForeground;

    if (!inForeground) {
      // Lock screen / app switch: stop audio even if still initializing.
      _isInitializing = false;
      unawaited(SoundAudioPreview.stop());
      unawaited(_suspendPlayback());
      if (mounted) setState(() {});
      return;
    }

    if (_shouldPlay && !_userPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_shouldPlay || _userPaused) return;
        unawaited(_resumePlayback());
      });
    }
  }

  void _onFeedPlaybackGateChanged() {
    if (!_shouldPlay) {
      // Do not bump [_initGeneration]: that would orphan the existing
      // controller listener and freeze the feed progress bar after resume.
      _isInitializing = false;
      final controller = _controller;
      if (_isControllerReady(controller)) {
        unawaited(_suspendPlayback());
      }
      if (mounted) setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_shouldPlay) return;
      unawaited(_resumePlayback());
    });
  }

  Future<void> _suspendPlayback() async {
    _progressNotifier?.unbindSeekHandler(this);
    final controller = _controller;
    if (controller == null || !_isControllerReady(controller)) return;
    try {
      await controller.pause();
      await controller.setVolume(0);
      _syncFeedProgress(force: true);
    } catch (_) {}
  }

  Future<void> _resumePlayback() async {
    if (!_shouldPlay) return;
    final controller = _controller;
    if (controller != null && _isControllerReady(controller)) {
      final generation = _initGeneration;
      _rebindPlaybackListener(controller, generation);
      _progressNotifier?.bindSeekHandler(this, _seekFeedTo);
      await _startPlayback(controller, generation, muted: _playbackMuted);
      if (mounted && identical(controller, _controller)) {
        _syncFeedProgress();
        setState(() {});
      }
      return;
    }
    await _initController();
  }

  Future<void> _seekFeedTo(
    Duration position, {
    required bool resumePlayback,
  }) async {
    final controller = _controller;
    if (!_shouldPlay || controller == null || !_isControllerReady(controller)) {
      return;
    }
    final generation = ++_seekGeneration;
    try {
      await controller.seekTo(position);
      if (!mounted ||
          generation != _seekGeneration ||
          !identical(controller, _controller)) {
        return;
      }
      if (resumePlayback && !_userPaused && _shouldPlay) {
        await _startPlayback(
          controller,
          _initGeneration,
          muted: _playbackMuted,
        );
      } else if (!resumePlayback) {
        try {
          await controller.pause();
        } catch (_) {}
      }
      if (resumePlayback) {
        _syncFeedProgress(force: true);
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _rebindPlaybackListener(
    VideoPlayerController controller,
    int generation,
  ) {
    final old = _playbackListener;
    if (old != null) {
      try {
        controller.removeListener(old);
      } catch (_) {}
    }
    final listener = _makePlaybackListener(controller, generation);
    _playbackListener = listener;
    controller.addListener(listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progressNotifier = FeedVideoProgressScope.maybeOf(context);
  }

  @override
  void didUpdateWidget(CustomVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.respectFeedPlaybackGate != widget.respectFeedPlaybackGate) {
      if (widget.respectFeedPlaybackGate) {
        FeedPlaybackGate.instance.addListener(_onFeedPlaybackGateChanged);
      } else {
        FeedPlaybackGate.instance.removeListener(_onFeedPlaybackGateChanged);
        if (widget.isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_shouldPlay) return;
            unawaited(_resumePlayback());
          });
        }
      }
    }
    if (oldWidget.posterUrl != widget.posterUrl) {
      _generatedPosterBytes = null;
      _posterGenerationStarted = false;
      _maybeGeneratePoster();
    }
    if (oldWidget.url != widget.url) {
      _generatedPosterBytes = null;
      _posterGenerationStarted = false;
      _playbackMuted = false;
      _userPaused = false;
      _hasEverPlayed = false;
      _codecRetryAttempted = false;
      _openedFromCache = false;
      _maybeGeneratePoster();
      if (_shouldPlay) {
        unawaited(_initController());
      } else {
        unawaited(_releasePlayer());
      }
      return;
    }
    if (oldWidget.isActive != widget.isActive) {
      if (_shouldPlay) {
        _maybeGeneratePoster();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_shouldPlay) return;
          unawaited(_resumePlayback());
        });
      } else {
        // Soft-pause while the page is still mounted; dispose parks for reuse.
        _progressNotifier?.unbindSeekHandler(this);
        unawaited(_suspendPlayback());
      }
    } else if (oldWidget.isActive == widget.isActive &&
        widget.isActive &&
        _shouldPlay &&
        !_isControllerReady(_controller)) {
      unawaited(_initController());
    }
  }

  void _maybeGeneratePoster() {
    if (_posterGenerationStarted) return;
    if (_resolvedPosterUrl != null) return;
    _posterGenerationStarted = true;
    unawaited(_generatePosterFromVideo());
  }

  Future<void> _generatePosterFromVideo() async {
    final url = _resolvedUrl;
    if (url.isEmpty || !MediaUtils.isVideo(url)) return;

    try {
      final bytes = await VideoThumbnailUtils.generateThumbnailBytes(
        url,
        timeMs: 0,
        quality: 70,
        maxHeight: 720,
      );
      if (!mounted || bytes == null) return;
      setState(() => _generatedPosterBytes = bytes);
    } catch (e) {
      debugPrint('Video poster generation failed: $e');
    }
  }

  VoidCallback _makePlaybackListener(
    VideoPlayerController controller,
    int generation,
  ) {
    return () {
      if (!mounted || generation != _initGeneration) return;
      if (!identical(controller, _controller)) return;
      try {
        if (controller.value.hasError) {
          final description =
              controller.value.errorDescription ?? 'Video playback failed';
          if (_isAudioFailure(description)) {
            unawaited(_startPlayback(controller, generation, muted: true));
            return;
          }
          unawaited(_handlePlaybackFailure(description));
        } else {
          if (mounted) setState(() {});
          _syncFeedProgress();
          _notifyPlaybackChanged();
        }
      } catch (_) {}
    };
  }

  Future<void> _handlePlaybackFailure(Object error) async {
    if (!mounted) return;

    // Free other decoders, then retry once — usually clears MediaCodec errors.
    if (_isVideoCodecFailure(error) && !_codecRetryAttempted) {
      _codecRetryAttempted = true;
      debugPrint(
        'Video codec failure — clearing warm pool and retrying: $error',
      );
      FeedVideoPrewarmer.instance.clear();
      FeedVideoDiskPrefetcher.instance.clear();
      final detached = _detachControllerSync();
      if (detached != null) {
        unawaited(_disposeController(detached.$1, detached.$2));
      }
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _isInitializing = false;
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted || !_shouldPlay) return;
      await _initController();
      return;
    }

    if (!mounted) return;
    setState(() => _errorMessage = _userFacingError(error));
    _syncFeedProgress();
  }

  /// Takes ownership of an already-initialized [controller] (from the
  /// prewarmer) and starts playback immediately.
  Future<void> _attachAndPlay(
    VideoPlayerController controller,
    int generation,
  ) async {
    _controller = controller;
    final listener = _makePlaybackListener(controller, generation);
    _playbackListener = listener;
    controller.addListener(listener);

    _isInitializing = false;
    if (mounted) setState(() {});

    final ok = await _startPlayback(controller, generation, muted: false);
    if (!ok && mounted && generation == _initGeneration) {
      final mutedOk = await _startPlayback(controller, generation, muted: true);
      if (!mutedOk && !identical(controller, _controller)) return;
      if (!mutedOk && mounted && generation == _initGeneration) {
        setState(() {
          _errorMessage = 'Video unavailable (audio not supported)';
        });
      }
    }
  }

  Future<void> _initController() async {
    if (!_shouldPlay || _isInitializing) return;

    final url = _resolvedUrl;
    if (url.isEmpty) {
      if (!mounted) return;
      setState(() => _errorMessage = 'No video URL');
      return;
    }

    // Adopt parked controller first — zero loading flash on scroll up/down.
    final prewarmed = FeedVideoPrewarmer.instance.take(url);
    if (prewarmed != null) {
      if (prewarmed.value.isInitialized && !prewarmed.value.hasError) {
        final generation = ++_initGeneration;
        final previous = _detachControllerSync();
        if (previous != null) {
          unawaited(_parkController(previous.$1, previous.$2));
        }
        _openedFromCache = true;
        _userPaused = false;
        _errorMessage = null;
        try {
          if (prewarmed.value.position > Duration.zero ||
              prewarmed.value.isPlaying) {
            _hasEverPlayed = true;
          }
        } catch (_) {
          _hasEverPlayed = true;
        }
        FeedVideoDiskPrefetcher.instance.setPlayingUrl(url);
        await _attachAndPlay(prewarmed, generation);
        return;
      }
      unawaited(prewarmed.dispose());
    }

    final generation = ++_initGeneration;
    _isInitializing = true;
    _openedFromCache = false;
    _userPaused = false;
    // Keep last frame / poster feel — don't force poster flash on reopen.
    if (mounted) setState(() => _errorMessage = null);

    final previous = _detachControllerSync();
    if (previous != null) {
      unawaited(_parkController(previous.$1, previous.$2));
    }

    FeedVideoDiskPrefetcher.instance.setPlayingUrl(url);

    final options = VideoPlayerOptions(
      mixWithOthers: false,
      allowBackgroundPlayback: false,
    );

    final cachedFile = await AppMediaCacheManager.getCachedVideoFile(url);
    if (!mounted || generation != _initGeneration || !_shouldPlay) {
      _isInitializing = false;
      return;
    }

    var usedFile = cachedFile != null;
    if (usedFile) _openedFromCache = true;
    var controller = cachedFile != null
        ? VideoPlayerController.file(cachedFile, videoPlayerOptions: options)
        : VideoPlayerController.networkUrl(
            Uri.parse(url),
            videoPlayerOptions: options,
          );
    _controller = controller;

    var listener = _makePlaybackListener(controller, generation);
    _playbackListener = listener;
    controller.addListener(listener);

    try {
      await controller.initialize().timeout(
        _initTimeout,
        onTimeout: () => throw TimeoutException(
          'Could not load video in ${_initTimeout.inSeconds}s.',
        ),
      );
      await controller.setLooping(true);

      if (!mounted || generation != _initGeneration || !_shouldPlay) {
        final detached = _detachControllerSync();
        if (detached != null && identical(detached.$1, controller)) {
          await _disposeController(detached.$1, detached.$2);
        } else {
          await _disposeController(controller, listener);
        }
        return;
      }

      if (mounted) setState(() => _isInitializing = false);

      final ok = await _startPlayback(controller, generation, muted: false);
      if (!ok && mounted && generation == _initGeneration) {
        final mutedOk = await _startPlayback(
          controller,
          generation,
          muted: true,
        );
        if (!mutedOk) {
          setState(() {
            _errorMessage = 'Video unavailable (audio not supported)';
          });
        }
      }
    } catch (e) {
      Object error = e;
      debugPrint('Video player initialization error: $error');
      await _disposeController(controller, listener);
      if (identical(_controller, controller)) {
        _controller = null;
        _playbackListener = null;
      }

      // Corrupt disk entry → drop and retry from network once.
      if (usedFile &&
          mounted &&
          generation == _initGeneration &&
          _shouldPlay) {
        await AppMediaCacheManager.removeCachedVideoFile(url);
        usedFile = false;
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: options,
        );
        _controller = controller;
        listener = _makePlaybackListener(controller, generation);
        _playbackListener = listener;
        controller.addListener(listener);
        try {
          await controller.initialize().timeout(_initTimeout);
          await controller.setLooping(true);
          if (!mounted || generation != _initGeneration || !_shouldPlay) {
            await _disposeController(controller, listener);
            return;
          }
          if (mounted) setState(() => _isInitializing = false);
          await _startPlayback(controller, generation, muted: false);
          return;
        } catch (e2) {
          debugPrint('Network fallback failed: $e2');
          await _disposeController(controller, listener);
          if (identical(_controller, controller)) {
            _controller = null;
            _playbackListener = null;
          }
          error = e2;
        }
      }

      if (!mounted || generation != _initGeneration) {
        _isInitializing = false;
        return;
      }
      _isInitializing = false;
      await _handlePlaybackFailure(error);
    } finally {
      if (generation == _initGeneration) {
        _isInitializing = false;
      }
    }
  }

  Future<bool> _startPlayback(
    VideoPlayerController controller,
    int generation, {
    bool? muted,
  }) async {
    if (!_shouldPlay ||
        generation != _initGeneration ||
        !identical(controller, _controller)) {
      return false;
    }

    final wantMuted = muted ?? _playbackMuted;
    try {
      if (!_isControllerReady(controller)) return false;
      await controller.setVolume(wantMuted ? 0 : 1);
      _playbackMuted = wantMuted;
      await controller.play();
      if (!mounted ||
          generation != _initGeneration ||
          !identical(controller, _controller)) {
        return false;
      }
      _userPaused = false;
      _hasEverPlayed = true;
      FeedVideoDiskPrefetcher.instance.markPlaybackSettled();
      setState(() => _errorMessage = null);
      _syncFeedProgress();
      _notifyPlaybackChanged();
      return true;
    } on PlatformException catch (e) {
      debugPrint('Video play failed: $e');
      if (!wantMuted && _isAudioFailure(e)) {
        return _startPlayback(controller, generation, muted: true);
      }
      return false;
    } catch (e) {
      debugPrint('Video play failed: $e');
      if (!wantMuted && _isAudioFailure(e)) {
        return _startPlayback(controller, generation, muted: true);
      }
      return false;
    }
  }

  void _notifyPlaybackChanged() {
    widget.onPlaybackChanged?.call();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null ||
        !_isControllerReady(controller) ||
        _isInitializing) {
      return;
    }
    try {
      if (controller.value.isPlaying) {
        _userPaused = true;
        await controller.pause();
      } else {
        await _startPlayback(
          controller,
          _initGeneration,
          muted: _playbackMuted,
        );
      }
      if (mounted) setState(() {});
      _syncFeedProgress();
      _notifyPlaybackChanged();
    } catch (_) {}
  }

  Future<void> _disposeController(
    VideoPlayerController controller,
    VoidCallback listener,
  ) async {
    controller.removeListener(listener);
    try {
      if (controller.value.isInitialized) {
        await controller.pause();
        await controller.setVolume(0);
      }
    } catch (_) {}
    await controller.dispose();
  }

  Future<void> _releasePlayer({bool park = false}) async {
    _initGeneration++;
    _isInitializing = false;
    _playbackMuted = false;
    _userPaused = false;
    if (!park) _hasEverPlayed = false;
    final url = _resolvedUrl;
    final detached = _detachControllerSync();
    FeedVideoDiskPrefetcher.instance.setPlayingUrl(null);
    if (mounted) setState(() {});
    if (detached == null) return;
    if (park) {
      await _parkController(detached.$1, detached.$2);
    } else {
      await _disposeController(detached.$1, detached.$2);
    }
    if (url.isNotEmpty && AppMediaCacheManager.canDiskCacheVideo(url)) {
      FeedVideoDiskPrefetcher.instance.enqueueAfterWatch(url);
    }
  }

  Future<void> _parkController(
    VideoPlayerController controller,
    VoidCallback listener,
  ) async {
    try {
      controller.removeListener(listener);
    } catch (_) {}
    try {
      if (controller.value.isInitialized) {
        await controller.pause();
        await controller.setVolume(0);
      }
    } catch (_) {}
    final url = _resolvedUrl;
    if (url.isNotEmpty) {
      FeedVideoPrewarmer.instance.offer(url, controller);
    } else {
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  void _syncFeedProgress({bool force = false}) {
    if (!mounted) return;
    if (!force && !_shouldPlay) return;
    final notifier = _progressNotifier;
    final controller = _controller;
    if (notifier == null ||
        controller == null ||
        !_isControllerReady(controller)) {
      return;
    }
    if (_shouldPlay) {
      notifier.bindSeekHandler(this, _seekFeedTo);
    }
    try {
      final value = controller.value;
      notifier.updateFromPlayback(
        position: value.position,
        duration: value.duration,
        isPlaying: value.isPlaying && !_userPaused,
      );
    } catch (_) {}
  }

  void _resetFeedProgress() {
    _progressNotifier?.unbindSeekHandler(this);
    _progressNotifier?.reset();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !_isControllerReady(controller)) return;
    try {
      if (_playbackMuted) {
        await controller.setVolume(1);
        _playbackMuted = false;
      } else {
        await controller.setVolume(0);
        _playbackMuted = true;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Unmute failed (emulator limit): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sound unavailable on this device'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.respectFeedPlaybackGate) {
      FeedPlaybackGate.instance.removeListener(_onFeedPlaybackGateChanged);
    }
    widget.controller?._detach(this);
    _progressNotifier?.unbindSeekHandler(this);
    _initGeneration++;
    if (widget.isActive) _resetFeedProgress();
    final detached = _detachControllerSync();
    if (detached != null) {
      FeedVideoDiskPrefetcher.instance.setPlayingUrl(null);
      final url = _resolvedUrl;
      unawaited(() async {
        await _parkController(detached.$1, detached.$2);
        if (url.isNotEmpty && AppMediaCacheManager.canDiskCacheVideo(url)) {
          FeedVideoDiskPrefetcher.instance.enqueueAfterWatch(url);
        }
      }());
    }
    super.dispose();
  }

  bool _shouldShowPosterOverlay() {
    if (_errorMessage != null) return false;
    if (!_hasPosterVisual && !_hasNetworkPosterAttempt) return false;
    // Once the video has rendered, its own frame stays up during brief
    // buffering; flashing the thumbnail over it looks like a glitch.
    if (_hasEverPlayed) return false;
    final controller = _controller;
    if (controller == null || !_isControllerReady(controller)) return true;
    try {
      return controller.value.isBuffering;
    } catch (_) {
      return true;
    }
  }

  Widget _buildPosterLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        // BoxFit.contain so the poster is letterboxed exactly like the video
        // (Center + AspectRatio) — no zoomed full-screen frame that jumps to
        // the real post size once playback starts.
        if (_resolvedPosterUrl != null)
          SafeNetworkImage(
            imageUrl: _resolvedPosterUrl!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            blankOnError: true,
          ),
        if (_generatedPosterBytes != null)
          Image.memory(
            _generatedPosterBytes!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // Keep the texture mounted while soft-paused so scroll-back does not
    // flash a black/poster frame before play resumes.
    final canMountVideoPlayer =
        controller != null &&
        identical(controller, _controller) &&
        _isControllerReady(controller) &&
        !_isInitializing;
    final isReady = canMountVideoPlayer;
    final isBuffering = isReady && _readIsBuffering(controller);
    // Only a deliberate tap-to-pause shows the pause UI; transient not-playing
    // states (startup, prewarmed handover, buffering) must not flash it.
    final isPaused =
        widget.isActive &&
        isReady &&
        !isBuffering &&
        _userPaused &&
        !_readIsPlaying(controller);

    if (_errorMessage != null && !isReady) {
      return _buildError();
    }

    final showVideoLoading =
        widget.isActive &&
        _shouldPlay &&
        (!canMountVideoPlayer || isBuffering) &&
        // Never flash loader on scroll-back / disk reopen / poster-ready opens.
        !_openedFromCache &&
        !_hasEverPlayed &&
        !_hasPosterVisual;

    return GestureDetector(
      onTap: () => unawaited(_togglePlayback()),
      onLongPress: widget.onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_hasPosterVisual || _hasNetworkPosterAttempt) _buildPosterLayer(),
          if (!isReady && !_hasPosterVisual && !_hasNetworkPosterAttempt)
            const ColoredBox(color: Colors.black),
          if (canMountVideoPlayer)
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _readAspectRatio(controller),
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          if (_shouldShowPosterOverlay())
            Positioned.fill(child: _buildPosterLayer()),
          if (showVideoLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 2,
              child: const Center(child: VideoLoadingIndicator()),
            ),
          if (isPaused)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _toggleMute,
                    child: BlurredIconBadge(
                      icon: _playbackMuted
                          ? LucideIcons.volumeX
                          : LucideIcons.volume2,
                      diameter: 40,
                      iconSize: 22,
                      iconColor: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BlurredIconBadge(
                    icon: LucideIcons.play,
                    diameter: 88,
                    iconSize: 44,
                    iconColor: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _readAspectRatio(VideoPlayerController controller) {
    try {
      final ratio = controller.value.aspectRatio;
      return ratio == 0 ? 9 / 16 : ratio;
    } catch (_) {
      return 9 / 16;
    }
  }

  bool _readIsBuffering(VideoPlayerController controller) {
    try {
      return controller.value.isBuffering;
    } catch (_) {
      return false;
    }
  }

  bool _readIsPlaying(VideoPlayerController controller) {
    try {
      return controller.value.isPlaying;
    } catch (_) {
      return false;
    }
  }

  Widget _buildError() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.circleAlert,
                color: Colors.white54,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              TextButton(
                onPressed: () {
                  _codecRetryAttempted = false;
                  unawaited(_initController());
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
