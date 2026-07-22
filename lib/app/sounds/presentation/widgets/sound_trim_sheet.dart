import 'dart:async';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_file.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_theme.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_trim_widgets.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Result of the trim sheet: which part of the track starts playing and
/// whether the video's own audio should be muted when the music is mixed in.
class SoundTrimResult {
  const SoundTrimResult({
    required this.offset,
    this.window = const Duration(seconds: 15),
    this.muteOriginal = false,
  });

  final Duration offset;

  /// Length of the selected period (7s–15s TikTok-style clip).
  final Duration window;

  final bool muteOriginal;
}

/// TikTok-style trimmer: pick which part of [sound] starts playing.
/// Drag the selection to move it; drag the side handles to shorten/lengthen.
/// Confirm with Use to apply the selected period.
///
/// Uses [just_audio] (not [VideoPlayer]) so opening this sheet never freezes
/// the media-studio video ExoPlayer sitting underneath.
class SoundTrimSheet extends StatefulWidget {
  const SoundTrimSheet({
    super.key,
    required this.sound,
    this.windowLength,
    this.initialOffset = Duration.zero,
    this.allowMute = false,
    this.initialMute = false,
  });

  final SoundEntity sound;
  final Duration? windowLength;
  final Duration initialOffset;
  final bool allowMute;
  final bool initialMute;

