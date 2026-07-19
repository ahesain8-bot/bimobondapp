import 'dart:io';
import 'dart:typed_data';

import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:bimobondapp/core/utils/video_trim_segment.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

/// Full-screen video trimmer: trim start/end, split at the playhead and delete
/// parts. Returns the kept [VideoTrimSegment] ranges (or null on cancel).
class VideoSegmentEditorScreen extends StatefulWidget {
  const VideoSegmentEditorScreen({
    super.key,
    required this.file,
    this.initialSegments = const [],
  });

  final File file;
  final List<VideoTrimSegment> initialSegments;

  static Future<List<VideoTrimSegment>?> show(
    BuildContext context, {
    required File file,
    List<VideoTrimSegment> initialSegments = const [],
  }) {
    return Navigator.of(context).push<List<VideoTrimSegment>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VideoSegmentEditorScreen(
          file: file,
          initialSegments: initialSegments,
        ),
      ),
    );
  }

  @override
  State<VideoSegmentEditorScreen> createState() =>
      _VideoSegmentEditorScreenState();
}

class _VideoSegmentEditorScreenState extends State<VideoSegmentEditorScreen> {
  static const _accent = Color(0xFFFE2C55);
  static const _handleW = 12.0;
  static const _handleHit = 34.0;
  static const _trackH = 60.0;
  static const _minSegment = Duration(milliseconds: 400);
  static const _thumbCount = 12;

  VideoPlayerController? _controller;
  Duration _duration = Duration.zero;
  bool _ready = false;

  /// Kept ranges of the source timeline, always sorted and non-overlapping.
  List<VideoTrimSegment> _segments = [];
  int _selected = 0;

