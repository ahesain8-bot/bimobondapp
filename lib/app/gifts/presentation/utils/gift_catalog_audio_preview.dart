import 'dart:async';

import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Previews catalog [AUDIO] gifts in the gift sheet (one at a time).
class GiftCatalogAudioPreview {
  GiftCatalogAudioPreview({this.onStateChanged});

  final VoidCallback? onStateChanged;

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _sub;
  String? _activeGiftId;
  int _generation = 0;

  String? get activeGiftId => _activeGiftId;

  bool isPlayingGift(String giftId) =>
      _activeGiftId == giftId && (_player?.playing ?? false);

  bool isActiveGift(String giftId) => _activeGiftId == giftId;

  bool isPausedGift(String giftId) {
    final player = _player;
    return _activeGiftId == giftId &&
        player != null &&
        !(player.playing);
  }

  Future<void> toggleGift(GiftEntity gift) async {
    if (!gift.isAudioGift) {
      await stop();
      return;
    }
    if (_activeGiftId == gift.id) {
      if (_player?.playing ?? false) {
        await pause();
      } else {
        await resume();
      }
      return;
    }
    await playGift(gift);
  }

  Future<void> pause() async {
    final player = _player;
    if (player == null) return;
    try {
      await player.pause();
      _notify();
    } catch (_) {}
  }

  Future<void> resume() async {
    final player = _player;
    if (player == null || _activeGiftId == null) return;
    try {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
      _notify();
    } catch (_) {}
  }

  Future<void> playGift(GiftEntity gift) async {
    if (!gift.isAudioGift) {
      await stop();
      return;
    }

    final url = MediaUtils.resolveAbsoluteUrl(gift.audioUrl ?? '').trim();
    if (url.isEmpty) {
      await stop();
      return;
    }

    if (_activeGiftId == gift.id) {
      if (_player?.playing ?? false) return;
      await resume();
      return;
    }

    await stop(notify: false);

    final generation = ++_generation;
    _activeGiftId = gift.id;
    _notify();

    final player = AudioPlayer(
      handleInterruptions: false,
      androidApplyAudioAttributes: false,
      handleAudioSessionActivation: false,
    );
    _player = player;

    try {
      await player.setUrl(url);
      if (generation != _generation) {
        await player.dispose();
        return;
      }
      _sub = player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          unawaited(stop());
        } else {
          _notify();
        }
      });
      await player.play();
      _notify();
    } catch (_) {
      if (generation == _generation) {
        await stop();
      } else {
        await player.dispose();
      }
    }
  }

  Future<void> stop({bool notify = true}) async {
    _generation++;
    _activeGiftId = null;
    await _sub?.cancel();
    _sub = null;
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
    if (notify) _notify();
  }

  void dispose() {
    _generation++;
    _activeGiftId = null;
    _sub?.cancel();
    final player = _player;
    _player = null;
    if (player != null) {
      unawaited(player.dispose());
    }
  }

  void _notify() => onStateChanged?.call();
}
