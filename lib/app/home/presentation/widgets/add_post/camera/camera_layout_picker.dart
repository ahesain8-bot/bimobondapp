import 'package:flutter/material.dart';

enum CameraLayoutMode {
  off,
  horizontal2,
  vertical2,
  horizontal3,
  grid2x2,
  grid3x2,
}

extension CameraLayoutModeX on CameraLayoutMode {
  int get cellCount => switch (this) {
        CameraLayoutMode.off => 0,
        CameraLayoutMode.horizontal2 => 2,
        CameraLayoutMode.vertical2 => 2,
        CameraLayoutMode.horizontal3 => 3,
        CameraLayoutMode.grid2x2 => 4,
        CameraLayoutMode.grid3x2 => 6,
      };

  /// Fractional cell rects in [0,1] space (left, top, width, height).
  List<(double, double, double, double)> get cellFractions => switch (this) {
        CameraLayoutMode.off => const [],
        CameraLayoutMode.horizontal2 => const [
            (0, 0, 1, 0.5),
            (0, 0.5, 1, 0.5),
          ],
        CameraLayoutMode.vertical2 => const [
            (0, 0, 0.5, 1),
            (0.5, 0, 0.5, 1),
          ],
        CameraLayoutMode.horizontal3 => const [
            (0, 0, 1, 1 / 3),
            (0, 1 / 3, 1, 1 / 3),
            (0, 2 / 3, 1, 1 / 3),
          ],
        CameraLayoutMode.grid2x2 => const [
            (0, 0, 0.5, 0.5),
            (0.5, 0, 0.5, 0.5),
            (0, 0.5, 0.5, 0.5),
            (0.5, 0.5, 0.5, 0.5),
          ],
        // 2 columns x 3 rows (2-2-2). Enum name kept for compatibility.
        CameraLayoutMode.grid3x2 => const [
            (0, 0, 0.5, 1 / 3),
            (0.5, 0, 0.5, 1 / 3),
            (0, 1 / 3, 0.5, 1 / 3),
            (0.5, 1 / 3, 0.5, 1 / 3),
            (0, 2 / 3, 0.5, 1 / 3),
            (0.5, 2 / 3, 0.5, 1 / 3),
          ],
      };

  Rect cellRect(Size size, int index) {
    final f = cellFractions[index];
    return Rect.fromLTWH(
      f.$1 * size.width,
      f.$2 * size.height,
      f.$3 * size.width,
      f.$4 * size.height,
    );
  }
}

class CameraLayoutPickerPopup extends StatelessWidget {
  const CameraLayoutPickerPopup({
    super.key,
    required this.selected,
    required this.offLabel,
    required this.onSelected,
  });

  final CameraLayoutMode selected;
  final String offLabel;
  final ValueChanged<CameraLayoutMode> onSelected;

  static const _modes = [
    CameraLayoutMode.horizontal2,
    CameraLayoutMode.vertical2,
    CameraLayoutMode.horizontal3,
    CameraLayoutMode.grid2x2,
    CameraLayoutMode.grid3x2,
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => onSelected(CameraLayoutMode.off),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  offLabel,
                  style: TextStyle(
                    color: selected == CameraLayoutMode.off
                        ? Colors.white
                        : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final mode in _modes) ...[
              _LayoutOptionTile(
                mode: mode,
                selected: selected == mode,
                onTap: () => onSelected(mode),
              ),
              if (mode != _modes.last) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _LayoutOptionTile extends StatelessWidget {
  const _LayoutOptionTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final CameraLayoutMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: CameraLayoutIcon(
          mode: mode,
          color: selected ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class CameraLayoutIcon extends StatelessWidget {
  const CameraLayoutIcon({
    super.key,
    required this.mode,
    this.color = Colors.white,
    this.size = 22,
  });

  final CameraLayoutMode mode;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (mode == CameraLayoutMode.off) {
      return Icon(Icons.grid_view_rounded, color: color, size: size * 0.85);
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _LayoutIconPainter(mode: mode, color: color),
    );
  }
}

class _LayoutIconPainter extends CustomPainter {
  _LayoutIconPainter({required this.mode, required this.color});

  final CameraLayoutMode mode;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final r = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    canvas.drawRect(r, paint);

    switch (mode) {
      case CameraLayoutMode.horizontal2:
        canvas.drawLine(
          Offset(r.left, r.center.dy),
          Offset(r.right, r.center.dy),
          paint,
        );
      case CameraLayoutMode.vertical2:
        canvas.drawLine(
          Offset(r.center.dx, r.top),
          Offset(r.center.dx, r.bottom),
          paint,
        );
      case CameraLayoutMode.horizontal3:
        final y1 = r.top + r.height / 3;
        final y2 = r.top + r.height * 2 / 3;
        canvas.drawLine(Offset(r.left, y1), Offset(r.right, y1), paint);
        canvas.drawLine(Offset(r.left, y2), Offset(r.right, y2), paint);
      case CameraLayoutMode.grid2x2:
        canvas.drawLine(
          Offset(r.center.dx, r.top),
          Offset(r.center.dx, r.bottom),
          paint,
        );
        canvas.drawLine(
          Offset(r.left, r.center.dy),
          Offset(r.right, r.center.dy),
          paint,
        );
      case CameraLayoutMode.grid3x2:
        // 2 columns x 3 rows: one vertical split + two horizontal splits.
        final rowH = r.height / 3;
        canvas.drawLine(
          Offset(r.center.dx, r.top),
          Offset(r.center.dx, r.bottom),
          paint,
        );
        canvas.drawLine(
          Offset(r.left, r.top + rowH),
          Offset(r.right, r.top + rowH),
          paint,
        );
        canvas.drawLine(
          Offset(r.left, r.top + rowH * 2),
          Offset(r.right, r.top + rowH * 2),
          paint,
        );
      case CameraLayoutMode.off:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LayoutIconPainter oldDelegate) =>
      oldDelegate.mode != mode || oldDelegate.color != color;
}
