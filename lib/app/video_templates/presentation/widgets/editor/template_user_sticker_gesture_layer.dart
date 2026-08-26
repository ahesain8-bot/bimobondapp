import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:flutter/material.dart';

/// Drag / pinch resize for user stickers on the main editor preview.
class TemplateUserStickerGestureLayer extends StatelessWidget {
  const TemplateUserStickerGestureLayer({
    super.key,
    required this.stickers,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onChanged,
    this.onInteractionStart,
  });

  final List<UserEditorStickerOverlay> stickers;
  final int canvasWidth;
  final int canvasHeight;
  final ValueChanged<UserEditorStickerOverlay> onChanged;
  final VoidCallback? onInteractionStart;

  @override
  Widget build(BuildContext context) {
    if (stickers.isEmpty) return const SizedBox.shrink();
    final cw = canvasWidth > 0 ? canvasWidth : 1080;
    final ch = canvasHeight > 0 ? canvasHeight : 1920;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final sticker in stickers)
              _DraggableStickerHit(
                overlay: sticker,
                previewSize: Size(w, h),
                canvasWidth: cw,
                canvasHeight: ch,
                onChanged: onChanged,
                onInteractionStart: onInteractionStart,
              ),
          ],
        );
      },
    );
  }
}

class _DraggableStickerHit extends StatefulWidget {
  const _DraggableStickerHit({
    required this.overlay,
    required this.previewSize,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onChanged,
    this.onInteractionStart,
  });

  final UserEditorStickerOverlay overlay;
  final Size previewSize;
  final int canvasWidth;
  final int canvasHeight;
  final ValueChanged<UserEditorStickerOverlay> onChanged;
  final VoidCallback? onInteractionStart;

  @override
  State<_DraggableStickerHit> createState() => _DraggableStickerHitState();
}

class _DraggableStickerHitState extends State<_DraggableStickerHit> {
  late double _x;
  late double _y;
  late double _scale;
  double _baseScale = 1;

  static const _baseCanvasPx = 96.0;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _DraggableStickerHit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overlay.id != widget.overlay.id ||
        oldWidget.overlay.positionX != widget.overlay.positionX ||
        oldWidget.overlay.positionY != widget.overlay.positionY ||
        oldWidget.overlay.scale != widget.overlay.scale) {
      _sync();
    }
  }

  void _sync() {
    _x = widget.overlay.positionX;
    _y = widget.overlay.positionY;
    _scale = widget.overlay.scale;
  }

  void _emit() {
    widget.onChanged(
      widget.overlay.copyWith(
        positionX: _x,
        positionY: _y,
        scale: _scale,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.previewSize.width;
    final h = widget.previewSize.height;
    final cw = widget.canvasWidth.toDouble();
    final ch = widget.canvasHeight.toDouble();
    final halfW = cw / 2;
    final halfH = ch / 2;
    final pxScale = w / cw;
    final hitSize =
        (_baseCanvasPx * _scale * pxScale).clamp(48.0, w * 0.55);
    final cx = w / 2 + _x * (w / cw);
    final cy = h / 2 + _y * (h / ch);

    return Positioned(
      left: cx - hitSize / 2,
      top: cy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) {
          _baseScale = _scale;
          widget.onInteractionStart?.call();
        },
        onScaleUpdate: (details) {
          final scaleX = cw / w;
          final scaleY = ch / h;
          setState(() {
            if (details.pointerCount >= 2 ||
                (details.scale - 1.0).abs() > 0.015) {
              _scale = (_baseScale * details.scale).clamp(0.35, 3.5);
            }
            _x = (_x + details.focalPointDelta.dx * scaleX)
                .clamp(-halfW + 40, halfW - 40);
            _y = (_y + details.focalPointDelta.dy * scaleY)
                .clamp(-halfH + 40, halfH - 40);
          });
          _emit();
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}
