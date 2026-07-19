import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_local_file.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
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

/// TikTok-style trimmer: pick which part of [sound] starts playing. The user
/// drags a fixed-width selection window over the track's waveform; the window
/// width represents how much of the track will be used ([windowLength]).
///
/// Returns the chosen [SoundTrimResult], or null on cancel.
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

  /// How much of the track will be used (usually the clip length). When null,
  /// a sensible default is derived from the track length.
  final Duration? windowLength;
  final Duration initialOffset;

  /// Show the "mute original video sound" toggle (only relevant for videos).
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
    return showModalBottomSheet<SoundTrimResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SoundTrimSheet(
        sound: sound,
        windowLength: windowLength,
        initialOffset: initialOffset,
        allowMute: allowMute,
        initialMute: initialMute,
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

  static const _maxWindowSeconds = 15;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
    _muteOriginal = widget.initialMute;
    _prepare();
  }

  Future<void> _prepare() async {
    final audio = await SoundLocalFile.resolve(widget.sound.resolvedAudioUrl);
    Duration track =
        Duration(seconds: widget.sound.duration.clamp(0, 3600));

    if (audio != null) {
      try {
        final controller = VideoPlayerController.file(audio);
        await controller.initialize();
        _player = controller;
        if (controller.value.duration > Duration.zero) {
          track = controller.value.duration;
        }
        controller.addListener(_loopWithinWindow);
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
    final defaultWindow = Duration(
      seconds: _track.inSeconds.clamp(1, _maxWindowSeconds),
    );
    _window = widget.windowLength ?? defaultWindow;
    if (_window > _track) _window = _track;
    _offset = _clampOffset(_offset);

    if (mounted) setState(() => _loading = false);
  }

  Duration _clampOffset(Duration value) {
    final maxOffset = _track - _window;
    if (maxOffset <= Duration.zero) return Duration.zero;
    if (value < Duration.zero) return Duration.zero;
    if (value > maxOffset) return maxOffset;
    return value;
  }

  void _loopWithinWindow() {
    final player = _player;
    if (player == null || !_playing) return;
    final pos = player.value.position;
    if (pos >= _offset + _window || pos < _offset) {
      player.seekTo(_offset);
    }
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

  @override
  void dispose() {
    _player?.removeListener(_loopWithinWindow);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16171B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.sound.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (_player != null)
                  IconButton(
                    onPressed: _togglePlay,
                    icon: Icon(
                      _playing ? Icons.pause_circle : Icons.play_circle,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: CircularProgressIndicator(color: Colors.white54),
              )
            else
              _TrimTrack(
                bars: _bars,
                track: _track,
                window: _window,
                offset: _offset,
                onDrag: _onDrag,
              ),
            const SizedBox(height: 8),
            Text(
              '${_fmt(_offset)} / ${_fmt(_track)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (widget.allowMute) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _muteOriginal,
                activeThumbColor: const Color(0xFFFE2C55),
                onChanged: (v) => setState(() => _muteOriginal = v),
                title: Text(
                  l10n.cameraMuteOriginalSound,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  SoundTrimResult(offset: _offset, muteOriginal: _muteOriginal),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFE2C55),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  l10n.mediaEditorDone,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// The waveform strip with a draggable selection window on top.
class _TrimTrack extends StatelessWidget {
  const _TrimTrack({
    required this.bars,
    required this.track,
    required this.window,
    required this.offset,
    required this.onDrag,
  });

  final List<double> bars;
  final Duration track;
  final Duration window;
  final Duration offset;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    const height = 64.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final windowFrac = track.inMicroseconds == 0
            ? 1.0
            : (window.inMicroseconds / track.inMicroseconds).clamp(0.0, 1.0);
        final offsetFrac = track.inMicroseconds == 0
            ? 0.0
            : (offset.inMicroseconds / track.inMicroseconds).clamp(0.0, 1.0);
        final windowW = totalW * windowFrac;
        final windowLeft = totalW * offsetFrac;

        void handleDelta(double globalDx) {
          // Convert the window's left edge (drag position minus half window)
          // into a start fraction of the whole track.
          final left = (globalDx - windowW / 2).clamp(0.0, totalW - windowW);
          onDrag(totalW == 0 ? 0 : left / totalW);
        }

        return SizedBox(
          height: height,
          width: totalW,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _WaveformPainter(bars: bars),
                ),
              ),
              Positioned(
                left: windowLeft,
                top: 0,
                bottom: 0,
                width: windowW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(d.globalPosition);
                    handleDelta(local.dx);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: const Color(0xFFFE2C55),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.drag_indicator,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.bars});

  final List<double> bars;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeCap = StrokeCap.round;

    // Fall back to a uniform bar pattern when no waveform is available.
    final count = bars.isNotEmpty ? bars.length : (size.width ~/ 4);
    if (count <= 0) return;
    final step = size.width / count;
    paint.strokeWidth = (step * 0.5).clamp(1.0, 3.0);
    final mid = size.height / 2;

    for (var i = 0; i < count; i++) {
      final amp = bars.isNotEmpty ? bars[i].clamp(0.0, 1.0) : 0.35;
      final h = (amp * size.height).clamp(3.0, size.height);
      final x = step * i + step / 2;
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.bars != bars;
}
