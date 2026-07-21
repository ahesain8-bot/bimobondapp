part of '../video_post_widget.dart';

/// Post soundtrack playback for image slides (video slides use [CustomVideoPlayer]).
mixin VideoPostSoundMixin on State<VideoPostWidget> {
  VideoPlayerController? _postSoundController;
  VoidCallback? _postSoundListener;

  int get soundCurrentPage;
  Map<int, CustomVideoPlayerController> get soundVideoControllers;
  bool get soundPlaybackActive;
  List<PostMediaEntity> get soundDisplayMedia;

  bool get canTogglePlayback =>
      isSlideVideo(soundCurrentPage) ||
      (widget.post.sound?.resolvedAudioUrl?.isNotEmpty ?? false);

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

  Future<void> syncPostSoundPlayback() async {
    if (!soundPlaybackActive || isSlideVideo(soundCurrentPage)) {
      await stopPostSound();
      return;
    }

    final audioUrl = widget.post.sound?.resolvedAudioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      await stopPostSound();
      return;
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
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );
    _postSoundController = controller;
    void onSoundPlaybackChanged() {
      if (!mounted) return;
      setState(() {});
    }

    _postSoundListener = onSoundPlaybackChanged;
    controller.addListener(onSoundPlaybackChanged);

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      if (!mounted ||
          !soundPlaybackActive ||
          isSlideVideo(soundCurrentPage) ||
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