  static Future<SoundTrimResult?> show(
    BuildContext context, {
    required SoundEntity sound,
    Duration? windowLength,
    Duration initialOffset = Duration.zero,
    bool allowMute = false,
    bool initialMute = false,
  }) {
    return GlassBottomSheet.open<SoundTrimResult>(
      context,
      isScrollControlled: true,
      builder: (ctx) => SoundPickerTheme(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: GlassBottomSheetShell(
            lightSurface: true,
            showHandle: true,
            child: SoundTrimSheet(
              sound: sound,
              windowLength: windowLength,
              initialOffset: initialOffset,
              allowMute: allowMute,
              initialMute: initialMute,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<SoundTrimSheet> createState() => _SoundTrimSheetState();
}

class _SoundTrimSheetState extends State<SoundTrimSheet> {
  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSub;
  List<double> _bars = const [];
  Duration _track = Duration.zero;
  Duration _window = Duration.zero;
  Duration _offset = Duration.zero;
  bool _loading = true;
  bool _playing = false;
  bool _muteOriginal = false;
  bool _applying = false;
  bool _ready = false;

  static const _minWindow = Duration(seconds: 7);
  static const _maxWindow = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
    _muteOriginal = widget.initialMute;
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      final audio = await SoundLocalFile.resolve(widget.sound.resolvedAudioUrl);
      Duration track = Duration(seconds: widget.sound.duration.clamp(0, 3600));

      if (audio != null) {
        try {
          final player = AudioPlayer(
            handleInterruptions: false,
            androidApplyAudioAttributes: false,
            handleAudioSessionActivation: false,
          );
          final duration = await player.setFilePath(audio.path);
          if (duration != null && duration > Duration.zero) {
            track = duration;
          }
          _player = player;
          _ready = true;
          _positionSub = player.positionStream.listen(_onPosition);
        } catch (_) {
          await _disposePlayer();
        }

        try {
          final data = await ProVideoEditor.instance.getWaveform(
            WaveformConfigs(
              video: EditorVideo.file(audio),
              resolution: WaveformResolution.low,
            ),
          );
          _bars = data.leftChannel.toList(growable: false);
        } catch (_) {
          _bars = const [];
        }
      } else {
        // Fall back to network URL if local cache failed.
        try {
          final url = widget.sound.resolvedAudioUrl.trim();
          if (url.isNotEmpty) {
            final player = AudioPlayer(
              handleInterruptions: false,
              androidApplyAudioAttributes: false,
              handleAudioSessionActivation: false,
            );
            final duration = await player.setUrl(url);
            if (duration != null && duration > Duration.zero) {
              track = duration;
            }
            _player = player;
            _ready = true;
            _positionSub = player.positionStream.listen(_onPosition);
          }
        } catch (_) {
          await _disposePlayer();
        }
      }

      _track = track > Duration.zero ? track : const Duration(seconds: 15);
      _window = _resolveWindow(_track, widget.windowLength);
      _offset = _clampOffset(_offset);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Default / preferred window: 7s–15s, never longer than the track.
  static Duration _resolveWindow(Duration track, Duration? preferred) {
    final maxAllowed = track < _maxWindow ? track : _maxWindow;
    if (maxAllowed <= Duration.zero) return _minWindow;
    final target = preferred != null && preferred > Duration.zero
        ? preferred
        : _maxWindow;
    if (target < _minWindow) {
      return maxAllowed < _minWindow ? maxAllowed : _minWindow;
    }
    return target > maxAllowed ? maxAllowed : target;
  }

  Duration get _maxAllowedWindow =>
      _track < _maxWindow ? _track : _maxWindow;

  Duration _clampOffset(Duration value) {
    final maxOffset = _track - _window;
    if (maxOffset <= Duration.zero) return Duration.zero;
    if (value < Duration.zero) return Duration.zero;
    if (value > maxOffset) return maxOffset;
    return value;
  }

  Duration _clampWindow(Duration value) {
    final maxW = _maxAllowedWindow;
    if (maxW <= Duration.zero) return Duration.zero;
    if (value < _minWindow) {
      return maxW < _minWindow ? maxW : _minWindow;
    }
    return value > maxW ? maxW : value;
  }

  void _onPosition(Duration pos) {
    if (!_playing) return;
    final end = _offset + _window;
    if (pos >= end || pos < _offset) {
      unawaited(_player?.seek(_offset) ?? Future<void>.value());
    }
  }

  Future<void> _seekToOffset() async {
    try {
      await _player?.seek(_offset);
    } catch (_) {}
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null || !_ready) return;
    if (_playing) {
      await player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await player.seek(_offset);
      await player.play();
      if (mounted) setState(() => _playing = true);
    }
  }

  void _onMove(double leftFrac) {
    final maxOffset = _track - _window;
    if (maxOffset <= Duration.zero) return;
    final newMicros = (leftFrac * _track.inMicroseconds).round();
    setState(() => _offset = _clampOffset(Duration(microseconds: newMicros)));
    unawaited(_seekToOffset());
  }

  /// Drag left handle: change start; keep end fixed when possible.
  void _onResizeStart(double leftFrac) {
    if (_track <= Duration.zero) return;
    final end = _offset + _window;
    final rawStart = Duration(
      microseconds: (leftFrac * _track.inMicroseconds).round(),
    );
    var start = rawStart < Duration.zero ? Duration.zero : rawStart;
    if (start >= end) {
      start = end - _minWindow;
      if (start < Duration.zero) start = Duration.zero;
    }
    var window = _clampWindow(end - start);
    // If clamped shorter, keep the end and pull start forward.
    start = end - window;
    if (start < Duration.zero) {
      start = Duration.zero;
      window = _clampWindow(end);
    }
    final maxStart = _track - window;
    if (start > maxStart) {
      start = maxStart < Duration.zero ? Duration.zero : maxStart;
    }
    setState(() {
      _offset = start;
      _window = window;
    });
    unawaited(_seekToOffset());
  }

  /// Drag right handle: change end; keep start fixed when possible.
  void _onResizeEnd(double rightFrac) {
    if (_track <= Duration.zero) return;
    final rawEnd = Duration(
      microseconds: (rightFrac * _track.inMicroseconds).round(),
    );
    var end = rawEnd > _track ? _track : rawEnd;
    if (end <= _offset) {
      end = _offset + _minWindow;
      if (end > _track) end = _track;
    }
    var window = _clampWindow(end - _offset);
    end = _offset + window;
    if (end > _track) {
      end = _track;
      window = _clampWindow(end - _offset);
      // Pull offset back if needed to fit min window near track end.
      if (_offset + window > _track) {
        final start = _track - window;
        setState(() {
          _offset = start < Duration.zero ? Duration.zero : start;
          _window = window;
        });
        unawaited(_seekToOffset());
        return;
      }
    }
    setState(() => _window = window);
  }

  Future<void> _apply() async {
    if (_applying) return;
    _applying = true;

    final result = SoundTrimResult(
      offset: _offset,
      window: _window,
      muteOriginal: _muteOriginal,
    );

    try {
      await _player?.pause();
      _playing = false;
    } catch (_) {}

    // Close immediately so Use feels like "apply + dismiss".
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(result);
    }
  }

  Future<void> _closeWithoutApply() async {
    if (_applying) return;
    try {
      await _player?.pause();
      _playing = false;
    } catch (_) {}
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _disposePlayer() async {
    final sub = _positionSub;
    final player = _player;
    _positionSub = null;
    _player = null;
    _ready = false;
    await sub?.cancel();
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    unawaited(_disposePlayer());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SoundTrimSheetBody(
      loading: _loading,
      canPlay: _ready && !_applying,
      playing: _playing,
      bars: _bars,
      track: _track,
      window: _window,
      offset: _offset,
      allowMute: widget.allowMute,
      muteOriginal: _muteOriginal,
      applying: _applying,
      onClose: () => unawaited(_closeWithoutApply()),
      onTogglePlay: () => unawaited(_togglePlay()),
      onConfirm: () => unawaited(_apply()),
      onMove: _onMove,
      onResizeStart: _onResizeStart,
      onResizeEnd: _onResizeEnd,
      onMuteChanged: (v) {
        if (_applying) return;
        setState(() => _muteOriginal = v);
      },
    );
  }
}
