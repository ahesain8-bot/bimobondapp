import 'dart:async';
import 'dart:typed_data';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Muted looping 3-second video preview for a profile grid tile.
class ProfileGridVideoBackground extends StatefulWidget {
  const ProfileGridVideoBackground({
    required this.videoUrl,
    this.posterUrl,
    super.key,
  });

  final String videoUrl;
  final String? posterUrl;

  @override
  State<ProfileGridVideoBackground> createState() =>
      _ProfileGridVideoBackgroundState();
}

class _ProfileGridVideoBackgroundState extends State<ProfileGridVideoBackground> {
  static const Duration _initTimeout = Duration(seconds: 20);
  static const Duration _maxPlaybackDuration = Duration(seconds: 3);

  VideoPlayerController? _controller;
  VoidCallback? _playbackListener;
  Timer? _playbackTimer;
  bool _failed = false;
  bool _posterGenerationStarted = false;
  int _initGeneration = 0;
  Uint8List? _generatedPosterBytes;

  String get _resolvedVideoUrl => MediaUtils.resolveAbsoluteUrl(widget.videoUrl);

  String? get _resolvedPosterUrl {
    final raw = widget.posterUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final resolved = MediaUtils.resolveAbsoluteUrl(raw);
    if (MediaUtils.isVideo(resolved)) return null;
    return isValidNetworkImageUrl(resolved) ? resolved : null;
  }

  @override
  void initState() {
    super.initState();
    _maybeGeneratePoster();
    unawaited(_initController());
  }

  @override
  void didUpdateWidget(ProfileGridVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.posterUrl != widget.posterUrl) {
      _failed = false;
      _generatedPosterBytes = null;
      _posterGenerationStarted = false;
      _maybeGeneratePoster();
      unawaited(_initController());
    }
  }

  void _maybeGeneratePoster() {
    if (_posterGenerationStarted || _resolvedPosterUrl != null) return;
    _posterGenerationStarted = true;
    unawaited(_generatePosterFromVideo());
  }

  Future<void> _generatePosterFromVideo() async {
    final url = _resolvedVideoUrl;
    if (url.isEmpty) return;

    try {
      final bytes = await VideoThumbnailUtils.generateThumbnailBytes(
        url,
        timeMs: 0,
        quality: 70,
        maxHeight: 480,
      );
      if (!mounted || bytes == null) return;
      setState(() => _generatedPosterBytes = bytes);
    } catch (e) {
      debugPrint('Profile grid poster generation failed: $e');
    }
  }

  Future<void> _initController() async {
    final generation = ++_initGeneration;
    await _disposeController();

    final url = _resolvedVideoUrl;
    if (url.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );
    _controller = controller;

    void listener() {
      if (!mounted || generation != _initGeneration) return;

      final value = controller.value;
      if (value.isInitialized &&
          value.duration > Duration.zero &&
          value.duration <= _maxPlaybackDuration &&
          value.position >= value.duration - const Duration(milliseconds: 150)) {
        unawaited(_restartPreviewPlayback());
        return;
      }

      setState(() {});
    }

    _playbackListener = listener;
    controller.addListener(listener);

    try {
      await controller.initialize().timeout(
        _initTimeout,
        onTimeout: () => throw TimeoutException('Video load timed out'),
      );
      if (!mounted || generation != _initGeneration) {
        await _disposeController();
        return;
      }

      await controller.setLooping(false);
      await _startPreviewPlayback();
    } catch (e) {
      debugPrint('Profile grid video failed: $e');
      await _disposeController();
      if (!mounted || generation != _initGeneration) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _startPreviewPlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.setVolume(0);
      await controller.seekTo(Duration.zero);
      await controller.play();
      _schedulePreviewTimer();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _restartPreviewPlayback() async {
    _playbackTimer?.cancel();
    _playbackTimer = null;

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.pause();
      await controller.seekTo(Duration.zero);
      await controller.play();
      _schedulePreviewTimer();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _schedulePreviewTimer() {
    final generation = _initGeneration;
    _playbackTimer?.cancel();
    _playbackTimer = Timer(_maxPlaybackDuration, () {
      if (!mounted || generation != _initGeneration) return;
      unawaited(_restartPreviewPlayback());
    });
  }

  Future<void> _disposeController() async {
    _playbackTimer?.cancel();
    _playbackTimer = null;

    final controller = _controller;
    final listener = _playbackListener;
    _controller = null;
    _playbackListener = null;
    if (controller == null) return;

    if (listener != null) {
      controller.removeListener(listener);
    }

    try {
      if (controller.value.isInitialized) {
        await controller.pause();
        await controller.setVolume(0);
      }
    } catch (_) {}
    await controller.dispose();
  }

  @override
  void dispose() {
    _initGeneration++;
    unawaited(_disposeController());
    super.dispose();
  }

  Widget _buildPosterLayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
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

  bool get _hasPosterVisual =>
      _resolvedPosterUrl != null || _generatedPosterBytes != null;

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;

    if (_failed && !isReady) {
      if (_hasPosterVisual) {
        return _buildPosterLayer();
      }
      return const VideoPostPreviewPlaceholder(iconSize: 34);
    }

    final videoWidth = isReady && controller.value.size.width > 0
        ? controller.value.size.width
        : 9.0;
    final videoHeight = isReady && controller.value.size.height > 0
        ? controller.value.size.height
        : 16.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_hasPosterVisual) _buildPosterLayer(),
        if (!isReady && !_hasPosterVisual)
          const ColoredBox(color: Colors.black),
        if (isReady)
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: videoWidth,
                height: videoHeight,
                child: VideoPlayer(controller),
              ),
            ),
          ),
      ],
    );
  }
}
