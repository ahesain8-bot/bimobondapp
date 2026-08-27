import 'dart:io';
import 'dart:math' as math;

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/app/video_templates/engine/slot/slot_engine.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum TemplateEditorOverlayKind { filter, effect, text, sticker, audio }

/// Timed bar on a secondary editor track (filter / effect / text / sticker).
class TemplateEditorOverlaySegment {
  const TemplateEditorOverlaySegment({
    required this.id,
    required this.kind,
    required this.start,
    required this.end,
    required this.label,
    required this.color,
    this.slotId,
    this.icon,
    this.editable = true,
    this.showVolumeIcon = false,
    this.selected = false,
  });

  final String id;
  final TemplateEditorOverlayKind kind;
  final double start;
  final double end;
  final String label;
  final Color color;
  final String? slotId;
  final IconData? icon;
  final bool editable;
  final bool showVolumeIcon;
  final bool selected;
}

typedef TemplateEditorOverlayTap = void Function(
  TemplateEditorOverlayKind kind,
  String id,
);

typedef TemplateEditorOverlayRangeChanged = void Function(
  TemplateEditorOverlayKind kind,
  String id,
  double start,
  double end,
);

class TemplateEditorTimeline extends StatelessWidget {
  const TemplateEditorTimeline({
    super.key,
    required this.slots,
    required this.fills,
    required this.playhead,
    required this.totalDuration,
    required this.selectedSlotIndex,
    this.soundLabel,
    this.overlaySegments = const [],
    this.onSlotTap,
    this.onAddMedia,
    this.onSeek,
    this.onOverlayRangeChanged,
    this.onOverlayTap,
    this.selectedOverlayId,
  });

  final List<VideoTemplateSlotEntity> slots;
  final Map<String, SlotFillEntry> fills;
  final double playhead;
  final double totalDuration;
  final int selectedSlotIndex;
  final String? soundLabel;
  final List<TemplateEditorOverlaySegment> overlaySegments;
  final ValueChanged<int>? onSlotTap;
  final VoidCallback? onAddMedia;
  final ValueChanged<double>? onSeek;
  final TemplateEditorOverlayRangeChanged? onOverlayRangeChanged;
  final TemplateEditorOverlayTap? onOverlayTap;
  final String? selectedOverlayId;

  static const double _maxPxPerSecond = 56;
  static const double _horizontalPadding = 12;
  static const double _mediaRowHeight = 56;
  static const double _trackHeight = 28;
  static const double _trackGap = 4;
  static const double _leftGutter = 52;

  static const double _slotGap = 4;
  static const double _contentTrailingPad = 8;

  /// Timeline track width so the full clip period fits on screen (with padding).
  double _resolveTimelineWidth(double maxWidth, double duration) {
    final safeDuration = math.max(duration, 0.01);
    final available = math.max(
      100.0,
      maxWidth - _horizontalPadding * 2 - _leftGutter - _contentTrailingPad,
    );
    // Cap px/sec for short clips so the bar is not too tiny; long clips shrink.
    final minWidth = math.min(available, safeDuration * _maxPxPerSecond);
    return minWidth.clamp(100.0, available);
  }

  double _pxPerSecond(double timelineWidth, double duration) {
    return timelineWidth / math.max(duration, 0.01);
  }

  /// Seconds between ruler labels — widens when the track is compressed.
  int _timeLabelStep(double duration, double pxPerSecond) {
    const minSpacing = 40.0;
    const candidates = [1, 2, 5, 10, 15, 30, 60];
    for (final step in candidates) {
      if (step * pxPerSecond >= minSpacing || step >= duration) {
        return step;
      }
    }
    return duration.ceil().clamp(1, 999);
  }

