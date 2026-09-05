import 'dart:async';

import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:just_audio/just_audio.dart';

/// Shows the auction audio shelf chip only while a music gift is playing.
///
/// Must not take over the process audio session: guests on stage
/// (استضافة غرفة) and the host already own a LiveKit communication session.
/// Activating a media session here silently fails playback for the receiver.
class AuctionAudioGiftChipSession {
  Timer? _hideTimer;
  StreamSubscription<PlayerState>? _playerSub;
  AudioPlayer? _player;
  int _generation = 0;

  Future<void> play({
    required void Function(String? label, String? colorHex) onUpdate,
    required String label,
    String? colorHex,
    String? audioUrl,
  }) async {
    await clear(onUpdate: onUpdate);

    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) return;

    onUpdate(trimmedLabel, colorHex);

    final generation = ++_generation;
    var hideAfter = const Duration(seconds: 5);

    final resolved = MediaUtils.resolveAbsoluteUrl(audioUrl ?? '').trim();
    if (resolved.isNotEmpty) {
      // Keep LiveKit mic/speaker session intact while mixing gift SFX.
      final player = AudioPlayer(
        handleInterruptions: false,
        androidApplyAudioAttributes: false,
        handleAudioSessionActivation: false,
      );
      _player = player;
      try {
        await player.setUrl(resolved);
        if (generation != _generation) {
          await player.dispose();
          return;
        }
        final duration = player.duration;
        if (duration != null && duration.inMilliseconds > 0) {
          hideAfter = duration + const Duration(milliseconds: 200);
        }
        _playerSub = player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            unawaited(clear(onUpdate: onUpdate));
          }
        });
        await player.setVolume(1.0);
        await player.play();
      } catch (_) {
        await player.dispose();
        if (_player == player) _player = null;
      }
    }

    _hideTimer = Timer(hideAfter, () {
      unawaited(clear(onUpdate: onUpdate));
    });
  }

  Future<void> clear({
    required void Function(String? label, String? colorHex) onUpdate,
  }) async {
    _generation++;
    _hideTimer?.cancel();
    _hideTimer = null;
    await _playerSub?.cancel();
    _playerSub = null;
    final player = _player;
    _player = null;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
    onUpdate(null, null);
  }

  void dispose() {
    _generation++;
    _hideTimer?.cancel();
    _playerSub?.cancel();
    final player = _player;
    _player = null;
    if (player != null) {
      unawaited(player.dispose());
    }
  }
}
