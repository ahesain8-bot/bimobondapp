import 'dart:async';

import 'package:video_player/video_player.dart';

class SoundAudioPreview {
  SoundAudioPreview._();

  static VideoPlayerController? _controller;
  static String? _playingId;
  static Duration _loopStart = Duration.zero;
  static Duration _loopEnd = Duration.zero;

  static String? get playingId => _playingId;

  static bool isPlaying(String soundId) =>
      _playingId == soundId && (_controller?.value.isPlaying ?? false);

  static Future<void> toggle(String soundId, String audioUrl) async {
    if (_playingId == soundId && _controller != null) {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
      } else {
        await _controller!.play();
      }
      return;
    }

    await playAt(soundId, audioUrl);
  }

  /// Plays [audioUrl] from [startOffset] for up to [window] (default 15s),
  /// then stops. Does not loop — leftover looping was causing music to keep
  /// playing after the picker closed / during capture & upload.
  static Future<void> playAt(
    String soundId,
    String audioUrl, {
    Duration startOffset = Duration.zero,
    Duration window = const Duration(seconds: 15),
  }) async {
    final url = audioUrl.trim();
    if (soundId.isEmpty || url.isEmpty) return;

    await stop();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    _playingId = soundId;
    _loopStart = startOffset < Duration.zero ? Duration.zero : startOffset;
    _loopEnd = _loopStart +
        (window <= Duration.zero ? const Duration(seconds: 15) : window);

    try {
      await controller.initialize();
      final trackEnd = controller.value.duration;
      if (_loopStart > Duration.zero &&
          trackEnd > Duration.zero &&
          _loopStart < trackEnd) {
        await controller.seekTo(_loopStart);
      } else {
        _loopStart = Duration.zero;
      }
      if (trackEnd > Duration.zero && _loopEnd > trackEnd) {
        _loopEnd = trackEnd;
      }
      controller.setLooping(false);
      controller.addListener(_onTick);
      await controller.play();
    } catch (_) {
      await stop();
    }
  }

  static void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isPlaying) return;
    final pos = controller.value.position;
    final end = _loopEnd > _loopStart ? _loopEnd : controller.value.duration;
    if (end > Duration.zero && pos >= end - const Duration(milliseconds: 80)) {
      // End of the selected preview window — stop (do not seek/loop).
      unawaited(stop());
    }
  }

  static Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    _playingId = null;
    _loopStart = Duration.zero;
    _loopEnd = Duration.zero;
    if (controller != null) {
      controller.removeListener(_onTick);
      try {
        await controller.pause();
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }
}
