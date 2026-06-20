import 'dart:io';

import 'package:video_player/video_player.dart';

class SoundDurationProbe {
  SoundDurationProbe._();

  static Future<int> probeSeconds(File file) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      final millis = controller.value.duration.inMilliseconds;
      final seconds = (millis / 1000).ceil();
      return seconds < 1 ? 1 : seconds;
    } finally {
      await controller.dispose();
    }
  }
}
