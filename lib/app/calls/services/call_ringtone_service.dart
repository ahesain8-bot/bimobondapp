import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class CallRingtoneService {
  AudioPlayer? _player;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  // Snapchat-style modern melodic ringtone chime
  static const _snapchatRingtoneUrl =
      'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';

  // Outgoing ringing feedback chime
  static const _outgoingRingtoneUrl =
      'https://assets.mixkit.co/active_storage/sfx/1359/1359-preview.mp3';

  Future<void> playIncomingRingtone() async {
    await stop();
    try {
      _player = AudioPlayer();
      _isPlaying = true;
      await _player!.setUrl(_snapchatRingtoneUrl);
      await _player!.setLoopMode(LoopMode.one);
      await _player!.setVolume(1.0);
      await _player!.play();
    } catch (e) {
      debugPrint('CallRingtoneService playIncomingRingtone error: $e');
    }
  }

  Future<void> playOutgoingRingtone() async {
    await stop();
    try {
      _player = AudioPlayer();
      _isPlaying = true;
      await _player!.setUrl(_outgoingRingtoneUrl);
      await _player!.setLoopMode(LoopMode.one);
      await _player!.setVolume(0.8);
      await _player!.play();
    } catch (e) {
      debugPrint('CallRingtoneService playOutgoingRingtone error: $e');
    }
  }

  Future<void> stop() async {
    try {
      _isPlaying = false;
      if (_player != null) {
        await _player!.stop();
        await _player!.dispose();
        _player = null;
      }
    } catch (e) {
      debugPrint('CallRingtoneService stop error: $e');
    }
  }

  void dispose() {
    stop();
  }
}