  final List<Uint8List?> _thumbs = List<Uint8List?>.filled(_thumbCount, null);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.file(widget.file);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _duration = controller.value.duration;
      _segments = widget.initialSegments.isNotEmpty
          ? _sanitize(widget.initialSegments)
          : [VideoTrimSegment(start: Duration.zero, end: _duration)];
      controller.addListener(_onTick);
      await controller.setLooping(false);
      await controller.seekTo(_segments.first.start);
      await controller.play();
      setState(() => _ready = true);
      _loadThumbs();
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  List<VideoTrimSegment> _sanitize(List<VideoTrimSegment> input) {
    final list = input
        .where((s) => s.end > s.start)
        .map(
          (s) => VideoTrimSegment(
            start: s.start < Duration.zero ? Duration.zero : s.start,
            end: s.end > _duration ? _duration : s.end,
          ),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (list.isEmpty) {
      return [VideoTrimSegment(start: Duration.zero, end: _duration)];
    }
    return list;
  }

  Future<void> _loadThumbs() async {
    final durMs = _duration.inMilliseconds;
    if (durMs <= 0) return;
    for (var i = 0; i < _thumbCount; i++) {
      final t = (durMs * (i + 0.5) / _thumbCount).round();
      final bytes = await VideoThumbnailUtils.generateThumbnailBytes(
        widget.file.path,
        timeMs: t,
        maxHeight: 120,
        quality: 60,
      );
      if (!mounted) return;
      setState(() => _thumbs[i] = bytes);
    }
  }

  /// Keeps playback inside the kept ranges: when the playhead runs past a
  /// segment (into a trimmed-out gap or the end), jump to the next kept start.
  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isPlaying) {
      if (mounted) setState(() {});
      return;
    }
    final pos = controller.value.position;
    final inSegment = _segments.any((s) => pos >= s.start && pos < s.end);
    if (!inSegment) {
      final next = _segments.firstWhere(
        (s) => s.start > pos,
        orElse: () => _segments.first,
      );
      controller.seekTo(next.start);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Duration get _playhead => _controller?.value.position ?? Duration.zero;

  // ---- Editing actions -----------------------------------------------------

  void _splitAtPlayhead() {
    final pos = _playhead;
    final idx = _segments.indexWhere((s) => pos > s.start && pos < s.end);
    if (idx < 0) return;
    final seg = _segments[idx];
    if (pos - seg.start < _minSegment || seg.end - pos < _minSegment) return;
    setState(() {
      _segments = [
        ..._segments.sublist(0, idx),
        VideoTrimSegment(start: seg.start, end: pos),
        VideoTrimSegment(start: pos, end: seg.end),
        ..._segments.sublist(idx + 1),
      ];
      _selected = idx + 1;
    });
  }

  void _deleteSelected() {
    if (_segments.length <= 1) return;
    setState(() {
      _segments = [..._segments]..removeAt(_selected);
      _selected = _selected.clamp(0, _segments.length - 1);
    });
    _controller?.seekTo(_segments[_selected].start);
  }

  void _dragHandle({
    required int index,
    required bool isStart,
    required double dxTime,
  }) {
    final seg = _segments[index];
    final delta = Duration(milliseconds: dxTime.round());
    if (isStart) {
      var newStart = seg.start + delta;
      final lowerBound =
          index > 0 ? _segments[index - 1].end : Duration.zero;
      final upperBound = seg.end - _minSegment;
      if (newStart < lowerBound) newStart = lowerBound;
      if (newStart > upperBound) newStart = upperBound;
      setState(() => _segments[index] = seg.copyWith(start: newStart));
      _controller?.seekTo(newStart);
    } else {
      var newEnd = seg.end + delta;
      final upperBound =
          index < _segments.length - 1 ? _segments[index + 1].start : _duration;
      final lowerBound = seg.start + _minSegment;
      if (newEnd > upperBound) newEnd = upperBound;
      if (newEnd < lowerBound) newEnd = lowerBound;
      setState(() => _segments[index] = seg.copyWith(end: newEnd));
      _controller?.seekTo(newEnd - const Duration(milliseconds: 200));
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        if (!_segments.any((s) =>
            c.value.position >= s.start && c.value.position < s.end)) {
          c.seekTo(_segments.first.start);
        }
        c.play();
      }
    });
  }

  Duration get _keptDuration =>
      _segments.fold(Duration.zero, (a, s) => a + s.duration);

  /// Returns the kept ranges, or an empty list when the clip is untouched
  /// (single full-length segment) so the export can skip re-encoding.
  List<VideoTrimSegment> _resultSegments() {
    if (videoSegmentsAreTrimmed(_segments, _duration)) return _segments;
    return const [];
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(l10n),
            Expanded(
              child: Center(
                child: _ready &&
                        controller != null &&
                        controller.value.isInitialized
                    ? GestureDetector(
                        onTap: _togglePlay,
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio == 0
                              ? 9 / 16
                              : controller.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(controller),
                              if (!controller.value.isPlaying)
                                const _PlayGlyph(),
                            ],
                          ),
                        ),
                      )
                    : const CircularProgressIndicator(color: Colors.white54),
              ),
            ),
            if (_ready) _actionsRow(l10n),
            if (_ready) _timeline(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _topBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.x, color: Colors.white),
          ),
          Expanded(
            child: Text(
              l10n.mediaEditorTrim,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_resultSegments()),
            child: Text(
              l10n.mediaEditorDone,
              style: const TextStyle(
                color: _accent,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_fmt(_playhead)} / ${_fmt(_keptDuration)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          _pillButton(
            icon: LucideIcons.scissors,
            label: l10n.videoEditorSplit,
            onTap: _splitAtPlayhead,
          ),
          const SizedBox(width: 10),
          _pillButton(
            icon: LucideIcons.trash2,
            label: l10n.videoEditorDeleteSegment,
            onTap: _segments.length > 1 ? _deleteSelected : null,
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Left offset (px) of each kept segment on a COLLAPSED timeline where the
  /// full clip fits [trackW] at a fixed scale. Deleted/trimmed parts disappear,
  /// so the strip visibly shrinks and reflows after every edit.
  List<double> _layoutLefts(double pxPerMs) {
    final lefts = <double>[];
    var cursor = 0.0;
    for (final seg in _segments) {
      lefts.add(cursor);
      cursor += seg.duration.inMilliseconds * pxPerMs;
    }
    return lefts;
  }

  /// Playhead x on the collapsed timeline (source position mapped through the
  /// kept ranges).
  double _collapsedPlayheadPx(double pxPerMs) {
    final pos = _playhead;
    var acc = 0.0;
    for (final seg in _segments) {
      if (pos >= seg.start && pos <= seg.end) {
        return (acc + (pos - seg.start).inMilliseconds) * pxPerMs;
      }
      acc += seg.duration.inMilliseconds * pxPerMs;
    }
    return acc;
  }

  Widget _timeline() {
    final durMs = _duration.inMilliseconds;
    if (durMs <= 0) return const SizedBox(height: _trackH + 20);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fixed scale: the whole clip == track width. Trimming/deleting only
          // shrinks the content (never rescales), so a dragged handle stays put
          // under the finger.
          final trackW = constraints.maxWidth;
          final pxPerMs = trackW / durMs;
          final lefts = _layoutLefts(pxPerMs);
          final totalW = _keptDuration.inMilliseconds * pxPerMs;
          // Center the collapsed strip so trimming/deleting pulls both ends
          // inward (natural feel) instead of pinning the left edge at 0.
          final offset = ((trackW - totalW) / 2).clamp(0.0, trackW);
          final playheadX =
              (_collapsedPlayheadPx(pxPerMs) + offset).clamp(0.0, trackW);

          final children = <Widget>[];
          for (var i = 0; i < _segments.length; i++) {
            final seg = _segments[i];
            final left = lefts[i] + offset;
            final width = seg.duration.inMilliseconds * pxPerMs;
            children.add(_segmentBlock(index: i, left: left, width: width));
          }

          // Handles only on the selected clip — keeps the strip uncluttered and
          // makes "grab the edge to cut" obvious.
          if (_selected >= 0 && _selected < _segments.length) {
            final left = lefts[_selected] + offset;
            final width = _segments[_selected].duration.inMilliseconds * pxPerMs;
            children
              ..add(
                _buildHandle(
                  edgeX: left,
                  isStart: true,
                  onDrag: (dx) => _dragHandle(
                    index: _selected,
                    isStart: true,
                    dxTime: dx / pxPerMs,
                  ),
                ),
              )
              ..add(
                _buildHandle(
                  edgeX: left + width,
                  isStart: false,
                  onDrag: (dx) => _dragHandle(
                    index: _selected,
                    isStart: false,
                    dxTime: dx / pxPerMs,
                  ),
                ),
              );
          }

          children.add(
            Positioned(
              left: playheadX - 1,
              top: 2,
              height: _trackH + 4,
              child: IgnorePointer(
                child: Container(width: 2, color: Colors.white),
              ),
            ),
          );

          return SizedBox(
            height: _trackH + 16,
            child: Stack(clipBehavior: Clip.none, children: children),
          );
        },
      ),
    );
  }

  Widget _segmentBlock({
    required int index,
    required double left,
    required double width,
  }) {
    final seg = _segments[index];
    final isSel = index == _selected;
    final thumbs = _segmentThumbs(seg);
    // Small gap between clips so multiple pieces read as separate.
    const gap = 2.0;
    final w = (width - gap).clamp(2.0, double.infinity);

    return Positioned(
      left: left + gap / 2,
      width: w,
      top: 6,
      height: _trackH,
      child: GestureDetector(
        onTap: () => setState(() => _selected = index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  for (final t in thumbs)
                    Expanded(
                      child: t != null
                          ? Image.memory(t, fit: BoxFit.cover)
                          : const ColoredBox(color: Color(0xFF1C1C1E)),
                    ),
                ],
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSel ? _accent : Colors.white70,
                    width: isSel ? 2.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The source-sampled thumbnails that fall inside [seg]; if the clip is too
  /// short to contain any sample, the nearest one to its midpoint is used.
  List<Uint8List?> _segmentThumbs(VideoTrimSegment seg) {
    final durMs = _duration.inMilliseconds;
    if (durMs <= 0) return const [null];
    final startMs = seg.start.inMilliseconds;
    final endMs = seg.end.inMilliseconds;
    final inRange = <Uint8List?>[];
    for (var i = 0; i < _thumbCount; i++) {
      final t = durMs * (i + 0.5) / _thumbCount;
      if (t >= startMs && t <= endMs) inRange.add(_thumbs[i]);
    }
    if (inRange.isNotEmpty) return inRange;

    final mid = (startMs + endMs) / 2;
    var bestI = 0;
    var bestD = double.infinity;
    for (var i = 0; i < _thumbCount; i++) {
      final t = durMs * (i + 0.5) / _thumbCount;
      final d = (t - mid).abs();
      if (d < bestD) {
        bestD = d;
        bestI = i;
      }
    }
    return [_thumbs[bestI]];
  }

  Widget _buildHandle({
    required double edgeX,
    required ValueChanged<double> onDrag,
    required bool isStart,
  }) {
    // Wide, transparent hit area centered on the edge for an easy grab; a slim
    // accent bar shows where the cut point is.
    return Positioned(
      left: edgeX - _handleHit / 2,
      top: 0,
      height: _trackH + 12,
      width: _handleHit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        child: Center(
          child: Container(
            width: _handleW,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              LucideIcons.gripVertical,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}

class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
    );
  }
}
