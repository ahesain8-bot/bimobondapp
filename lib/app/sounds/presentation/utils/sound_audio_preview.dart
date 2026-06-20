import 'package:video_player/video_player.dart';

class SoundAudioPreview {
  SoundAudioPreview._();

  static VideoPlayerController? _controller;
  static String? _playingId;

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

    await stop();

    final controller = VideoPlayerController.networkUrl(Uri.parse(audioUrl));
    _controller = controller;
    _playingId = soundId;

    try {
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();
    } catch (_) {
      await stop();
    }
  }

  static Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    _playingId = null;
    if (controller != null) {
      await controller.pause();
      await controller.dispose();
    }
  }
}
