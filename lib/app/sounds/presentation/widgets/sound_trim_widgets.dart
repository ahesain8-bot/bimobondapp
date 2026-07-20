import 'package:bimobondapp/app/sounds/presentation/widgets/sound_picker_theme.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// X / play / check chrome for the sound trim sheet.
/// The right check applies the selected period and closes the sheet.
class SoundTrimHeader extends StatelessWidget {
  const SoundTrimHeader({
    super.key,
    required this.canPlay,
    required this.playing,
    required this.confirmEnabled,
    required this.onClose,
    required this.onTogglePlay,
    required this.onConfirm,
  });

  final bool canPlay;
  final bool playing;
  final bool confirmEnabled;
  final VoidCallback onClose;
  final VoidCallback onTogglePlay;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final iconColor = onSurface.withValues(alpha: 0.87);

    return Row(
      children: [
        IconButton(
          onPressed: confirmEnabled ? onClose : null,
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: Icon(LucideIcons.x, color: iconColor, size: 24),
        ),
        const Spacer(),
        if (canPlay)
          IconButton(
            onPressed: confirmEnabled ? onTogglePlay : null,
            icon: Icon(
              playing ? LucideIcons.pause : LucideIcons.play,
              color: iconColor,
              size: 24,
            ),
          ),
        IconButton(
          onPressed: confirmEnabled ? onConfirm : null,
          tooltip: l10n.soundUseThis,
          icon: Icon(
            LucideIcons.check,
            size: 24,
            color: confirmEnabled
                ? scheme.primary
                : onSurface.withValues(alpha: 0.28),
          ),
        ),
      ],
    );
  }
}

/// "{n}s selected" + "00:00 / 00:08" footer.
class SoundTrimFooter extends StatelessWidget {
  const SoundTrimFooter({
    super.key,
    required this.selectedLabel,
    required this.timeLabel,
  });

  final String selectedLabel;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);
    final style = TextStyle(
      color: muted,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(selectedLabel, style: style),
          const Spacer(),
          Text(timeLabel, style: style),
        ],
      ),
    );
  }
}

/// Mute original video audio toggle (media studio).
class SoundTrimMuteTile extends StatelessWidget {
  const SoundTrimMuteTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: true,
      value: value,
      activeThumbColor: SoundPickerTheme.accentOf(context),
      onChanged: onChanged,
      title: Text(
        l10n.cameraMuteOriginalSound,
        style: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.87),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Full trim sheet chrome: header, waveform, footer, optional mute.
class SoundTrimSheetBody extends StatelessWidget {
  const SoundTrimSheetBody({
    super.key,
    required this.loading,
    required this.canPlay,
    required this.playing,
    required this.bars,
    required this.track,
    required this.window,
    required this.offset,
    required this.allowMute,
    required this.muteOriginal,
    required this.onClose,
    required this.onTogglePlay,
    required this.onConfirm,
    required this.onDrag,
    required this.onMuteChanged,
    this.applying = false,
  });

  final bool loading;
  final bool canPlay;
  final bool playing;
  final List<double> bars;
  final Duration track;
  final Duration window;
  final Duration offset;
  final bool allowMute;
  final bool muteOriginal;
  final bool applying;
  final VoidCallback onClose;
  final VoidCallback onTogglePlay;
  final VoidCallback onConfirm;
  final ValueChanged<double> onDrag;
  final ValueChanged<bool> onMuteChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final selectedSeconds = window.inSeconds.clamp(1, 9999);
    // Check applies + closes even while waveform is still loading.
    final canConfirm = !applying;

    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SoundTrimHeader(
                canPlay: canPlay,
                playing: playing,
                confirmEnabled: canConfirm,
                onClose: onClose,
                onTogglePlay: onTogglePlay,
                onConfirm: onConfirm,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: CircularProgressIndicator(
                          color: SoundPickerTheme.accentOf(context),
                        ),
                      )
                    : SoundTrimWaveform(
                        bars: bars,
                        track: track,
                        window: window,
                        offset: offset,
                        onDrag: applying ? (_) {} : onDrag,
                      ),
              ),
              const SizedBox(height: 10),
              SoundTrimFooter(
                selectedLabel: l10n.soundSecondsSelected(selectedSeconds),
                timeLabel:
                    '${formatTrimClock(offset)} – ${formatTrimClock(offset + window)} / ${formatTrimClock(track)}',
              ),
              if (allowMute) ...[
                const SizedBox(height: 4),
                SoundTrimMuteTile(
                  value: muteOriginal,
                  onChanged: onMuteChanged,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String formatTrimClock(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Rounded waveform track with pink selection window.
class SoundTrimWaveform extends StatelessWidget {
  const SoundTrimWaveform({
    super.key,
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
    const height = 72.0;
    final scheme = Theme.of(context).colorScheme;
    final trackBg = scheme.surfaceContainerHighest.withValues(alpha: 0.55);

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

        void moveToLocalDx(double localDx) {
          final left = (localDx - windowW / 2).clamp(0.0, totalW - windowW);
          onDrag(totalW == 0 ? 0 : left / totalW);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => moveToLocalDx(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => moveToLocalDx(d.localPosition.dx),
          child: Container(
            height: height,
            width: totalW,
            decoration: BoxDecoration(
              color: trackBg,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: SoundTrimWaveformPainter(
                      bars: bars,
                      selectionStart: offsetFrac,
                      selectionEnd: (offsetFrac + windowFrac).clamp(0.0, 1.0),
                      idleColor: scheme.onSurface.withValues(alpha: 0.87),
                      accentColor: SoundPickerTheme.accentOf(context),
                    ),
                  ),
                ),
                Positioned(
                  left: windowLeft,
                  top: 0,
                  bottom: 0,
                  width: windowW,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: SoundPickerTheme.accentOf(context),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SoundTrimWaveformPainter extends CustomPainter {
  SoundTrimWaveformPainter({
    required this.bars,
    required this.selectionStart,
    required this.selectionEnd,
    required this.idleColor,
    required this.accentColor,
  });

  final List<double> bars;
  final double selectionStart;
  final double selectionEnd;
  final Color idleColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final selectedPaint = Paint()
      ..color = accentColor
      ..strokeCap = StrokeCap.round;
    final idlePaint = Paint()
      ..color = idleColor
      ..strokeCap = StrokeCap.round;

    final count = bars.isNotEmpty ? bars.length : (size.width ~/ 4);
    if (count <= 0) return;
    final step = size.width / count;
    final stroke = (step * 0.45).clamp(1.0, 3.0);
    selectedPaint.strokeWidth = stroke;
    idlePaint.strokeWidth = stroke;
    final mid = size.height / 2;

    for (var i = 0; i < count; i++) {
      final amp = bars.isNotEmpty ? bars[i].clamp(0.0, 1.0) : 0.35;
      final h = (amp * size.height * 0.85).clamp(4.0, size.height);
      final x = step * i + step / 2;
      final frac = count <= 1 ? 0.0 : i / (count - 1);
      final inSelection = frac >= selectionStart && frac <= selectionEnd;
      canvas.drawLine(
        Offset(x, mid - h / 2),
        Offset(x, mid + h / 2),
        inSelection ? selectedPaint : idlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SoundTrimWaveformPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.selectionStart != selectionStart ||
      oldDelegate.selectionEnd != selectionEnd ||
      oldDelegate.idleColor != idleColor ||
      oldDelegate.accentColor != accentColor;
}
