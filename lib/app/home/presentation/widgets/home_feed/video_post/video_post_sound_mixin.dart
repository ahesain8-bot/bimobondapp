part of '../video_post_widget.dart';

/// Post soundtrack playback for image slides and for videos that attach a
/// library sound via `soundId` (video track is muted; this plays the track).
mixin VideoPostSoundMixin on State<VideoPostWidget> {
  VideoPlayerController? _postSoundController;
  VoidCallback? _postSoundListener;

  int get soundCurrentPage;
  Map<int, CustomVideoPlayerController> get soundVideoControllers;
  bool get soundPlaybackActive;
  List<PostMediaEntity> get soundDisplayMedia;

  bool get _hasExternalSoundtrack =>
      widget.post.sound?.resolvedAudioUrl?.isNotEmpty ?? false;

  Duration? get _segmentStart {
    final ms = widget.post.sound?.startMs;
    if (ms == null || ms <= 0) return null;
    return Duration(milliseconds: ms);
  }

  Duration? get _segmentEnd {
    final ms = widget.post.sound?.endMs;
    if (ms == null || ms <= 0) return null;
    return Duration(milliseconds: ms);
  }

  bool get canTogglePlayback =>
      isSlideVideo(soundCurrentPage) || _hasExternalSoundtrack;

  bool isPostPlaybackActive() {
    if (isSlideVideo(soundCurrentPage)) {
      return soundVideoControllers[soundCurrentPage]?.isPlaying ?? false;
    }
    return _postSoundController?.value.isPlaying ?? false;
  }

  bool isSlideVideo(int index) {
    final media = soundDisplayMedia;
    if (media.isEmpty) {
      final videoUrl = widget.post.videoUrl;
      return widget.post.type == 'VIDEO' ||
          (videoUrl != null && MediaUtils.isVideo(videoUrl));
    }
    if (index < 0 || index >= media.length) return false;
    final item = media[index];
    final url = MediaUtils.resolveAbsoluteUrl(item.url);
    return MediaUtils.isVideo(url, mediaType: item.mediaType) ||
        widget.post.type == 'VIDEO';
  }

  Future<void> togglePostPlayback() async {
    if (!canTogglePlayback) return;

    if (isSlideVideo(soundCurrentPage)) {
      await soundVideoControllers[soundCurrentPage]?.togglePlayback();
      final playing =
          soundVideoControllers[soundCurrentPage]?.isPlaying ?? false;
      if (_hasExternalSoundtrack) {
        if (playing) {
          await _resumePostSound();
        } else {
          await pausePostSound();
        }
      }
    } else {
      final controller = _postSoundController;
      if (controller != null && controller.value.isInitialized) {
        if (controller.value.isPlaying) {
          await controller.pause();
        } else {
          await controller.setVolume(1);
          await controller.play();
        }
      } else {
        await syncPostSoundPlayback();
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> pausePostSound() async {
    final controller = _postSoundController;
    if (controller == null) return;
    try {
      if (!controller.value.isInitialized) return;
      await controller.pause();
    } catch (_) {}
  }

  Future<void> _resumePostSound() async {
    final controller = _postSoundController;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setVolume(1);
        if (!controller.value.isPlaying) await controller.play();
        return;
      } catch (_) {}
    }
    await syncPostSoundPlayback();
  }

  Future<void> stopPostSound() async {
    final controller = _postSoundController;
    final listener = _postSoundListener;
    _postSoundController = null;
    _postSoundListener = null;
    if (controller == null) return;
    if (listener != null) {
      controller.removeListener(listener);
    }
    try {
      await controller.pause();
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _seekToSegmentStart(VideoPlayerController controller) async {
    final start = _segmentStart ?? Duration.zero;
    try {
      await controller.seekTo(start);
    } catch (_) {}
  }

  Future<void> syncPostSoundPlayback() async {
    if (!soundPlaybackActive) {
      await stopPostSound();
      return;
    }

    final audioUrl = widget.post.sound?.resolvedAudioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      await stopPostSound();
      return;
    }

    // Videos with an attached library sound: keep video muted and play this
    // track. Image slides also use this path.
    if (isSlideVideo(soundCurrentPage)) {
      unawaited(
        soundVideoControllers[soundCurrentPage]?.setMuted(true),
      );
    }

    final existing = _postSoundController;
    if (existing != null &&
        existing.dataSource == audioUrl &&
        existing.value.isInitialized) {
      if (!existing.value.isPlaying) {
        await existing.setVolume(1);
        await existing.play();
      }
      return;
    }

    await stopPostSound();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(audioUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );
    _postSoundController = controller;
    void onSoundPlaybackChanged() {
      if (!mounted || _postSoundController != controller) return;
      final end = _segmentEnd;
      if (end != null &&
          controller.value.isInitialized &&
          controller.value.isPlaying &&
          controller.value.position >= end) {
        unawaited(_seekToSegmentStart(controller));
      }
      setState(() {});
    }

    _postSoundListener = onSoundPlaybackChanged;
    controller.addListener(onSoundPlaybackChanged);

    try {
      await controller.initialize();
      // Loop the full file only when there is no segment window; otherwise
      // we manually wrap at endMs → startMs (see listener above).
      final hasWindow = widget.post.sound?.hasSegmentWindow ?? false;
      await controller.setLooping(!hasWindow);
      await controller.setVolume(1);
      if (hasWindow) {
        await _seekToSegmentStart(controller);
      }
      if (!mounted ||
          !soundPlaybackActive ||
          _postSoundController != controller) {
        await controller.dispose();
        return;
      }
      await controller.play();
    } catch (_) {
      await stopPostSound();
    }
  }
}
