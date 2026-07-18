import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:bimobondapp/core/widgets/blurred_icon_badge.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
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

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  static const Duration _initTimeout = Duration(seconds: 20);

  VideoPlayerController? _controller;
  VoidCallback? _playbackListener;
  FeedVideoProgressNotifier? _progressNotifier;
  String? _errorMessage;
  bool _isInitializing = false;
  bool _playbackMuted = false;
  int _initGeneration = 0;
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
        text.contains('exoplaybackexception') ||
        text.contains('error -12') ||
        text.contains('audio/3gpp');
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
    if (widget.respectFeedPlaybackGate) {
      FeedPlaybackGate.instance.addListener(_onFeedPlaybackGateChanged);
    }
    widget.controller?._attach(this);
    _maybeGeneratePoster();
    if (_shouldPlay) {
      unawaited(_initController());
    }
  }

  void _onFeedPlaybackGateChanged() {
    if (!_shouldPlay) {
      _initGeneration++;
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
    final controller = _controller;
    if (controller == null || !_isControllerReady(controller)) return;
    try {
      await controller.pause();
      await controller.setVolume(0);
    } catch (_) {}
  }

  Future<void> _resumePlayback() async {
    if (!_shouldPlay) return;
    final controller = _controller;
    if (controller != null && _isControllerReady(controller)) {
      final generation = _initGeneration;
      await _startPlayback(controller, generation, muted: _playbackMuted);
      if (mounted && identical(controller, _controller)) {
        setState(() {});
      }
      return;
    }
    await _initController();
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
        _resetFeedProgress();
        unawaited(_releasePlayer());
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

  Future<void> _initController() async {
    if (!_shouldPlay || _isInitializing) return;

    final url = _resolvedUrl;
    final generation = ++_initGeneration;

    if (url.isEmpty) {
      if (!mounted) return;
      setState(() => _errorMessage = 'No video URL');
      return;
    }

    _isInitializing = true;
    if (mounted) setState(() => _errorMessage = null);

    final previous = _detachControllerSync();
    if (previous != null) {
      unawaited(_disposeController(previous.$1, previous.$2));
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );
    _controller = controller;

    void listener() {
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
          setState(() => _errorMessage = description);
          _syncFeedProgress();
        } else {
          if (mounted) setState(() {});
          _syncFeedProgress();
          _notifyPlaybackChanged();
        }
      } catch (_) {}
    }

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
      debugPrint('Video player initialization error: $e');
      if (_isAudioFailure(e) &&
          controller.value.isInitialized &&
          mounted &&
          generation == _initGeneration) {
        final ok = await _startPlayback(controller, generation, muted: true);
        if (ok) return;
      }
      await _disposeController(controller, listener);
      if (_controller == controller) {
        _controller = null;
        _playbackListener = null;
      }
      if (!mounted || generation != _initGeneration) return;
      setState(() {
        _errorMessage = _isAudioFailure(e)
            ? 'Playing without sound on this device'
            : e.toString();
        _isInitializing = false;
      });
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
    if (controller == null || !_isControllerReady(controller) || _isInitializing) {
      return;
    }
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await _startPlayback(controller, _initGeneration, muted: _playbackMuted);
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

  Future<void> _releasePlayer() async {
    _initGeneration++;
    _isInitializing = false;
    _playbackMuted = false;
    final detached = _detachControllerSync();
    if (mounted) setState(() {});
    if (detached != null) {
      await _disposeController(detached.$1, detached.$2);
    }
  }

  void _syncFeedProgress() {
    if (!mounted || !_shouldPlay) return;
    final notifier = _progressNotifier;
    final controller = _controller;
    if (notifier == null || controller == null || !_isControllerReady(controller)) {
      return;
    }
    try {
      final value = controller.value;
      notifier.updateFromPlayback(
        position: value.position,
        duration: value.duration,
        isPlaying: value.isPlaying,
      );
    } catch (_) {}
  }

  void _resetFeedProgress() {
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
    if (widget.respectFeedPlaybackGate) {
      FeedPlaybackGate.instance.removeListener(_onFeedPlaybackGateChanged);
    }
    widget.controller?._detach(this);
    _initGeneration++;
    if (widget.isActive) _resetFeedProgress();
    final detached = _detachControllerSync();
    if (detached != null) {
      unawaited(_disposeController(detached.$1, detached.$2));
    }
    super.dispose();
  }

  bool _shouldShowPosterOverlay() {
    if (_errorMessage != null) return false;
    if (!_hasPosterVisual && !_hasNetworkPosterAttempt) return false;
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
        if (_resolvedPosterUrl != null)
          SafeNetworkImage(
            imageUrl: _resolvedPosterUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            blankOnError: true,
          ),
        if (_generatedPosterBytes != null)
          Image.memory(
            _generatedPosterBytes!,
            fit: BoxFit.cover,
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
    final canMountVideoPlayer = widget.isActive &&
        _shouldPlay &&
        controller != null &&
        identical(controller, _controller) &&
        _isControllerReady(controller) &&
        !_isInitializing;
    final isReady = canMountVideoPlayer;
    final isBuffering = isReady && _readIsBuffering(controller);
    final isPaused = isReady && !isBuffering && !_readIsPlaying(controller);

    if (_errorMessage != null && !isReady) {
      return _buildError();
    }

    final showVideoLoading =
        widget.isActive && _shouldPlay && (!canMountVideoPlayer || isBuffering);

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
            const Center(child: CustomLoadingWidget(size: 72)),
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
                onPressed: () => unawaited(_initController()),
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
