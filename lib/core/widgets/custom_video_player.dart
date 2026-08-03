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

typedef FeedVideoSeekSync =
    Future<void> Function(Duration position, {required bool resumePlayback});

class CustomVideoPlayerController {
  _CustomVideoPlayerState? _state;

  bool get isPlaying => _state?.isPlaying ?? false;

  Duration get playbackPosition => _state?.playbackPosition ?? Duration.zero;

  Duration get playbackDuration => _state?.playbackDuration ?? Duration.zero;

  Future<void> togglePlayback() async {
    await _state?._togglePlayback();
  }

  Future<void> setMuted(bool muted) async {
    await _state?._setMuted(muted);
  }

  Future<void> pausePlayback() async {
    await _state?._pausePlaybackForSync();
  }

  Future<void> restartFromBeginning() async {
    await _state?._restartFromBeginning();
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
    this.fallbackUrl,
    this.posterUrl,
    this.isActive = true,
    this.respectFeedPlaybackGate = true,

    /// When true, video track stays silent (external soundtrack is playing).
    this.muteAudio = false,
    this.controller,
    this.onPlaybackChanged,
    this.onSeekSync,
    this.onUserMuteChanged,
    this.onSegmentEnd,
    this.onVideoDurationReady,
    this.onLongPress,
    this.loopVideo = true,
    this.segmentMaxPosition,
    this.fit = BoxFit.contain,
  });

  final String url;
  final String? fallbackUrl;
  final String? posterUrl;
  final bool isActive;

  /// When false, playback is not paused by [FeedPlaybackGate] (e.g. auction detail).
  final bool respectFeedPlaybackGate;

  /// Force-mute the video's own audio (e.g. while a library sound plays).
  final bool muteAudio;
  final CustomVideoPlayerController? controller;
  final VoidCallback? onPlaybackChanged;
  final FeedVideoSeekSync? onSeekSync;
  final ValueChanged<bool>? onUserMuteChanged;
  final VoidCallback? onSegmentEnd;
  final ValueChanged<Duration>? onVideoDurationReady;
  final VoidCallback? onLongPress;
  final bool loopVideo;
  final Duration? segmentMaxPosition;

  /// Feed videos use contain so the posted frame matches the recording
  /// (no cover-zoom crop). Images still use [mediaFit].
  final BoxFit fit;

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer>
    with WidgetsBindingObserver {
  static const Duration _initTimeout = Duration(seconds: 60);

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

  /// Switched to [CustomVideoPlayer.fallbackUrl] after primary stream failed.
  bool _usingFallbackUrl = false;

  /// One automatic retry for slow / flaky networks before showing Retry UI.
  bool _networkRetryAttempted = false;

  /// False while the phone is locked / app backgrounded — stops audio then.
  bool _appInForeground = true;
  Uint8List? _generatedPosterBytes;
  bool _posterGenerationStarted = false;
  int _feedHandoffGeneration = 0;
  bool _segmentEndHandled = false;

  String get _resolvedUrl => MediaUtils.resolveAbsoluteUrl(widget.url);

  String get _effectivePlaybackUrl {
    if (_usingFallbackUrl) {
      final fallback = widget.fallbackUrl?.trim();
      if (fallback != null && fallback.isNotEmpty) {
        return MediaUtils.resolveAbsoluteUrl(fallback);
      }
    }
    return _resolvedUrl;
  }

  String? get _resolvedPosterUrl {
    final raw = widget.posterUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final resolved = MediaUtils.resolveAbsoluteUrl(raw);
    if (!MediaUtils.isLikelyImageUrl(resolved)) return null;
    return isValidNetworkImageUrl(resolved) ? resolved : null;
  }

  bool get _hasPosterVisual => _generatedPosterBytes != null;

  void _syncFeedHandoffGeneration() {
    final notifier =
        _progressNotifier ?? FeedVideoProgressScope.maybeOf(context);
    if (notifier != null) {
      _feedHandoffGeneration = notifier.handoffGeneration;
    }
  }

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

  bool _isTransientNetworkError(Object? error) {
    if (error is TimeoutException) return true;
    final text = error?.toString().toLowerCase() ?? '';
    return text.contains('timeout') ||
        text.contains('socket') ||
        text.contains('connection') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('temporarily unavailable') ||
        text.contains('503') ||
        text.contains('504');
  }

  /// HLS ↔ progressive fallback or one delayed retry on slow networks.
  Future<bool> _tryRecoverFromInitFailure(Object error, int generation) async {
    if (!mounted || generation != _initGeneration || !_shouldPlay) {
      return false;
    }
    if (_isVideoCodecFailure(error)) return false;

    final fallback = widget.fallbackUrl?.trim();
    if (!_usingFallbackUrl &&
        fallback != null &&
        fallback.isNotEmpty &&
        MediaUtils.resolveAbsoluteUrl(fallback) != _resolvedUrl) {
      _usingFallbackUrl = true;
      _networkRetryAttempted = false;
      _codecRetryAttempted = false;
      if (mounted) setState(() => _errorMessage = null);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted || generation != _initGeneration) return false;
      _isInitializing = false;
      await _initController();
      return true;
    }

    if (!_networkRetryAttempted && _isTransientNetworkError(error)) {
      _networkRetryAttempted = true;
      if (mounted) setState(() => _errorMessage = null);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted || generation != _initGeneration) return false;
      _isInitializing = false;
      await _initController();
      return true;
    }
    return false;
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
      return controller.value.isInitialized &&
          controller.value.isPlaying &&
          !_userPaused;
    } catch (_) {
      return false;
    }
  }

  Duration get playbackPosition {
    final controller = _controller;
    if (controller == null || !_isControllerReady(controller)) {
      return Duration.zero;
    }
    try {
      return controller.value.position;
    } catch (_) {
      return Duration.zero;
    }
  }

  Duration get playbackDuration {
    final controller = _controller;
    if (controller == null || !_isControllerReady(controller)) {
      return Duration.zero;
    }
    try {
      return controller.value.duration;
    } catch (_) {
      return Duration.zero;
    }
  }

  int? _lastReportedDurationMs;

  void _maybeReportVideoDuration(VideoPlayerController controller) {
    if (widget.onVideoDurationReady == null) return;
    try {
      final ms = controller.value.duration.inMilliseconds;
      if (ms <= 0 || ms == _lastReportedDurationMs) return;
      _lastReportedDurationMs = ms;
      widget.onVideoDurationReady!(Duration(milliseconds: ms));
    } catch (_) {}
  }

  bool get _shouldPlay =>
      widget.isActive &&
      _appInForeground &&
      FeedPlaybackGate.instance.playbackAllowed(
        respectFeedPlaybackGate: widget.respectFeedPlaybackGate,
      );

  /// Dedicated viewers (search post detail, profile fullscreen) keep the
  /// progress bar interactive even when the feed gate would block playback.
  bool get _allowsFeedScrub {
    if (!widget.isActive || !_appInForeground) return false;
    if (!_isControllerReady(_controller)) return false;
    if (!widget.respectFeedPlaybackGate) return true;
    return _shouldPlay;
  }

  bool get _shouldSyncFeedProgress =>
      _shouldPlay || (!widget.respectFeedPlaybackGate && widget.isActive);

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
    FeedPlaybackGate.instance.addListener(_onFeedPlaybackGateChanged);
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
      if (widget.isActive) {
        _progressNotifier?.setVideoLoading(
          false,
          handoff: _feedHandoffGeneration,
        );
      }
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
      if (widget.muteAudio) {
        _notifyPlaybackChanged();
      }
      await controller.pause();
      await controller.setVolume(0);
      _syncFeedProgress(force: true);
      _notifyPlaybackChanged();
    } catch (_) {}
  }

  Future<void> _resumePlayback() async {
    if (!_shouldPlay || _userPaused) return;
    final controller = _controller;
    if (controller != null && _isControllerReady(controller)) {
      final generation = _initGeneration;
      _rebindPlaybackListener(controller, generation);
      if (_allowsFeedScrub) {
        _progressNotifier?.bindSeekHandler(this, _seekFeedTo);
      }
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
    if (!_allowsFeedScrub ||
        controller == null ||
        !_isControllerReady(controller)) {
      return;
    }
    final generation = ++_seekGeneration;
    var target = position;
    final maxPos = widget.segmentMaxPosition;
    if (maxPos != null) {
      if (target > maxPos) target = maxPos;
      if (target.isNegative) target = Duration.zero;
      if (target < maxPos - const Duration(milliseconds: 80)) {
        _segmentEndHandled = false;
      }
    }
    try {
      await controller.seekTo(target);
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
      await widget.onSeekSync?.call(target, resumePlayback: resumePlayback);
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
    if (widget.isActive && _shouldPlay) {
      _syncFeedHandoffGeneration();
    }
  }

  @override
  void didUpdateWidget(CustomVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.respectFeedPlaybackGate != widget.respectFeedPlaybackGate) {
      if (widget.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_shouldPlay) {
            unawaited(_resumePlayback());
          } else {
            unawaited(_suspendPlayback());
          }
        });
      }
    }
    if (oldWidget.posterUrl != widget.posterUrl) {
      _generatedPosterBytes = null;
      _posterGenerationStarted = false;
      _maybeGeneratePoster();
    }
    if (oldWidget.muteAudio != widget.muteAudio) {
      unawaited(_setMuted(widget.muteAudio));
    }
    if (oldWidget.url != widget.url ||
        oldWidget.fallbackUrl != widget.fallbackUrl) {
      _generatedPosterBytes = null;
      _posterGenerationStarted = false;
      _playbackMuted = false;
      _userPaused = false;
      _hasEverPlayed = false;
      _codecRetryAttempted = false;
      _usingFallbackUrl = false;
      _networkRetryAttempted = false;
      _segmentEndHandled = false;
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
        _syncFeedHandoffGeneration();
        _maybeGeneratePoster();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_shouldPlay) return;
          _syncFeedHandoffGeneration();
          unawaited(_resumePlayback());
          _updateFeedVideoLoadingState(_controller);
          _syncFeedProgress(force: true);
        });
      } else {
        // Soft-pause while the page is still mounted; dispose parks for reuse.
        _progressNotifier?.unbindSeekHandler(this);
        if (oldWidget.isActive) {
          _progressNotifier?.setVideoLoading(
            false,
            handoff: _feedHandoffGeneration,
          );
        }
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
    final url = _effectivePlaybackUrl;
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
          if (controller.value.isPlaying &&
              !controller.value.isBuffering &&
              controller.value.isInitialized) {
            _hasEverPlayed = true;
          }
          if (mounted) setState(() {});
          _maybeLoopSegmentPlayback(controller);
          _maybeReportVideoDuration(controller);
          _syncFeedProgress();
          _notifyPlaybackChanged();
          _updateFeedVideoLoadingState(controller);
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
    if (mounted && generation == _initGeneration) {
      _updateFeedVideoLoadingState(_controller);
    }
  }

  Future<void> _initController() async {
    if (!_shouldPlay || _isInitializing) return;

    final url = _effectivePlaybackUrl;
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
      await controller.setLooping(widget.loopVideo);
      _maybeReportVideoDuration(controller);

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
      if (usedFile && mounted && generation == _initGeneration && _shouldPlay) {
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
          await controller.setLooping(widget.loopVideo);
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
      if (await _tryRecoverFromInitFailure(error, generation)) {
        return;
      }
      await _handlePlaybackFailure(error);
    } finally {
      if (generation == _initGeneration) {
        _isInitializing = false;
        if (mounted) {
          _updateFeedVideoLoadingState(_controller);
          if (!widget.respectFeedPlaybackGate && widget.isActive) {
            _syncFeedProgress(force: true);
          }
        }
      }
    }
  }

  Future<bool> _startPlayback(
    VideoPlayerController controller,
    int generation, {
    bool? muted,
  }) async {
    if (_userPaused ||
        !_shouldPlay ||
        generation != _initGeneration ||
        !identical(controller, _controller)) {
      return false;
    }

    final userMuted = muted ?? _playbackMuted;
    try {
      if (!_isControllerReady(controller)) return false;
      if (widget.muteAudio) {
        await controller.setVolume(0);
        if (_playbackMuted) {
          widget.onUserMuteChanged?.call(_playbackMuted);
        }
      } else {
        await controller.setVolume(userMuted ? 0 : 1);
        _playbackMuted = userMuted;
      }
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
      _updateFeedVideoLoadingState(controller);
      _notifyPlaybackChanged();
      return true;
    } on PlatformException catch (e) {
      debugPrint('Video play failed: $e');
      if (!widget.muteAudio && !userMuted && _isAudioFailure(e)) {
        return _startPlayback(controller, generation, muted: true);
      }
      return false;
    } catch (e) {
      debugPrint('Video play failed: $e');
      if (!widget.muteAudio && !userMuted && _isAudioFailure(e)) {
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
      final effectivelyPlaying = controller.value.isPlaying && !_userPaused;
      if (effectivelyPlaying) {
        _userPaused = true;
        if (widget.muteAudio) {
          _notifyPlaybackChanged();
        }
        await controller.pause();
      } else {
        _userPaused = false;
        final maxPos = widget.segmentMaxPosition;
        if (maxPos != null &&
            controller.value.position >=
                maxPos - const Duration(milliseconds: 80)) {
          _segmentEndHandled = false;
          await _seekFeedTo(Duration.zero, resumePlayback: true);
          return;
        }
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

  Future<void> _pausePlaybackForSync() async {
    final controller = _controller;
    if (controller == null || !_isControllerReady(controller)) return;
    try {
      if (widget.muteAudio) {
        _notifyPlaybackChanged();
      }
      await controller.pause();
      if (mounted) setState(() {});
      _syncFeedProgress();
      _notifyPlaybackChanged();
    } catch (_) {}
  }

  Future<void> _restartFromBeginning() async {
    _segmentEndHandled = false;
    await _seekFeedTo(Duration.zero, resumePlayback: false);
  }

  void _maybeLoopSegmentPlayback(VideoPlayerController controller) {
    final maxPos = widget.segmentMaxPosition;

    if (maxPos != null) {
      if (controller.value.position <
          maxPos - const Duration(milliseconds: 120)) {
        _segmentEndHandled = false;
        return;
      }
    } else if (widget.loopVideo) {
      // Native loop is enabled — only intervene if platform stalled at natural end.
      final duration = controller.value.duration;
      final nearNaturalEnd =
          duration.inMilliseconds > 0 &&
          controller.value.position >=
              duration - const Duration(milliseconds: 120);
      if (!controller.value.isCompleted && !nearNaturalEnd) {
        if (controller.value.position < const Duration(milliseconds: 300)) {
          _segmentEndHandled = false;
        }
        return;
      }
    } else {
      return;
    }

    if (_segmentEndHandled) return;
    _segmentEndHandled = true;
    unawaited(_replaySegmentFromStart(controller));
  }

  Future<void> _replaySegmentFromStart(VideoPlayerController controller) async {
    try {
      await controller.seekTo(Duration.zero);
      if (_shouldPlay && !_userPaused) {
        final ok = await _startPlayback(
          controller,
          _initGeneration,
          muted: _playbackMuted,
        );
        if (!ok && _isControllerReady(controller)) {
          await controller.play();
        }
      }
    } catch (_) {}
    widget.onSegmentEnd?.call();
    if (mounted) {
      _syncFeedProgress();
      _notifyPlaybackChanged();
    }
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
    final url = _effectivePlaybackUrl;
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
    final url = _effectivePlaybackUrl;
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
    if (!force && !_shouldSyncFeedProgress) return;
    final notifier = _progressNotifier;
    final controller = _controller;
    if (notifier == null ||
        controller == null ||
        !_isControllerReady(controller)) {
      return;
    }
    if (_allowsFeedScrub) {
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
    _progressNotifier?.setVideoLoading(false, handoff: _feedHandoffGeneration);
    _progressNotifier?.reset();
  }

  bool get _ownsFeedProgressBar => widget.isActive && _shouldPlay;

  void _publishFeedVideoLoading(bool show) {
    if (!_ownsFeedProgressBar) return;
    final notifier =
        _progressNotifier ?? FeedVideoProgressScope.maybeOf(context);
    if (notifier == null) return;
    if (show && notifier.scrubbing) return;
    notifier.setVideoLoading(show, handoff: _feedHandoffGeneration);
  }

  bool _shouldShowVideoLoading({
    required bool canMountVideoPlayer,
    required bool isBuffering,
  }) {
    if (!widget.isActive || !_shouldPlay) return false;

    if (_hasEverPlayed) {
      return canMountVideoPlayer && isBuffering;
    }

    return _isInitializing || !canMountVideoPlayer || isBuffering;
  }

  void _updateFeedVideoLoadingState(VideoPlayerController? controller) {
    if (!_ownsFeedProgressBar) return;
    final ready = controller != null && _isControllerReady(controller);
    final buffering = ready && _readIsBuffering(controller);
    final show = _shouldShowVideoLoading(
      canMountVideoPlayer: ready && !_isInitializing,
      isBuffering: buffering,
    );
    _publishFeedVideoLoading(show);
  }

  Future<void> _setMuted(bool muted) async {
    if (widget.muteAudio) {
      // Library soundtrack plays separately — only silence the video track.
      final controller = _controller;
      if (controller == null || !_isControllerReady(controller)) return;
      try {
        await controller.setVolume(0);
        if (mounted) setState(() {});
      } catch (_) {}
      return;
    }

    final controller = _controller;
    if (controller == null || !_isControllerReady(controller)) {
      _playbackMuted = muted;
      return;
    }
    try {
      await controller.setVolume(muted ? 0 : 1);
      _playbackMuted = muted;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _toggleMute() async {
    if (widget.muteAudio) {
      _playbackMuted = !_playbackMuted;
      widget.onUserMuteChanged?.call(_playbackMuted);
      if (mounted) setState(() {});
      return;
    }
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
      widget.onUserMuteChanged?.call(_playbackMuted);
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
    FeedPlaybackGate.instance.removeListener(_onFeedPlaybackGateChanged);
    widget.controller?._detach(this);
    _progressNotifier?.unbindSeekHandler(this);
    _initGeneration++;
    if (widget.isActive) _resetFeedProgress();
    final detached = _detachControllerSync();
    if (detached != null) {
      FeedVideoDiskPrefetcher.instance.setPlayingUrl(null);
      final url = _effectivePlaybackUrl;
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
    final fit = widget.fit;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        // Match video layout — cover in feed, contain elsewhere.
        if (_resolvedPosterUrl != null)
          SafeNetworkImage(
            imageUrl: _resolvedPosterUrl!,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            blankOnError: true,
          ),
        if (_generatedPosterBytes != null)
          Image.memory(
            _generatedPosterBytes!,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildVideoLayer(VideoPlayerController controller) {
    final ratio = _readAspectRatio(controller);
    if (widget.fit == BoxFit.cover) {
      return ColoredBox(
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;
            if (maxW <= 0 || maxH <= 0) {
              return const SizedBox.shrink();
            }
            final screenRatio = maxW / maxH;
            final double width;
            final double height;
            if (screenRatio > ratio) {
              width = maxW;
              height = maxW / ratio;
            } else {
              height = maxH;
              width = maxH * ratio;
            }
            return ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                minWidth: width,
                maxWidth: width,
                minHeight: height,
                maxHeight: height,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: VideoPlayer(controller),
                ),
              ),
            );
          },
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: ratio,
          child: VideoPlayer(controller),
        ),
      ),
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

    final showVideoLoading = _shouldShowVideoLoading(
      canMountVideoPlayer: canMountVideoPlayer,
      isBuffering: isBuffering,
    );

    final progressNotifier =
        _progressNotifier ?? FeedVideoProgressScope.maybeOf(context);
    final loadingOnProgressBar = progressNotifier != null;
    if (loadingOnProgressBar) {
      _publishFeedVideoLoading(showVideoLoading);
    }

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
            _buildVideoLayer(controller),
          if (_shouldShowPosterOverlay())
            Positioned.fill(child: _buildPosterLayer()),
          if (showVideoLoading && !loadingOnProgressBar)
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
                  _usingFallbackUrl = false;
                  _networkRetryAttempted = false;
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
