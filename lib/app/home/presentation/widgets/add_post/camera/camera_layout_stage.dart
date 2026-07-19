import 'dart:io';
import 'dart:typed_data';

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_layout_picker.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/material.dart';

class CameraLayoutStage extends StatelessWidget {
  const CameraLayoutStage({
    super.key,
    required this.mode,
    required this.cellPhotos,
    required this.activeCellIndex,
    this.onDeleteCell,
    this.onDuplicateCell,
    this.onImportCell,
  });

  final CameraLayoutMode mode;
  /// Per-cell media paths (photo or video). Null = empty.
  final List<String?> cellPhotos;
  final int activeCellIndex;

  /// Delete the captured media in a frame (before the grid is complete).
  final ValueChanged<int>? onDeleteCell;

  /// Duplicate the captured media in a frame into the next empty frame.
  final ValueChanged<int>? onDuplicateCell;

  /// Import a gallery photo into a specific empty frame (tap an empty frame).
  final ValueChanged<int>? onImportCell;

  @override
  Widget build(BuildContext context) {
    if (mode == CameraLayoutMode.off) return const SizedBox.shrink();

    // Duplicate is only possible while at least one frame is still empty.
    final canDuplicate = cellPhotos.any((p) => p == null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final count = mode.cellCount;
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < count; i++)
              Positioned.fromRect(
                rect: mode.cellRect(size, i),
                child: _LayoutCell(
                  index: i,
                  mediaPath: i < cellPhotos.length ? cellPhotos[i] : null,
                  isActive: i == activeCellIndex,
                  canDuplicate: canDuplicate,
                  onDelete: onDeleteCell,
                  onDuplicate: onDuplicateCell,
                  onImport: onImportCell,
                ),
              ),
            // Grid lines never intercept taps so the frames stay tappable.
            IgnorePointer(
              child: CustomPaint(
                painter: _LayoutGridPainter(mode: mode),
                size: size,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LayoutCell extends StatefulWidget {
  const _LayoutCell({
    required this.index,
    required this.mediaPath,
    required this.isActive,
    required this.canDuplicate,
    this.onDelete,
    this.onDuplicate,
    this.onImport,
  });

  final int index;
  final String? mediaPath;
  final bool isActive;
  final bool canDuplicate;
  final ValueChanged<int>? onDelete;
  final ValueChanged<int>? onDuplicate;
  final ValueChanged<int>? onImport;

  @override
  State<_LayoutCell> createState() => _LayoutCellState();
}

class _LayoutCellState extends State<_LayoutCell> {
  /// Whether the delete/duplicate actions are revealed on this captured cell.
  bool _showActions = false;

  @override
  void didUpdateWidget(covariant _LayoutCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Hide the actions if this frame's media changed (e.g. deleted / replaced)
    // or its active state flipped, so the reveal always starts fresh.
    if (oldWidget.mediaPath != widget.mediaPath ||
        oldWidget.isActive != widget.isActive) {
      _showActions = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaPath = widget.mediaPath;
    if (mediaPath != null) {
      final file = File(mediaPath);
      final Widget media = VideoThumbnailUtils.isVideoFile(file)
          ? _VideoCellThumb(path: mediaPath)
          : Image.file(
              file,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            );

      final showDelete = widget.onDelete != null;
      final showDuplicate = widget.onDuplicate != null && widget.canDuplicate;
      if (!showDelete && !showDuplicate) return media;

      // Actions are hidden by default; tap the picture to reveal them centered,
      // tap again to hide.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showActions = !_showActions),
        child: Stack(
          fit: StackFit.expand,
          children: [
            media,
            if (_showActions) ...[
              // Dim the frame so the centered actions stand out.
              const ColoredBox(color: Color(0x59000000)),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showDelete)
                      _CellActionButton(
                        icon: Icons.delete_outline_rounded,
                        onTap: () => widget.onDelete!(widget.index),
                      ),
                    if (showDelete && showDuplicate)
                      const SizedBox(width: 16),
                    if (showDuplicate)
                      _CellActionButton(
                        icon: Icons.copy_rounded,
                        onTap: () => widget.onDuplicate!(widget.index),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Active (live camera) cell: transparent so the preview shows through.
    // Tapping it reveals a centered gallery-import icon (tap again to hide);
    // tapping the icon picks a photo into this exact frame. Translucent hit
    // behavior keeps pinch-to-zoom on the preview working.
    if (widget.isActive) {
      if (widget.onImport == null) {
        return const IgnorePointer(child: SizedBox.expand());
      }
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() => _showActions = !_showActions),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const SizedBox.expand(),
            if (_showActions)
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onImport!(widget.index),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Empty (not-yet-shot) non-active cell: a simple, neutral mid-grey
    // placeholder — no icon, never intercepts taps.
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2C2E33),
              Color(0xFF3A3D44),
            ],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}

/// Small circular action button (delete / duplicate) shown on a captured frame.
class _CellActionButton extends StatelessWidget {
  const _CellActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _VideoCellThumb extends StatefulWidget {
  const _VideoCellThumb({required this.path});

  final String path;

  @override
  State<_VideoCellThumb> createState() => _VideoCellThumbState();
}

class _VideoCellThumbState extends State<_VideoCellThumb> {
  Future<Uint8List?>? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VideoCellThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  void _load() {
    _thumb = VideoThumbnailUtils.generateThumbnailBytes(
      widget.path,
      maxHeight: 480,
      quality: 80,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumb,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const ColoredBox(color: Color(0xFF1A1A1A));
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }
}

class _LayoutGridPainter extends CustomPainter {
  _LayoutGridPainter({required this.mode});

  final CameraLayoutMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    switch (mode) {
      case CameraLayoutMode.horizontal2:
        canvas.drawLine(
          Offset(0, size.height * 0.5),
          Offset(size.width, size.height * 0.5),
          paint,
        );
      case CameraLayoutMode.vertical2:
        canvas.drawLine(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height),
          paint,
        );
      case CameraLayoutMode.horizontal3:
        canvas.drawLine(
          Offset(0, size.height / 3),
          Offset(size.width, size.height / 3),
          paint,
        );
        canvas.drawLine(
          Offset(0, size.height * 2 / 3),
          Offset(size.width, size.height * 2 / 3),
          paint,
        );
      case CameraLayoutMode.grid2x2:
        canvas.drawLine(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height),
          paint,
        );
        canvas.drawLine(
          Offset(0, size.height * 0.5),
          Offset(size.width, size.height * 0.5),
          paint,
        );
      case CameraLayoutMode.grid3x2:
        // 2 columns x 3 rows: one vertical split + two horizontal splits.
        canvas.drawLine(
          Offset(size.width * 0.5, 0),
          Offset(size.width * 0.5, size.height),
          paint,
        );
        canvas.drawLine(
          Offset(0, size.height / 3),
          Offset(size.width, size.height / 3),
          paint,
        );
        canvas.drawLine(
          Offset(0, size.height * 2 / 3),
          Offset(size.width, size.height * 2 / 3),
          paint,
        );
      case CameraLayoutMode.off:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutGridPainter oldDelegate) =>
      oldDelegate.mode != mode;
}
