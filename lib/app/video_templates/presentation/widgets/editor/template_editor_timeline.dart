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

/// Responsive sizing for the TikTok-style editor timeline.
class _EditorTimelineLayout {
  _EditorTimelineLayout._({
    required this.maxWidth,
    required this.screenWidth,
    required this.textScaler,
    required this.scale,
    this.verticalScale = 1.0,
  });

  factory _EditorTimelineLayout.of(BuildContext context, double maxWidth) {
    return _EditorTimelineLayout._(
      maxWidth: maxWidth,
      screenWidth: MediaQuery.sizeOf(context).width,
      textScaler: MediaQuery.textScalerOf(context),
      scale: (MediaQuery.sizeOf(context).width / 390).clamp(0.78, 1.12),
    );
  }

  _EditorTimelineLayout withVerticalScale(double scale) {
    return _EditorTimelineLayout._(
      maxWidth: maxWidth,
      screenWidth: screenWidth,
      textScaler: textScaler,
      scale: this.scale,
      verticalScale: scale.clamp(0.72, 1.0),
    );
  }

  /// Reference duration that fills the scrollable track area (full width).
  static const double fullWidthReferenceSeconds = 5.0;

  /// Ruler / grid hint spacing (seconds between minor ticks when space allows).
  static const double secondsPerGridUnit = 2.0;

  final double maxWidth;
  final double screenWidth;
  final TextScaler textScaler;
  final double scale;
  final double verticalScale;

  double _d(double design) => design * scale;
  double _v(double design) => _d(design) * verticalScale;

  double get horizontalPadding => _d(12).clamp(8, 16);
  double get leftGutter => _d(52).clamp(42, 58);
  double get contentTrailingPad => _d(8).clamp(6, 10);
  double get slotGap => _d(4).clamp(3, 5);
  double get mediaRowHeight => _v(52).clamp(38, 58);
  double get trackHeight => _v(24).clamp(18, 30);
  double get trackGap => _v(3).clamp(2, 5);
  double get rulerHeight => _v(16).clamp(13, 20);
  double get sectionGap => _v(4).clamp(3, 5);
  double get bodyBottomPad => _v(8).clamp(4, 10);
  double get addButtonWidth => _d(40).clamp(34, 46);
  double get minBarWidth => _d(8).clamp(6, 12);
  double get handleWidth => _d(14).clamp(11, 18);
  double get handlePillHeight => _v(14).clamp(10, 16);
  double get barRadius => _d(8).clamp(6, 10);
  double get iconSizeSm => _d(12).clamp(10, 14);
  double get iconSizeMd => _d(16).clamp(14, 18);
  double get iconSizeLg => _d(22).clamp(18, 24);
  double get gapSm => _d(4).clamp(2, 5);

  double sp(double size) =>
      textScaler.scale(size * scale.clamp(0.85, 1.1) * verticalScale);

  /// Bars narrower than ~2s on the timeline hide trim handles (icon-only).
  double get compactBarWidth =>
      trackAreaWidth *
      (secondsPerGridUnit / fullWidthReferenceSeconds) *
      0.85;

  /// Scrollable track area (viewport minus padding and fixed left rail).
  double get trackAreaWidth => math.max(
        100.0,
        maxWidth - horizontalPadding * 2 - leftGutter,
      );

  /// 5s spans the full track area; longer clips scale out and scroll.
  double get pxPerSecond => trackAreaWidth / fullWidthReferenceSeconds;

  double resolveTimelineWidth(double duration) {
    final safeDuration = math.max(duration, 0.01);
    final scaled = safeDuration * pxPerSecond;
    if (safeDuration <= fullWidthReferenceSeconds) {
      return trackAreaWidth;
    }
    return scaled;
  }

  /// Width of the horizontally scrollable track content.
  double scrollContentWidth(double timelineWidth) {
    if (timelineWidth > trackAreaWidth) {
      return timelineWidth + contentTrailingPad;
    }
    return trackAreaWidth;
  }

  bool needsHorizontalScroll(double timelineWidth) =>
      timelineWidth > trackAreaWidth + 0.5;
}

