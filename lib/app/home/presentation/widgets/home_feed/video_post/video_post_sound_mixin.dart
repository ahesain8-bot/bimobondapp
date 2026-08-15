part of '../video_post_widget.dart';

/// Post soundtrack playback for image slides and for videos that attach a
/// library sound via `soundId` (video track is muted; this plays the track).
///
/// Uses [AudioPlayer] (not a second [VideoPlayerController]) so feed video +
/// sound does not stall on Android ExoPlayer/surface contention.
mixin VideoPostSoundMixin on State<VideoPostWidget> {
  AudioPlayer? _postSoundPlayer;
  bool _postSoundUserMuted = false;
  Future<void>? _soundPrepareFuture;
  int _postSoundGeneration = 0;
  static bool _postSoundSessionReady = false;
  int? _knownVideoDurationMs;
  String? _preparedClipSignature;
  StreamSubscription<PlayerState>? _postSoundStateSub;

  int get soundCurrentPage;
  Map<int, CustomVideoPlayerController> get soundVideoControllers;
  bool get soundPlaybackActive;
  List<PostMediaEntity> get soundDisplayMedia;

  bool get _hasExternalSoundtrack =>
      widget.post.sound?.resolvedAudioUrl?.isNotEmpty ?? false;

  bool get _syncSoundWithVideoSlide =>
      _hasExternalSoundtrack && isSlideVideo(soundCurrentPage);

  double get _postSoundVolume => _postSoundUserMuted ? 0 : 1;

  bool get _hasSegmentWindow => widget.post.sound?.hasSegmentWindow ?? false;

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

  /// Length of the attached sound clip (endMs − startMs), if configured.
  Duration? get _soundSegmentLength {
    if (!_hasSegmentWindow) return null;
    final sound = widget.post.sound!;
    final segmentLenMs = sound.endMs! - sound.startMs!;
    if (segmentLenMs <= 0) return null;
    return Duration(milliseconds: segmentLenMs);
  }

  /// Max position for [CustomVideoPlayer.segmentMaxPosition].
  ///
  /// Image + sound: the sound window is the playback length.
  /// Video + sound: always play the full video — never shorten a long clip to
  /// a short soundtrack (that made 27s videos loop at ~12s while UI showed 27).
  Duration? get _segmentPlaybackDuration {
    if (!_hasSegmentWindow) return null;
    if (_syncSoundWithVideoSlide) {
      // Full video; soundtrack loops via [LoopMode.one] / segment-end handler.
      return null;
    }
    return _soundSegmentLength;
  }

  /// For feed chrome: pass to [CustomVideoPlayer.segmentMaxPosition].
  Duration? segmentPlaybackMaxForPost() => _segmentPlaybackDuration;

  int? _resolvedVideoDurationMs() {
    if (_knownVideoDurationMs != null && _knownVideoDurationMs! > 0) {
      return _knownVideoDurationMs;
    }
    if (!_syncSoundWithVideoSlide) return null;
    final ms =
        soundVideoControllers[soundCurrentPage]?.playbackDuration.inMilliseconds ??
        0;
    return ms > 0 ? ms : null;
  }

  /// End of the clipped soundtrack on the source audio timeline.
  /// When the video is shorter than the sound segment, trim audio to the clip.
  Duration? _effectiveClipEndOnSource() {
    final start = _segmentStart ?? Duration.zero;
    final end = _segmentEnd;
    if (end == null || end <= start) return null;

    if (_syncSoundWithVideoSlide) {
      final videoMs = _resolvedVideoDurationMs();
      if (videoMs != null && videoMs > 0) {
        final maxEnd = start.inMilliseconds + videoMs;
        if (end.inMilliseconds > maxEnd) {
          return Duration(milliseconds: maxEnd);
        }
      }
    }
    return end;
  }

  String _clipSignature(String audioUrl) {
    final start = widget.post.sound?.startMs ?? 0;
    final endMs = _effectiveClipEndOnSource()?.inMilliseconds ?? 0;
    return '$audioUrl|$start|$endMs';
  }

  void onVideoDurationReady(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms <= 0) return;
    if (_knownVideoDurationMs == ms) return;
    _knownVideoDurationMs = ms;
    // May be reported from a player listener during build — defer setState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_onVideoDurationChanged());
    });
  }

  Future<void> _onVideoDurationChanged() async {
    if (!mounted) return;
    final sig = widget.post.sound?.resolvedAudioUrl;
    if (sig == null || sig.isEmpty) return;
    if (_preparedClipSignature != null &&
        _preparedClipSignature != _clipSignature(sig)) {
      await stopPostSound();
    }
    setState(() {});
    unawaited(syncPostSoundPlayback());
  }

  bool get canTogglePlayback =>
      isSlideVideo(soundCurrentPage) || _hasExternalSoundtrack;

  bool get isPostSoundUserMuted => _postSoundUserMuted;

  void togglePostSoundMute() {
    onVideoUserMuteChanged(!_postSoundUserMuted);
    if (mounted) setState(() {});
  }

  void _bindPostSoundStateListener(AudioPlayer player) {
    _postSoundStateSub?.cancel();
    _postSoundStateSub = player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed &&
          soundPlaybackActive &&
          _syncSoundWithVideoSlide) {
        unawaited(onPostSoundSegmentLoop());
      }
      setState(() {});
    });
  }

  void resetPostSoundMuteState() {
    _postSoundUserMuted = false;
    _knownVideoDurationMs = null;
    _preparedClipSignature = null;
  }

  void onVideoPlaybackChangedFromPlayer() {
    if (!_hasExternalSoundtrack || !isSlideVideo(soundCurrentPage)) return;

    final controller = soundVideoControllers[soundCurrentPage];
    final playing = controller?.isPlaying ?? false;
    if (playing) {
      unawaited(_tryStartSoundWithVideo());
      return;
    }

    // Video briefly reports paused while seeking back for a segment loop or starting at 0:00.
    final pos = controller?.playbackPosition ?? Duration.zero;
    if (pos <= const Duration(milliseconds: 350)) {
      return;
    }

    if (_hasSegmentWindow) {
      final window = _segmentPlaybackDuration;
      if (window != null &&
          pos >= window - const Duration(milliseconds: 150)) {
        return;
      }
    }

    // Short sound posts: video hits EOF before the sound window is known —
    // don't kill the soundtrack while the player is restarting the loop.
    final videoDuration = controller?.playbackDuration ?? Duration.zero;
    if (videoDuration > Duration.zero &&
        pos >= videoDuration - const Duration(milliseconds: 200)) {
      return;
    }

    unawaited(pausePostSound());
  }

  void onVideoUserMuteChanged(bool muted) {
    _postSoundUserMuted = muted;
    unawaited(_applyPostSoundVolume());
  }

  Future<void> onPostSoundSegmentLoop() async {
    if (!_hasExternalSoundtrack || !soundPlaybackActive) return;
    final player = _postSoundPlayer;
    if (player == null) return;

    // Video + soundtrack: never restart audio alone while the clip is still
    // seeking/loading — wait until video is playing near the start again.
    if (_syncSoundWithVideoSlide) {
      final controller = soundVideoControllers[soundCurrentPage];
      final pos = controller?.playbackPosition ?? Duration.zero;
      final duration = controller?.playbackDuration ?? Duration.zero;
      final nearStart = pos <= const Duration(milliseconds: 450);
      final nearEnd = duration > Duration.zero &&
          pos >= duration - const Duration(milliseconds: 450);
      final videoPlaying = controller?.isPlaying ?? false;

      // Sound clip ended mid-video — realign to the video clock, don't hard reset.
      if (!nearStart && !nearEnd && videoPlaying) {
        try {
          await _alignPostSoundToVideo(force: true);
          if (_postSoundVolume > 0) {
            await player.setVolume(_postSoundVolume);
            if (!player.playing) await player.play();
          }
        } catch (_) {}
        return;
      }

      try {
        await player.pause();
        await player.seek(Duration.zero);
      } catch (_) {}

      final ready = await _waitForVideoReplayReady();
      if (!ready || !mounted || !soundPlaybackActive) return;

      try {
        if (_postSoundVolume > 0) {
          await player.setVolume(_postSoundVolume);
          await player.play();
        }
      } catch (_) {}
      return;
    }

    // Image + soundtrack: restart the bed immediately.
    try {
      await player.seek(Duration.zero);
      if (_postSoundVolume > 0) {
        await player.setVolume(_postSoundVolume);
        if (!player.playing) {
          await player.play();
        }
      }
    } catch (_) {}
  }

  /// True once the video has seeked back and is actually playing near 0:00.
  Future<bool> _waitForVideoReplayReady() async {
    final controller = soundVideoControllers[soundCurrentPage];
    if (controller == null) return false;

    for (var i = 0; i < 50; i++) {
      if (!mounted || !soundPlaybackActive) return false;
      final playing = controller.isPlaying;
      final pos = controller.playbackPosition;
      if (playing && pos < const Duration(milliseconds: 600)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    return soundVideoControllers[soundCurrentPage]?.isPlaying ?? false;
  }

  Future<void> onVideoSeekSync(
    Duration videoPosition, {
    required bool resumePlayback,
  }) async {
    if (!_syncSoundWithVideoSlide) return;
    final clamped = _clampVideoPosition(videoPosition);
    await seekPostSoundToVideoPosition(clamped);
    if (!resumePlayback) {
      await pausePostSound();
      return;
    }
    if (soundVideoControllers[soundCurrentPage]?.isPlaying ?? false) {
      await _tryStartSoundWithVideo(skipAlign: true);
    }
  }

  bool isPostPlaybackActive() {
    if (isSlideVideo(soundCurrentPage)) {
      return soundVideoControllers[soundCurrentPage]?.isPlaying ?? false;
    }
    return _postSoundPlayer?.playing ?? false;
  }

  bool isSlideVideo(int index) {
    final media = soundDisplayMedia;
    if (media.isEmpty) {
      final videoUrl = widget.post.videoUrl;
      return _postTypeIsVideo(widget.post.type) ||
          (videoUrl != null && MediaUtils.isVideo(videoUrl));
    }
    if (index < 0 || index >= media.length) return false;
    final item = media[index];
    final url = MediaUtils.resolveAbsoluteUrl(item.url);
    return MediaUtils.isVideo(url, mediaType: item.mediaType) ||
        _postTypeIsVideo(widget.post.type);
  }

  bool _postTypeIsVideo(String? type) {
    final normalized = type?.trim().toUpperCase();
    return normalized == 'VIDEO' || normalized == 'REEL';
  }

  Future<void> togglePostPlayback() async {
    if (!canTogglePlayback) return;

    if (isSlideVideo(soundCurrentPage)) {
      await soundVideoControllers[soundCurrentPage]?.togglePlayback();
      final playing =
          soundVideoControllers[soundCurrentPage]?.isPlaying ?? false;
      if (_hasExternalSoundtrack) {
        if (playing) {
          await _tryStartSoundWithVideo();
        } else {
          await pausePostSound();
        }
      }
    } else {
      final player = _postSoundPlayer;
      if (player != null) {
        if (player.playing) {
          await player.pause();
        } else {
          if (_hasSegmentWindow) {
            await player.seek(Duration.zero);
          }
          await player.setVolume(_postSoundVolume);
          await player.play();
        }
      } else {
        await syncPostSoundPlayback();
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> pausePostSound() async {
    final player = _postSoundPlayer;
    if (player == null) return;
    try {
      if (player.playing) {
        await player.pause();
      }
    } catch (_) {}
  }

  bool _videoSlideSoundShouldPlay() {
    if (!_syncSoundWithVideoSlide || !soundPlaybackActive) return false;
    return soundVideoControllers[soundCurrentPage]?.isPlaying ?? false;
  }

  Future<void> _tryStartSoundWithVideo({bool skipAlign = false}) async {
    if (!_videoSlideSoundShouldPlay()) {
      await pausePostSound();
      return;
    }
    await _restartSegmentIfAtEnd();
    // Hold audio until the video texture is actually playing (not just queued).
    final ready = await _waitForVideoReplayReady();
    if (!ready || !_videoSlideSoundShouldPlay()) {
      await pausePostSound();
      return;
    }
    await ensurePostSoundPrepared();
    if (!_videoSlideSoundShouldPlay()) {
      await pausePostSound();
      return;
    }
    final player = _postSoundPlayer;
    if (player == null) return;
    try {
      if (!skipAlign) {
        await _alignPostSoundToVideo(force: false);
      }
      if (!_videoSlideSoundShouldPlay()) {
        await pausePostSound();
        return;
      }
      await player.setVolume(_postSoundVolume);
      if (!player.playing) {
        await player.play();
      }
    } catch (_) {}
  }

  Future<void> stopPostSound() async {
    _postSoundGeneration++;
    _soundPrepareFuture = null;
    _preparedClipSignature = null;
    await _postSoundStateSub?.cancel();
    _postSoundStateSub = null;
    final player = _postSoundPlayer;
    _postSoundPlayer = null;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  Future<void> _applyPostSoundVolume() async {
    final player = _postSoundPlayer;
    if (player == null) return;
    try {
      await player.setVolume(_postSoundVolume);
    } catch (_) {}
  }

  Duration _clampVideoPosition(Duration videoPosition) {
    final window = _segmentPlaybackDuration;
    if (window == null) return videoPosition;
    if (videoPosition > window) return window;
    if (videoPosition.isNegative) return Duration.zero;
    return videoPosition;
  }

  /// Map video clock → position inside the clipped soundtrack.
  /// When video is longer than the sound clip, wrap with modulo so audio stays
  /// in sync across the full clip.
  Duration _playerSeekPosition(Duration videoPosition) {
    final clipped = _clampVideoPosition(videoPosition);
    if (!_syncSoundWithVideoSlide) return clipped;

    final soundLen = _soundSegmentLength;
    if (soundLen == null || soundLen.inMilliseconds <= 0) return clipped;

    final videoMs = _resolvedVideoDurationMs();
    // Video shorter than / equal to sound — 1:1 mapping inside the clip.
    if (videoMs != null && videoMs > 0 && videoMs <= soundLen.inMilliseconds) {
      return clipped;
    }

    final lenMs = soundLen.inMilliseconds;
    final posMs = videoPosition.isNegative ? 0 : videoPosition.inMilliseconds;
    return Duration(milliseconds: posMs % lenMs);
  }

  Future<void> seekPostSoundToVideoPosition(Duration videoPosition) async {
    final player = _postSoundPlayer;
    if (player == null) return;
    try {
      await player.seek(_playerSeekPosition(videoPosition));
    } catch (_) {}
  }

  Future<void> _alignPostSoundToVideo({required bool force}) async {
    if (!isSlideVideo(soundCurrentPage)) return;
    final player = _postSoundPlayer;
    if (player == null) return;
    final videoPosition = _clampVideoPosition(
      soundVideoControllers[soundCurrentPage]?.playbackPosition ??
          Duration.zero,
    );
    final target = _playerSeekPosition(videoPosition);
    if (!force) {
      try {
        final delta = (player.position - target).abs();
        if (delta < const Duration(milliseconds: 280)) return;
      } catch (_) {}
    }
    await seekPostSoundToVideoPosition(videoPosition);
  }

  Future<AudioSource> _buildSoundAudioSource(String audioUrl) async {
    final resolved = MediaUtils.resolveAbsoluteUrl(audioUrl);
    final UriAudioSource child;
    if (AppMediaCacheManager.canDiskCacheVideo(resolved)) {
      var file = await AppMediaCacheManager.getCachedSoundFile(resolved);
      file ??= await AppMediaCacheManager.downloadSoundFile(resolved);
      child = file != null
          ? AudioSource.uri(Uri.file(file.path))
          : AudioSource.uri(Uri.parse(resolved));
    } else {
      child = AudioSource.uri(Uri.parse(resolved));
    }

    final start = _segmentStart ?? Duration.zero;
    final clipEnd = _effectiveClipEndOnSource();
    if (clipEnd != null && clipEnd > start) {
      return ClippingAudioSource(
        child: child,
        start: start,
        end: clipEnd,
      );
    }
    return child;
  }

  Future<void> ensurePostSoundPrepared() async {
    if (!soundPlaybackActive) {
      await stopPostSound();
      return;
    }

    final audioUrl = widget.post.sound?.resolvedAudioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      await stopPostSound();
      return;
    }

    if (isSlideVideo(soundCurrentPage)) {
      unawaited(
        soundVideoControllers[soundCurrentPage]?.setMuted(true),
      );
    }

    final signature = _clipSignature(audioUrl);
    if (_postSoundPlayer != null) {
      if (_preparedClipSignature == signature) return;
      await stopPostSound();
    }

    final inFlight = _soundPrepareFuture;
    if (inFlight != null) {
      await inFlight;
      if (_postSoundPlayer != null && _preparedClipSignature == signature) {
        return;
      }
    }

    final prepare = _preparePostSoundPlayer(audioUrl, signature);
    _soundPrepareFuture = prepare;
    try {
      await prepare;
    } finally {
      if (identical(_soundPrepareFuture, prepare)) {
        _soundPrepareFuture = null;
      }
    }
  }

  Future<void> _ensurePostSoundSession() async {
    if (_postSoundSessionReady) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );
      _postSoundSessionReady = true;
    } catch (_) {}
  }

  Future<void> _preparePostSoundPlayer(
    String audioUrl,
    String signature,
  ) async {
    await stopPostSound();
    await _ensurePostSoundSession();

    final generation = ++_postSoundGeneration;
    final player = AudioPlayer(
      handleInterruptions: false,
      androidApplyAudioAttributes: false,
      handleAudioSessionActivation: false,
    );
    _postSoundPlayer = player;

    try {
      final source = await _buildSoundAudioSource(audioUrl);
      if (generation != _postSoundGeneration || _postSoundPlayer != player) {
        await player.dispose();
        return;
      }

      await player.setAudioSource(source);
      if (generation != _postSoundGeneration || _postSoundPlayer != player) {
        await player.dispose();
        return;
      }

      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_postSoundVolume);
      _preparedClipSignature = signature;
      _bindPostSoundStateListener(player);

      if (_syncSoundWithVideoSlide) {
        await seekPostSoundToVideoPosition(Duration.zero);
      }

      if (!mounted ||
          !soundPlaybackActive ||
          _postSoundPlayer != player ||
          generation != _postSoundGeneration) {
        await player.dispose();
        return;
      }

      if (!_syncSoundWithVideoSlide) {
        if (soundPlaybackActive) {
          await player.play();
        }
      } else if (_videoSlideSoundShouldPlay()) {
        await player.play();
      } else {
        await player.pause();
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (_postSoundPlayer == player) {
        await stopPostSound();
      } else {
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
  }

  Future<void> _restartSegmentIfAtEnd() async {
    final window = _segmentPlaybackDuration;
    if (window == null) return;
    if (_syncSoundWithVideoSlide) {
      final pos =
          soundVideoControllers[soundCurrentPage]?.playbackPosition ??
          Duration.zero;
      if (pos >= window - const Duration(milliseconds: 80)) {
        await soundVideoControllers[soundCurrentPage]?.restartFromBeginning();
      }
    }
  }

  Future<void> syncPostSoundPlayback() async {
    if (!soundPlaybackActive) {
      await stopPostSound();
      return;
    }

    if (!_hasExternalSoundtrack) {
      await stopPostSound();
      return;
    }

    final audioUrl = widget.post.sound!.resolvedAudioUrl!;
    if (AppMediaCacheManager.canDiskCacheVideo(audioUrl)) {
      unawaited(AppMediaCacheManager.downloadSoundFile(audioUrl));
    }

    unawaited(ensurePostSoundPrepared());

    if (_syncSoundWithVideoSlide && isPostPlaybackActive()) {
      unawaited(_tryStartSoundWithVideo());
    }
  }
}
