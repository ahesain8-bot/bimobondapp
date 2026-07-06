import 'dart:async';

import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
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
    this.controller,
    this.onPlaybackChanged,
  });

  final String url;
  final String? posterUrl;
  final bool isActive;
  final CustomVideoPlayerController? controller;
  final VoidCallback? onPlaybackChanged;

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

  bool get isPlaying =>
      _controller?.value.isInitialized == true && _controller!.value.isPlaying;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _maybeGeneratePoster();
    if (widget.isActive) {
      unawaited(_initController());
    }
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
      if (widget.isActive) {
        unawaited(_initController());
      } else {
        unawaited(_releasePlayer());
      }
      return;
    }
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _maybeGeneratePoster();
        final controller = _controller;
        if (controller != null && controller.value.isInitialized) {
          unawaited(_ensureAudiblePlayback());
        } else {
          unawaited(_initController());
        }
      } else {
        unawaited(_releasePlayer());
        _resetFeedProgress();
      }
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
    if (!widget.isActive || _isInitializing) return;

    final url = _resolvedUrl;
    final generation = ++_initGeneration;

    if (url.isEmpty) {
      if (!mounted) return;
      setState(() => _errorMessage = 'No video URL');
      return;
    }

    _isInitializing = true;
    if (mounted) setState(() => _errorMessage = null);

    await _tearDownController();

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
      if (controller.value.hasError) {
        final description =
            controller.value.errorDescription ?? 'Video playback failed';
        if (_isAudioFailure(description)) {
          unawaited(_playWithVolume(controller, generation, muted: true));
          return;
        }
        setState(() => _errorMessage = description);
        _syncFeedProgress();
      } else {
        if (mounted) setState(() {});
        _syncFeedProgress();
        _notifyPlaybackChanged();
      }
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

      if (!mounted || generation != _initGeneration || !widget.isActive) {
        await _disposeController(controller, listener);
        return;
      }

      if (mounted) setState(() => _isInitializing = false);

      var ok = await _playWithVolume(controller, generation, muted: false);
      if (!ok) {
        ok = await _playWithVolume(controller, generation, muted: true);
      }
      if (!ok && mounted && generation == _initGeneration) {
        setState(() {
          _errorMessage = 'Video unavailable';
        });
      }
    } catch (e) {
      debugPrint('Video player initialization error: $e');
      if (_isAudioFailure(e) &&
          controller.value.isInitialized &&
          mounted &&
          generation == _initGeneration) {
        final ok = await _playWithVolume(controller, generation, muted: true);
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

  Future<void> _ensureAudiblePlayback() async {
    final controller = _controller;
    final generation = _initGeneration;
    if (controller == null ||
        !controller.value.isInitialized ||
        !widget.isActive) {
      return;
    }
    _playbackMuted = false;
    var ok = await _playWithVolume(controller, generation, muted: false);
    if (!ok) {
      await _playWithVolume(controller, generation, muted: true);
    }
  }

  Future<bool> _playWithVolume(
    VideoPlayerController controller,
    int generation, {
    required bool muted,
  }) async {
    if (!widget.isActive || generation != _initGeneration) return false;
    try {
      await controller.setVolume(muted ? 0 : 1);
      _playbackMuted = muted;
      await controller.play();
      if (!mounted || generation != _initGeneration) return false;
      setState(() => _errorMessage = null);
      _syncFeedProgress();
      return true;
    } on PlatformException catch (e) {
      debugPrint('Video play failed: $e');
      return muted;
    } catch (e) {
      debugPrint('Video play failed: $e');
      return muted || !_isAudioFailure(e);
    }
  }

  void _notifyPlaybackChanged() {
    widget.onPlaybackChanged?.call();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isInitializing) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await _playWithVolume(
        controller,
        _initGeneration,
        muted: _playbackMuted,
      );
    }
    if (mounted) setState(() {});
    _syncFeedProgress();
    _notifyPlaybackChanged();
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

  Future<void> _tearDownController() async {
    final controller = _controller;
    final listener = _playbackListener;
    _controller = null;
    _playbackListener = null;
    if (controller == null) return;
    if (listener != null) {
      await _disposeController(controller, listener);
    } else {
      try {
        if (controller.value.isInitialized) {
          await controller.pause();
          await controller.setVolume(0);
        }
      } catch (_) {}
      await controller.dispose();
    }
  }

  Future<void> _releasePlayer() async {
    _initGeneration++;
    _isInitializing = false;
    _playbackMuted = false;
    await _tearDownController();
    if (mounted) setState(() {});
  }

  void _syncFeedProgress() {
    if (!mounted || !widget.isActive) return;
    final notifier = _progressNotifier;
    final controller = _controller;
    if (notifier == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    final value = controller.value;
    notifier.updateFromPlayback(
      position: value.position,
      duration: value.duration,
      isPlaying: value.isPlaying,
    );
  }

  void _resetFeedProgress() {
    _progressNotifier?.reset();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
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
    widget.controller?._detach(this);
    _initGeneration++;
    if (widget.isActive) _resetFeedProgress();
    unawaited(_tearDownController());
    super.dispose();
  }

  bool _shouldShowPosterOverlay() {
    if (_errorMessage != null) return false;
    if (!_hasPosterVisual && !_hasNetworkPosterAttempt) return false;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return true;
    return controller.value.isBuffering;
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
    if (_errorMessage != null &&
        _controller?.value.isInitialized != true) {
      return _buildError();
    }

    final controller = _controller;
    final isReady =
        controller != null &&
        controller.value.isInitialized &&
        !_isInitializing;
    final showVideoLoading =
        widget.isActive &&
        (!isReady || (isReady && controller.value.isBuffering));

    return GestureDetector(
      onTap: () => unawaited(_togglePlayback()),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_hasPosterVisual || _hasNetworkPosterAttempt) _buildPosterLayer(),
          if (!isReady && !_hasPosterVisual && !_hasNetworkPosterAttempt)
            const ColoredBox(color: Colors.black),
          if (isReady)
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 9 / 16
                      : controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          if (_shouldShowPosterOverlay())
            Positioned.fill(child: _buildPosterLayer()),
          if (showVideoLoading)
            const Center(child: CustomLoadingWidget(size: 72)),
          if (isReady &&
              !controller.value.isPlaying &&
              !controller.value.isBuffering)
            Icon(
              LucideIcons.play,
              size: 80,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          if (isReady)
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: Icon(
                    _playbackMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: _toggleMute,
                ),
              ),
            ),
        ],
      ),
    );
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
