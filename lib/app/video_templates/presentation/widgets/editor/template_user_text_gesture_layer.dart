import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:flutter/material.dart';

/// Invisible hit targets over user captions so they can be dragged / pinched
/// on the main editor preview after Apply.
class TemplateUserTextGestureLayer extends StatelessWidget {
  const TemplateUserTextGestureLayer({
    super.key,
    required this.texts,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onChanged,
    this.onInteractionStart,
  });

  final List<UserEditorTextOverlay> texts;
  final int canvasWidth;
  final int canvasHeight;
  final ValueChanged<UserEditorTextOverlay> onChanged;
  final VoidCallback? onInteractionStart;

  @override
  Widget build(BuildContext context) {
    if (texts.isEmpty) return const SizedBox.shrink();
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
            for (final text in texts)
              _DraggableCaptionHit(
                overlay: text,
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

class _DraggableCaptionHit extends StatefulWidget {
  const _DraggableCaptionHit({
    required this.overlay,
    required this.previewSize,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onChanged,
    this.onInteractionStart,
  });

  final UserEditorTextOverlay overlay;
  final Size previewSize;
  final int canvasWidth;
  final int canvasHeight;
  final ValueChanged<UserEditorTextOverlay> onChanged;
  final VoidCallback? onInteractionStart;

  @override
  State<_DraggableCaptionHit> createState() => _DraggableCaptionHitState();
}

class _DraggableCaptionHitState extends State<_DraggableCaptionHit> {
  late double _x;
  late double _y;
  late double _fontSize;
  double _baseFont = 48;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _DraggableCaptionHit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overlay.id != widget.overlay.id ||
        oldWidget.overlay.positionX != widget.overlay.positionX ||
        oldWidget.overlay.positionY != widget.overlay.positionY ||
        oldWidget.overlay.fontSize != widget.overlay.fontSize) {
      _sync();
    }
  }

  void _sync() {
    _x = widget.overlay.positionX;
    _y = widget.overlay.positionY;
    _fontSize = widget.overlay.fontSize;
  }

  void _emit() {
    widget.onChanged(
      widget.overlay.copyWith(
        positionX: _x,
        positionY: _y,
        fontSize: _fontSize,
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
    final scale = w / cw;
    final displayFont = (_fontSize * scale).clamp(10.0, 96.0);
    final hitW = (w * 0.7).clamp(120.0, w);
    final hitH = (displayFont * 2.4).clamp(48.0, h * 0.35);
    final cx = w / 2 + _x * (w / cw);
    final cy = h / 2 + _y * (h / ch);

    return Positioned(
      left: cx - hitW / 2,
      top: cy - hitH / 2,
      width: hitW,
      height: hitH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (_) {
          _baseFont = _fontSize;
          widget.onInteractionStart?.call();
        },
        onScaleUpdate: (details) {
          final scaleX = cw / w;
          final scaleY = ch / h;
          setState(() {
            if (details.pointerCount >= 2 ||
                (details.scale - 1.0).abs() > 0.015) {
              _fontSize = (_baseFont * details.scale).clamp(12.0, 120.0);
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