class TemplateEditorTimeline extends StatefulWidget {
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

  @override
  State<TemplateEditorTimeline> createState() => _TemplateEditorTimelineState();
}

class _TemplateEditorTimelineState extends State<TemplateEditorTimeline> {
  final ScrollController _horizontalScroll = ScrollController();
  double? _lastAutoScrollPlayhead;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TemplateEditorTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playhead != oldWidget.playhead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _autoScrollToPlayhead();
      });
    }
  }

  void _autoScrollToPlayhead() {
    if (!_horizontalScroll.hasClients) return;
    final position = _horizontalScroll.position;
    if (position.maxScrollExtent <= 0) return;

    final layout = _EditorTimelineLayout.of(
      context,
      MediaQuery.sizeOf(context).width,
    );
    final duration = math.max(widget.totalDuration, 0.01);
    final timelineWidth = layout.resolveTimelineWidth(duration);
    if (!layout.needsHorizontalScroll(timelineWidth)) return;

    final playheadX =
        (widget.playhead / duration * timelineWidth).clamp(0.0, timelineWidth);
    if (_lastAutoScrollPlayhead != null &&
        (playheadX - _lastAutoScrollPlayhead!).abs() < 0.05) {
      return;
    }
    _lastAutoScrollPlayhead = playheadX;

    final viewport = position.viewportDimension;
    final current = position.pixels;
    const edgePad = 48.0;
    if (playheadX < current + edgePad) {
      position.jumpTo((playheadX - edgePad).clamp(0.0, position.maxScrollExtent));
    } else if (playheadX > current + viewport - edgePad) {
      position.jumpTo(
        (playheadX - viewport + edgePad).clamp(0.0, position.maxScrollExtent),
      );
    }
  }

  double _overlayTracksHeight(_EditorTimelineLayout layout) {
    final byKind = _segmentsByKind();
    var height = 0.0;
    for (final kind in _laneOrder) {
      final segments = byKind[kind];
      if (segments == null || segments.isEmpty) continue;
      final subLanes = _maxOverlapLanes(segments);
      height += layout.trackHeight * subLanes + layout.trackGap;
    }
    return height > 0 ? height + layout.sectionGap : 0;
  }

  double _timelineBodyHeight(_EditorTimelineLayout layout) {
    return layout.mediaRowHeight +
        _overlayTracksHeight(layout) +
        layout.bodyBottomPad;
  }

  double _timelineTotalHeight(_EditorTimelineLayout layout) {
    return layout.rulerHeight + layout.sectionGap + _timelineBodyHeight(layout);
  }

  _EditorTimelineLayout _layoutFittedToHeight(
    _EditorTimelineLayout layout,
    double maxHeight,
  ) {
    if (!maxHeight.isFinite || maxHeight <= 0) return layout;
    var fitted = layout;
    var total = _timelineTotalHeight(fitted);

    for (var pass = 0; pass < 6 && total > maxHeight + 0.01; pass++) {
      if (fitted.verticalScale <= 0.72) break;
      final nextScale = (fitted.verticalScale * (maxHeight / total))
          .clamp(0.72, 1.0);
      if ((nextScale - fitted.verticalScale).abs() < 0.001) break;
      fitted = fitted.withVerticalScale(nextScale);
      total = _timelineTotalHeight(fitted);
    }
    return fitted;
  }

  Map<TemplateEditorOverlayKind, List<TemplateEditorOverlaySegment>>
      _segmentsByKind() {
    final byKind =
        <TemplateEditorOverlayKind, List<TemplateEditorOverlaySegment>>{};
    for (final segment in widget.overlaySegments) {
      (byKind[segment.kind] ??= []).add(segment);
    }
    return byKind;
  }

  static int _maxOverlapLanes(List<TemplateEditorOverlaySegment> segments) {
    if (segments.length <= 1) return 1;
    final laneEnds = <double>[];
    for (final segment in segments) {
      final start = math.min(segment.start, segment.end);
      final end = math.max(segment.start, segment.end);
      var lane = 0;
      for (; lane < laneEnds.length; lane++) {
        if (start >= laneEnds[lane] - 0.001) break;
      }
      if (lane == laneEnds.length) {
        laneEnds.add(end);
      } else {
        laneEnds[lane] = end;
      }
    }
    return math.max(1, laneEnds.length);
  }

  static Map<String, int> _assignOverlapLanes(
    List<TemplateEditorOverlaySegment> segments,
  ) {
    final laneEnds = <double>[];
    final out = <String, int>{};
    for (final segment in segments) {
      final start = math.min(segment.start, segment.end);
      final end = math.max(segment.start, segment.end);
      var lane = 0;
      for (; lane < laneEnds.length; lane++) {
        if (start >= laneEnds[lane] - 0.001) break;
      }
      if (lane == laneEnds.length) {
        laneEnds.add(end);
      } else {
        laneEnds[lane] = end;
      }
      out[segment.id] = lane;
    }
    return out;
  }

  /// One horizontal lane per overlay kind (TikTok-style).
  static const _laneOrder = <TemplateEditorOverlayKind>[
    TemplateEditorOverlayKind.audio,
    TemplateEditorOverlayKind.filter,
    TemplateEditorOverlayKind.effect,
    TemplateEditorOverlayKind.text,
    TemplateEditorOverlayKind.sticker,
  ];

  /// Ruler ticks every 2s when the fixed grid fits; otherwise widen.
  int _timeLabelStep(double duration, double pxPerSecond, double scale) {
    const gridStep = 2;
    if (gridStep * pxPerSecond >= 28) return gridStep;
    final minSpacing = 40.0 * scale.clamp(0.85, 1.1);
    const candidates = [1, 2, 5, 10, 15, 30, 60];
    for (final step in candidates) {
      if (step * pxPerSecond >= minSpacing || step >= duration) {
        return step;
      }
    }
    return duration.ceil().clamp(1, 999);
  }

  List<({TemplateEditorOverlayKind kind, double top, double height})>
      _overlayLaneMetrics(_EditorTimelineLayout layout) {
    final byKind = _segmentsByKind();
    final metrics =
        <({TemplateEditorOverlayKind kind, double top, double height})>[];
    var top = layout.mediaRowHeight + layout.sectionGap;

    for (final kind in _laneOrder) {
      final segments = byKind[kind];
      if (segments == null || segments.isEmpty) continue;

      final subLanes = _maxOverlapLanes(segments);
      final laneHeight =
          layout.trackHeight * subLanes + layout.trackGap * (subLanes - 1);
      metrics.add((kind: kind, top: top, height: laneHeight));
      top += laneHeight + layout.trackGap;
    }
    return metrics;
  }

  Widget _buildFixedLeftRail(
    _EditorTimelineLayout layout,
    List<({TemplateEditorOverlayKind kind, double top, double height})> lanes,
  ) {
    return SizedBox(
      width: layout.leftGutter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.onAddMedia != null)
            Positioned(
              left: 4,
              top: layout.rulerHeight + layout.sectionGap,
              height: layout.mediaRowHeight,
              child: _AddMediaButton(
                onTap: widget.onAddMedia!,
                width: layout.addButtonWidth,
                height: layout.mediaRowHeight,
                iconSize: layout.iconSizeLg,
              ),
            ),
          for (final lane in lanes)
            Positioned(
              left: layout.leftGutter - layout.iconSizeMd - 6,
              top: layout.rulerHeight + layout.sectionGap + lane.top +
                  (lane.height - layout.iconSizeMd) / 2,
              child: Icon(
                _laneIcon(lane.kind),
                color: TemplateEditorTheme.textMuted,
                size: layout.iconSizeMd,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollableTracks({
    required _EditorTimelineLayout layout,
    required double timelineWidth,
    required double scrollWidth,
    required double duration,
    required double pxPerSecond,
    required int labelStep,
    required double playheadX,
    required double bodyHeight,
    required List<({TemplateEditorOverlayKind kind, double top, double height})>
        lanes,
  }) {
    return SingleChildScrollView(
      controller: _horizontalScroll,
      scrollDirection: Axis.horizontal,
      physics: layout.needsHorizontalScroll(timelineWidth)
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      child: SizedBox(
        width: scrollWidth,
        height: layout.rulerHeight + layout.sectionGap + bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: layout.rulerHeight,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (var s = 0; s <= duration.ceil(); s += labelStep)
                    Positioned(
                      left: s * pxPerSecond,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          TemplateEditorTheme.formatTime(s.toDouble()),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            color: TemplateEditorTheme.textMuted,
                            fontSize: layout.sp(9),
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: layout.sectionGap),
            Expanded(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: timelineWidth,
                    height: layout.mediaRowHeight,
                    child: _buildMediaRow(
                      layout: layout,
                      timelineWidth: timelineWidth,
                      duration: duration,
                      slotWidths: _layoutSlotWidths(
                        timelineWidth,
                        duration,
                        layout,
                      ),
                    ),
                  ),
                  ..._buildOverlayTrackRows(
                    layout: layout,
                    lanes: lanes,
                    timelineWidth: timelineWidth,
                    duration: duration,
                  ),
                  Positioned(
                    left: playheadX,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(width: 2, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaRow({
    required _EditorTimelineLayout layout,
    required double timelineWidth,
    required double duration,
    required List<double> slotWidths,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.slots.length; i++)
              _SlotClipTile(
                slot: widget.slots[i],
                fill: widget.fills[widget.slots[i].id],
                width: slotWidths[i],
                selected: i == widget.selectedSlotIndex,
                isLast: i == widget.slots.length - 1,
                slotGap: layout.slotGap,
                barRadius: layout.barRadius,
                labelFontSize: layout.sp(9),
                iconSize: layout.iconSizeLg,
                onTap: widget.onSlotTap == null
                    ? null
                    : () => widget.onSlotTap!(i),
              ),
          ],
        ),
        if (widget.onSeek != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (d) {
                final t = (d.localPosition.dx / timelineWidth * duration)
                    .clamp(0.0, duration);
                widget.onSeek!(t);
              },
              onHorizontalDragUpdate: (d) {
                final t = (d.localPosition.dx / timelineWidth * duration)
                    .clamp(0.0, duration);
                widget.onSeek!(t);
              },
            ),
          ),
      ],
    );
  }

  List<double> _layoutSlotWidths(
    double timelineWidth,
    double totalDuration,
    _EditorTimelineLayout layout,
  ) {
    if (widget.slots.isEmpty) return const [];
    final gapTotal = math.max(0, widget.slots.length - 1) * layout.slotGap;
    final available = math.max(0, timelineWidth - gapTotal);
    final safeTotal = math.max(totalDuration, 0.01);
    final durations = widget.slots
        .map(
          (s) => UserProjectSlotMapper.resolveSlotDuration(
            s,
            widget.fills[s.id],
          ),
        )
        .toList();
    return [
      for (final d in durations) d / safeTotal * available,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseLayout =
            _EditorTimelineLayout.of(context, constraints.maxWidth);
        final layout = _layoutFittedToHeight(baseLayout, constraints.maxHeight);
        final duration = math.max(widget.totalDuration, 0.01);
        final timelineWidth = layout.resolveTimelineWidth(duration);
        final pxPerSecond = layout.pxPerSecond;
        final labelStep = _timeLabelStep(duration, pxPerSecond, layout.scale);
        final playheadX = (widget.playhead / duration * timelineWidth)
            .clamp(0.0, timelineWidth);
        final bodyHeight = _timelineBodyHeight(layout);
        final scrollWidth = layout.scrollContentWidth(timelineWidth);
        final lanes = _overlayLaneMetrics(layout);
        final totalHeight = _timelineTotalHeight(layout);
        final maxHeight = constraints.maxHeight;
        final needsVerticalScroll =
            maxHeight.isFinite && totalHeight > maxHeight + 0.01;

        final timeline = Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.horizontalPadding),
          child: SizedBox(
            height: totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFixedLeftRail(layout, lanes),
                Expanded(
                  child: _buildScrollableTracks(
                    layout: layout,
                    timelineWidth: timelineWidth,
                    scrollWidth: scrollWidth,
                    duration: duration,
                    pxPerSecond: pxPerSecond,
                    labelStep: labelStep,
                    playheadX: playheadX,
                    bodyHeight: bodyHeight,
                    lanes: lanes,
                  ),
                ),
              ],
            ),
          ),
        );

        if (needsVerticalScroll) {
          return SizedBox(
            height: maxHeight,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: timeline,
            ),
          );
        }

        return SizedBox(
          height: maxHeight.isFinite ? math.min(totalHeight, maxHeight) : totalHeight,
          child: Align(
            alignment: Alignment.topCenter,
            child: timeline,
          ),
        );
      },
    );
  }

  List<Widget> _buildOverlayTrackRows({
    required _EditorTimelineLayout layout,
    required List<({TemplateEditorOverlayKind kind, double top, double height})>
        lanes,
    required double timelineWidth,
    required double duration,
  }) {
    final byKind = _segmentsByKind();
    final widgets = <Widget>[];

    for (final lane in lanes) {
      final segments = byKind[lane.kind];
      if (segments == null || segments.isEmpty) continue;

      final laneAssignments = _assignOverlapLanes(segments);

      widgets.add(
        Positioned(
          left: 0,
          top: lane.top,
          width: timelineWidth,
          height: lane.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(layout.barRadius),
                  ),
                ),
              ),
              for (final segment in segments)
                _TimedTrackBar(
                  layout: layout,
                  barTop: (laneAssignments[segment.id] ?? 0) *
                      (layout.trackHeight + layout.trackGap),
                  barHeight: layout.trackHeight,
                  start: segment.start,
                  end: segment.end,
                  totalDuration: duration,
                  timelineWidth: timelineWidth,
                  label: segment.label,
                  color: segment.color,
                  icon: segment.icon,
                  selected: segment.selected ||
                      (widget.selectedOverlayId != null &&
                          widget.selectedOverlayId == segment.id),
                  editable:
                      segment.editable && widget.onOverlayRangeChanged != null,
                  onTap: widget.onOverlayTap == null
                      ? null
                      : () => widget.onOverlayTap!(segment.kind, segment.id),
                  onRangeChanged:
                      segment.editable && widget.onOverlayRangeChanged != null
                      ? (start, end) => widget.onOverlayRangeChanged!(
                            segment.kind,
                            segment.id,
                            start,
                            end,
                          )
                      : null,
                ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  static IconData _laneIcon(TemplateEditorOverlayKind kind) {
    return switch (kind) {
      TemplateEditorOverlayKind.audio => LucideIcons.volume2,
      TemplateEditorOverlayKind.filter => LucideIcons.blend,
      TemplateEditorOverlayKind.effect => LucideIcons.sparkles,
      TemplateEditorOverlayKind.text => LucideIcons.type,
      TemplateEditorOverlayKind.sticker => LucideIcons.sticker,
    };
  }
}

enum _Handle { start, end, move }

class _TimedTrackBar extends StatefulWidget {
  const _TimedTrackBar({
    required this.layout,
    required this.barTop,
    required this.barHeight,
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

  final _EditorTimelineLayout layout;
  final double barTop;
  final double barHeight;
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

  double? _dragStart;
  double? _dragEnd;
  _Handle? _handle;

  double get _start => _dragStart ?? widget.start;
  double get _end => _dragEnd ?? widget.end;

  static double _safeClamp(double value, double min, double max) {
    if (min > max) return max;
    return value.clamp(min, max);
  }

  ({double left, double width}) _barGeometry() {
    final layout = widget.layout;
    final safeTotal = math.max(widget.totalDuration, 0.01);
    final maxWidth = math.max(layout.minBarWidth, widget.timelineWidth);

    final start = _safeClamp(_start, 0.0, safeTotal);
    final end = _safeClamp(_end, start + 0.05, safeTotal);

    var left = _safeClamp(
      start / safeTotal * widget.timelineWidth,
      0.0,
      maxWidth - layout.minBarWidth,
    );
    var right = _safeClamp(
      end / safeTotal * widget.timelineWidth,
      left + layout.minBarWidth,
      maxWidth,
    );

    if (right <= left) {
      right = math.min(maxWidth, left + layout.minBarWidth);
      left = math.max(0.0, right - layout.minBarWidth);
    }

    final width = math.max(
      layout.minBarWidth,
      math.min(right - left, maxWidth - left),
    );
    return (left: left, width: width);
  }

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
        start = _safeClamp(start + deltaSeconds, 0.0, end - _minDuration);
      case _Handle.end:
        end = _safeClamp(end + deltaSeconds, start + _minDuration, total);
      case _Handle.move:
        final len = end - start;
        start = _safeClamp(start + deltaSeconds, 0.0, total - len);
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
    final layout = widget.layout;
    final safeTotal = math.max(widget.totalDuration, 0.01);
    final geometry = _barGeometry();
    final left = geometry.left;
    final width = geometry.width;
    final compact = width < layout.compactBarWidth;
    final showHandles =
        widget.editable && !compact && widget.onRangeChanged != null;

    return Positioned(
      left: left,
      top: widget.barTop,
      width: width,
      height: widget.barHeight,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: widget.selected ? 0.62 : 0.48),
            borderRadius: BorderRadius.circular(layout.barRadius),
            border: Border.all(
              color: widget.selected
                  ? Colors.white
                  : widget.color.withValues(alpha: 0.85),
              width: widget.selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: compact
              ? Center(
                  child: Icon(
                    widget.icon ?? LucideIcons.minus,
                    color: Colors.white,
                    size: layout.iconSizeSm,
                  ),
                )
              : Row(
                  children: [
                    if (showHandles)
                      _DragHandle(
                        width: layout.handleWidth,
                        pillHeight: layout.handlePillHeight,
                        onDragStart: () => _beginDrag(_Handle.start),
                        onDragUpdate: (dx) {
                          final dt = dx / widget.timelineWidth * safeTotal;
                          _updateDrag(dt);
                        },
                        onDragEnd: _endDrag,
                      ),
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        color: Colors.white,
                        size: layout.iconSizeSm,
                      ),
                      SizedBox(width: layout.gapSm),
                    ],
                    Expanded(
                      child: showHandles
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragStart: (_) =>
                                  _beginDrag(_Handle.move),
                              onHorizontalDragUpdate: (d) {
                                final dt = d.delta.dx /
                                    widget.timelineWidth *
                                    safeTotal;
                                _updateDrag(dt);
                              },
                              onHorizontalDragEnd: (_) => _endDrag(),
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: layout.sp(10),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: layout.sp(10),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    if (showHandles)
                      _DragHandle(
                        width: layout.handleWidth,
                        pillHeight: layout.handlePillHeight,
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
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.width,
    required this.pillHeight,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final double width;
  final double pillHeight;
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
            height: pillHeight,
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
  const _AddMediaButton({
    required this.onTap,
    required this.width,
    required this.height,
    required this.iconSize,
  });

  final VoidCallback onTap;
  final double width;
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: height,
          child: Icon(LucideIcons.plus, color: Colors.black, size: iconSize),
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
    required this.slotGap,
    required this.barRadius,
    required this.labelFontSize,
    required this.iconSize,
    this.isLast = false,
    this.onTap,
  });

  final VideoTemplateSlotEntity slot;
  final SlotFillEntry? fill;
  final double width;
  final bool selected;
  final bool isLast;
  final double slotGap;
  final double barRadius;
  final double labelFontSize;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dur = UserProjectSlotMapper.resolveSlotDuration(slot, fill);
    final hasMedia = fill?.hasMedia == true;
    final file = fill?.localFile;

    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : slotGap),
      child: Material(
        color: TemplateEditorTheme.panel,
        borderRadius: BorderRadius.circular(barRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(barRadius),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(barRadius),
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
                  Center(
                    child: Icon(
                      LucideIcons.imagePlus,
                      color: TemplateEditorTheme.textMuted,
                      size: iconSize,
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: labelFontSize,
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