  List<double> _layoutSlotWidths(double timelineWidth) {
    if (slots.isEmpty) return const [];
    final gapTotal = math.max(0, slots.length - 1) * _slotGap;
    final available = math.max(0, timelineWidth - gapTotal);
    final durations = slots
        .map(
          (s) => UserProjectSlotMapper.resolveSlotDuration(
            s,
            fills[s.id],
          ),
        )
        .toList();
    final total = durations.fold<double>(0, (sum, d) => sum + d);
    if (total <= 0) {
      final even = available / slots.length;
      return List<double>.filled(slots.length, even);
    }
    return [
      for (final d in durations) d / total * available,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final duration = math.max(totalDuration, 0.01);
        final contentWidth = constraints.maxWidth - _horizontalPadding * 2;
        final timelineWidth = _resolveTimelineWidth(constraints.maxWidth, duration);
        final pxPerSecond = _pxPerSecond(timelineWidth, duration);
        final labelStep = _timeLabelStep(duration, pxPerSecond);
        final slotWidths = _layoutSlotWidths(timelineWidth);
        final playheadX =
            (playhead / duration * timelineWidth).clamp(0.0, timelineWidth);
        final trackCount = overlaySegments.length;
        final tracksHeight = trackCount == 0
            ? 0.0
            : trackCount * (_trackHeight + _trackGap) + 4;
        final bodyHeight = _mediaRowHeight + tracksHeight + 8;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
              child: SizedBox(
                width: contentWidth,
                height: 18,
                child: Stack(
                  children: [
                    for (var s = 0; s <= duration.ceil(); s += labelStep)
                      Positioned(
                        left: _leftGutter + s * pxPerSecond,
                        top: 0,
                        child: Text(
                          TemplateEditorTheme.formatTime(s.toDouble()),
                          style: const TextStyle(
                            color: TemplateEditorTheme.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
              child: SizedBox(
                width: contentWidth,
                height: bodyHeight.clamp(72.0, 260.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (onAddMedia != null)
                      Positioned(
                        left: 4,
                        top: 0,
                        height: _mediaRowHeight,
                        child: _AddMediaButton(onTap: onAddMedia!),
                      ),
                    Positioned(
                      left: _leftGutter,
                      top: 0,
                      width: timelineWidth,
                      height: _mediaRowHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < slots.length; i++)
                                _SlotClipTile(
                                  slot: slots[i],
                                  fill: fills[slots[i].id],
                                  width: slotWidths[i],
                                  selected: i == selectedSlotIndex,
                                  isLast: i == slots.length - 1,
                                  onTap: onSlotTap == null
                                      ? null
                                      : () => onSlotTap!(i),
                                ),
                            ],
                          ),
                          if (onSeek != null)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapDown: (d) {
                                  final t = (d.localPosition.dx /
                                              timelineWidth *
                                              duration)
                                      .clamp(0.0, duration);
                                  onSeek!(t);
                                },
                                onHorizontalDragUpdate: (d) {
                                  final t = (d.localPosition.dx /
                                              timelineWidth *
                                              duration)
                                      .clamp(0.0, duration);
                                  onSeek!(t);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    ..._buildOverlayTracks(timelineWidth, duration),
                    Positioned(
                      left: _leftGutter + playheadX,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(width: 2, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildOverlayTracks(
    double timelineWidth,
    double duration,
  ) {
    final widgets = <Widget>[];
    var top = _mediaRowHeight + 4.0;

    for (final segment in overlaySegments) {
      if (segment.showVolumeIcon) {
        widgets.add(
          Positioned(
            left: 0,
            top: top + (_trackHeight - 16) / 2,
            child: const Icon(
              LucideIcons.volume2,
              color: TemplateEditorTheme.textMuted,
              size: 16,
            ),
          ),
        );
      }
      widgets.add(
        Positioned(
          left: _leftGutter,
          top: top,
          width: timelineWidth,
          height: _trackHeight,
          child: _TimedTrackBar(
            start: segment.start,
            end: segment.end,
            totalDuration: duration,
            timelineWidth: timelineWidth,
            label: segment.label,
            color: segment.color,
            icon: segment.icon,
            selected: segment.selected ||
                (selectedOverlayId != null && selectedOverlayId == segment.id),
            editable: segment.editable && onOverlayRangeChanged != null,
            onTap: onOverlayTap == null
                ? null
                : () => onOverlayTap!(segment.kind, segment.id),
            onRangeChanged: segment.editable && onOverlayRangeChanged != null
                ? (start, end) => onOverlayRangeChanged!(
                      segment.kind,
                      segment.id,
                      start,
                      end,
                    )
                : null,
          ),
        ),
      );
      top += _trackHeight + _trackGap;
    }
    return widgets;
  }
}

enum _Handle { start, end, move }

class _TimedTrackBar extends StatefulWidget {
  const _TimedTrackBar({
    required this.start,
    required this.end,
    required this.totalDuration,
    required this.timelineWidth,
    required this.label,
    required this.color,
    this.icon,
    this.selected = false,
    this.editable = false,
    this.onTap,
    this.onRangeChanged,
  });

  final double start;
  final double end;
  final double totalDuration;
  final double timelineWidth;
  final String label;
  final Color color;
  final IconData? icon;
  final bool selected;
  final bool editable;
  final VoidCallback? onTap;
  final void Function(double start, double end)? onRangeChanged;

  @override
  State<_TimedTrackBar> createState() => _TimedTrackBarState();
}

class _TimedTrackBarState extends State<_TimedTrackBar> {
  static const _minDuration = 0.2;
  static const _handleWidth = 14.0;

  double? _dragStart;
  double? _dragEnd;
  _Handle? _handle;

  double get _start => _dragStart ?? widget.start;
  double get _end => _dragEnd ?? widget.end;

  @override
  void didUpdateWidget(covariant _TimedTrackBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_handle == null &&
        (oldWidget.start != widget.start || oldWidget.end != widget.end)) {
      _dragStart = null;
      _dragEnd = null;
    }
  }

  void _beginDrag(_Handle handle) {
    setState(() {
      _handle = handle;
      _dragStart = widget.start;
      _dragEnd = widget.end;
    });
  }

  void _updateDrag(double deltaSeconds) {
    if (_handle == null) return;
    final total = math.max(widget.totalDuration, 0.01);
    var start = _start;
    var end = _end;

    switch (_handle!) {
      case _Handle.start:
        start = (start + deltaSeconds).clamp(0.0, end - _minDuration);
      case _Handle.end:
        end = (end + deltaSeconds).clamp(start + _minDuration, total);
      case _Handle.move:
        final len = end - start;
        start = (start + deltaSeconds).clamp(0.0, total - len);
        end = start + len;
    }

    setState(() {
      _dragStart = start;
      _dragEnd = end;
    });
    widget.onRangeChanged?.call(start, end);
  }

  void _endDrag() {
    setState(() {
      _handle = null;
      _dragStart = null;
      _dragEnd = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeTotal = math.max(widget.totalDuration, 0.01);
    final left =
        (_start / safeTotal * widget.timelineWidth).clamp(0.0, widget.timelineWidth);
    final right = (_end / safeTotal * widget.timelineWidth)
        .clamp(left + 8, widget.timelineWidth);
    final width = math.max(8.0, right - left);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: left,
          width: width,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: widget.selected ? 0.55 : 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.selected
                    ? Colors.white
                    : widget.color.withValues(alpha: 0.75),
                width: widget.selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                if (widget.editable)
                  _DragHandle(
                    width: _handleWidth,
                    onDragStart: () => _beginDrag(_Handle.start),
                    onDragUpdate: (dx) {
                      final dt = dx / widget.timelineWidth * safeTotal;
                      _updateDrag(dt);
                    },
                    onDragEnd: _endDrag,
                  ),
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: widget.editable
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (_) =>
                              _beginDrag(_Handle.move),
                          onHorizontalDragUpdate: (d) {
                            final dt =
                                d.delta.dx / widget.timelineWidth * safeTotal;
                            _updateDrag(dt);
                          },
                          onHorizontalDragEnd: (_) => _endDrag(),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                if (widget.editable)
                  _DragHandle(
                    width: _handleWidth,
                    onDragStart: () => _beginDrag(_Handle.end),
                    onDragUpdate: (dx) {
                      final dt = dx / widget.timelineWidth * safeTotal;
                      _updateDrag(dt);
                    },
                    onDragEnd: _endDrag,
                  ),
              ],
            ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.width,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final double width;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => onDragStart(),
      onHorizontalDragUpdate: (d) => onDragUpdate(d.delta.dx),
      onHorizontalDragEnd: (_) => onDragEnd(),
      child: SizedBox(
        width: width,
        child: Center(
          child: Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMediaButton extends StatelessWidget {
  const _AddMediaButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const SizedBox(
          width: 44,
          height: 56,
          child: Icon(LucideIcons.plus, color: Colors.black, size: 22),
        ),
      ),
    );
  }
}

class _SlotClipTile extends StatelessWidget {
  const _SlotClipTile({
    required this.slot,
    required this.fill,
    required this.width,
    required this.selected,
    this.isLast = false,
    this.onTap,
  });

  final VideoTemplateSlotEntity slot;
  final SlotFillEntry? fill;
  final double width;
  final bool selected;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dur = UserProjectSlotMapper.resolveSlotDuration(slot, fill);
    final hasMedia = fill?.hasMedia == true;
    final file = fill?.localFile;

    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : TemplateEditorTimeline._slotGap),
      child: Material(
        color: TemplateEditorTheme.panel,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? TemplateEditorTheme.slotSelectedBorder
                    : TemplateEditorTheme.border,
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (file != null && hasMedia)
                  _SlotThumbnail(file: file, isVideo: fill!.isLocalVideo)
                else
                  const Center(
                    child: Icon(
                      LucideIcons.imagePlus,
                      color: TemplateEditorTheme.textMuted,
                      size: 22,
                    ),
                  ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${dur.toStringAsFixed(1)}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotThumbnail extends StatelessWidget {
  const _SlotThumbnail({required this.file, required this.isVideo});

  final File file;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    if (!isVideo) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return FutureBuilder<File?>(
      future: VideoThumbnailUtils.generateThumbnailFile(file),
      builder: (context, snap) {
        final thumb = snap.data;
        if (thumb != null) {
          return Image.file(thumb, fit: BoxFit.cover);
        }
        return const ColoredBox(
          color: TemplateEditorTheme.panelElevated,
          child: Center(
            child: Icon(LucideIcons.film, color: TemplateEditorTheme.textMuted),
          ),
        );
      },
    );
  }
}
