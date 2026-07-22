import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Audio-only preview / studio music bed.
///
/// Uses [just_audio] (no Flutter video texture) so it can play under the
/// media-studio [VideoPlayer] without freezing the preview on Android — two
/// [VideoPlayerController]s fighting for ExoPlayer/surfaces caused that freeze.
class SoundAudioPreview {
  SoundAudioPreview._();

  static AudioPlayer? _player;
  static StreamSubscription<PlayerState>? _stateSub;
  static String? _playingId;
  static bool _sessionReady = false;
  static int _generation = 0;

  static String? get playingId => _playingId;

  static bool isPlaying(String soundId) =>
      _playingId == soundId && (_player?.playing ?? false);

  static Future<void> toggle(String soundId, String audioUrl) async {
    if (_playingId == soundId && _player != null) {
      if (_player!.playing) {
        await _player!.pause();
      } else {
        await _player!.play();
      }
      return;
    }

    await playAt(soundId, audioUrl);
  }

  /// Plays [audioUrl] from [startOffset] for up to [window] (default 15s).
  ///
  /// When [loop] is false (picker preview), playback stops at the window end.
  /// When [loop] is true (media-studio bed), the window restarts so music keeps
  /// playing under the looping video preview.
  static Future<void> playAt(
    String soundId,
    String audioUrl, {
    Duration startOffset = Duration.zero,
    Duration window = const Duration(seconds: 15),
    bool loop = false,
  }) async {
    final url = audioUrl.trim();
    if (soundId.isEmpty || url.isEmpty) return;

    await stop();
    await _ensureMixableSession();

    final generation = ++_generation;
    final player = AudioPlayer(
      handleInterruptions: false,
      androidApplyAudioAttributes: false,
      // Don't request audio focus — that pauses the studio VideoPlayer on Android.
      handleAudioSessionActivation: false,
    );
    _player = player;
    _playingId = soundId;

    final start = startOffset < Duration.zero ? Duration.zero : startOffset;
    final win =
        window <= Duration.zero ? const Duration(seconds: 15) : window;
    final end = start + win;

    try {
      await player.setAudioSource(
        ClippingAudioSource(
          child: AudioSource.uri(Uri.parse(url)),
          start: start,
          end: end,
        ),
      );
      if (generation != _generation || _player != player) {
        await player.dispose();
        return;
      }

      await player.setLoopMode(loop ? LoopMode.one : LoopMode.off);

      if (!loop) {
        _stateSub = player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            unawaited(stop());
          }
        });
      }

      await player.play();
      if (generation != _generation || _player != player) {
        await player.dispose();
      }
    } catch (_) {
      if (_player == player) {
        await stop();
      } else {
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
  }

  static Future<void> stop() async {
    _generation++;
    final player = _player;
    final sub = _stateSub;
    _player = null;
    _stateSub = null;
    _playingId = null;
    await sub?.cancel();
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }

  /// Let music share the session with the studio video player (mixWithOthers).
  static Future<void> _ensureMixableSession() async {
    if (_sessionReady) return;
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
      _sessionReady = true;
    } catch (_) {
      // Playback may still work with the platform default session.
    }
  }
}
