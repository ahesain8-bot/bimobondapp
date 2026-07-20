import 'dart:async';

import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_file.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_theme.dart';
import 'package:bimobondapp/app/sounds/presentation/widgets/sound_trim_widgets.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

/// Result of the trim sheet: which part of the track starts playing and
/// whether the video's own audio should be muted when the music is mixed in.
class SoundTrimResult {
  const SoundTrimResult({required this.offset, this.muteOriginal = false});

  final Duration offset;
  final bool muteOriginal;
}

/// TikTok-style trimmer: pick which part of [sound] starts playing.
/// Confirm with the pink check to apply the selected period.
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
  VideoPlayerController? _player;
  List<double> _bars = const [];
  Duration _track = Duration.zero;
  Duration _window = Duration.zero;
  Duration _offset = Duration.zero;
  bool _loading = true;
  bool _playing = false;
  bool _muteOriginal = false;
  bool _applying = false;

  static const _maxWindowSeconds = 15;

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
          final controller = VideoPlayerController.file(audio);
          await controller.initialize();
          _player = controller;
          if (controller.value.duration > Duration.zero) {
            track = controller.value.duration;
          }
          controller.addListener(_onPlayerTick);
        } catch (_) {
          _player = null;
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
      }

      _track = track > Duration.zero ? track : const Duration(seconds: 15);
      _window = _resolveWindow(_track, widget.windowLength);
      _offset = _clampOffset(_offset);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Keep a movable selection when the track is short; otherwise cap at 15s.
  static Duration _resolveWindow(Duration track, Duration? preferred) {
    if (preferred != null && preferred > Duration.zero) {
      return preferred > track ? track : preferred;
    }
    final maxWindow = const Duration(seconds: _maxWindowSeconds);
    if (track > maxWindow) return maxWindow;
    // Short track: leave scrub room so the first drag actually changes offset.
    if (track.inMilliseconds <= 1500) return track;
    final scrubmable = Duration(
      milliseconds: (track.inMilliseconds * 0.65).round().clamp(
        1000,
        track.inMilliseconds - 500,
      ),
    );
    return scrubmable;
  }

  Duration _clampOffset(Duration value) {
    final maxOffset = _track - _window;
    if (maxOffset <= Duration.zero) return Duration.zero;
    if (value < Duration.zero) return Duration.zero;
    if (value > maxOffset) return maxOffset;
    return value;
  }

  void _onPlayerTick() {
    final player = _player;
    if (player == null) return;
    if (_playing) {
      final pos = player.value.position;
      if (pos >= _offset + _window || pos < _offset) {
        player.seekTo(_offset);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;
    if (_playing) {
      await player.pause();
      setState(() => _playing = false);
    } else {
      await player.seekTo(_offset);
      await player.play();
      setState(() => _playing = true);
    }
  }

  void _onDrag(double dxFraction) {
    final maxOffset = _track - _window;
    if (maxOffset <= Duration.zero) return;
    final newMicros = (dxFraction * _track.inMicroseconds).round();
    setState(() => _offset = _clampOffset(Duration(microseconds: newMicros)));
    _player?.seekTo(_offset);
  }

  Future<void> _apply() async {
    if (_applying) return;
    _applying = true;

    final result = SoundTrimResult(
      offset: _offset,
      muteOriginal: _muteOriginal,
    );

    // Close immediately so the check feels like "apply + dismiss".
    // Pause audio after scheduling the pop (don't block the dismiss).
    final player = _player;
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(result);
    }
    try {
      await player?.pause();
    } catch (_) {}
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayerTick);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SoundTrimSheetBody(
      loading: _loading,
      canPlay: _player != null && !_applying,
      playing: _playing,
      bars: _bars,
      track: _track,
      window: _window,
      offset: _offset,
      allowMute: widget.allowMute,
      muteOriginal: _muteOriginal,
      applying: _applying,
      onClose: () {
        if (_applying) return;
        Navigator.of(context, rootNavigator: true).pop();
      },
      onTogglePlay: () => unawaited(_togglePlay()),
      onConfirm: () => unawaited(_apply()),
      onDrag: _onDrag,
      onMuteChanged: (v) {
        if (_applying) return;
        setState(() => _muteOriginal = v);
      },
    );
  }
}
