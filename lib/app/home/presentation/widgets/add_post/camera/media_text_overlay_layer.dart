import 'package:bimobondapp/app/home/presentation/utils/media_text_font_styles.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_layout.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_text_overlay.dart';
import 'package:flutter/material.dart';

/// Renders draggable text stickers over the media preview.
///
/// [MediaTextOverlay.center] is image-normalized (0..1 of media pixels). This
/// layer maps that through [fit] so stickers stay locked to image content when
/// the preview letterboxes, filters refresh, or the container size changes.
class MediaTextOverlayLayer extends StatefulWidget {
  const MediaTextOverlayLayer({
    super.key,
    required this.overlays,
    required this.onChanged,
    required this.onEdit,
    this.mediaSize = Size.zero,
    this.fit = BoxFit.contain,
  });

  final List<MediaTextOverlay> overlays;
  final ValueChanged<MediaTextOverlay> onChanged;
  final ValueChanged<MediaTextOverlay> onEdit;
  final Size mediaSize;
  final BoxFit fit;

  @override
  State<MediaTextOverlayLayer> createState() => _MediaTextOverlayLayerState();
}

class _MediaTextOverlayLayerState extends State<MediaTextOverlayLayer> {
  final Map<String, Offset> _centers = {};
  final Set<String> _dragging = {};

  bool get _hasMediaSize =>
      widget.mediaSize.width > 0 && widget.mediaSize.height > 0;

  @override
  void initState() {
    super.initState();
    _syncFromParent();
  }

  @override
  void didUpdateWidget(MediaTextOverlayLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromParent();
  }

  void _syncFromParent() {
    final ids = widget.overlays.map((o) => o.id).toSet();
    _centers.removeWhere((id, _) => !ids.contains(id));
    for (final overlay in widget.overlays) {
      if (!_dragging.contains(overlay.id)) {
        _centers[overlay.id] = overlay.center;
      }
    }
  }

  Offset _centerFor(MediaTextOverlay overlay) =>
      _centers[overlay.id] ?? overlay.center;

  Offset _displayNorm(Offset imageNorm, Size container) {
    if (!_hasMediaSize) return imageNorm;
    return MediaTextLayout.toContainer(
      imageNorm,
      widget.mediaSize,
      container,
      widget.fit,
    );
  }

  void _onPanStart(MediaTextOverlay overlay) {
    _dragging.add(overlay.id);
    _centers[overlay.id] = overlay.center;
  }

  void _onPanUpdate(
    MediaTextOverlay overlay,
    DragUpdateDetails details,
    double w,
    double h,
  ) {
    if (w <= 0 || h <= 0) return;
    final container = Size(w, h);
    final currentImage = _centerFor(overlay);
    final currentDisplay = _displayNorm(currentImage, container);
    final nextDisplay = Offset(
      (currentDisplay.dx + details.delta.dx / w).clamp(0.0, 1.0),
      (currentDisplay.dy + details.delta.dy / h).clamp(0.0, 1.0),
    );
    _centers[overlay.id] = _hasMediaSize
        ? MediaTextLayout.toImage(
            nextDisplay,
            widget.mediaSize,
            container,
            widget.fit,
          )
        : nextDisplay;
    setState(() {});
  }

  void _onPanEnd(MediaTextOverlay overlay) {
    _dragging.remove(overlay.id);
    final center = _centers[overlay.id];
    if (center != null && center != overlay.center) {
      widget.onChanged(overlay.copyWith(center: center));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.overlays.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final container = Size(w, h);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final overlay in widget.overlays)
              Align(
                key: ValueKey(overlay.id),
                alignment: Alignment(
                  (_displayNorm(_centerFor(overlay), container).dx * 2) - 1,
                  (_displayNorm(_centerFor(overlay), container).dy * 2) - 1,
                ),
                child: RepaintBoundary(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => widget.onEdit(overlay),
                    onPanStart: (_) => _onPanStart(overlay),
                    onPanUpdate: (d) => _onPanUpdate(overlay, d, w, h),
                    onPanEnd: (_) => _onPanEnd(overlay),
                    onPanCancel: () => _onPanEnd(overlay),
                    child: _OverlayText(
                      overlay: overlay,
                      maxWidth: w * 0.9,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OverlayText extends StatelessWidget {
  const _OverlayText({required this.overlay, required this.maxWidth});

  final MediaTextOverlay overlay;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final look = overlay.look;
    final bg =
        look == MediaTextLook.background ? overlay.resolvedBackground : null;
    final textColor = overlay.resolvedTextColor;
    final fillStyle = MediaTextFontStyles.byId(overlay.fontStyleId).resolve(
      color: textColor,
      fontSize: overlay.fontSize,
      decoration: overlay.textDecoration,
      shadows: look == MediaTextLook.none
          ? const [
              Shadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ]
          : null,
    );

    Widget textWidget;
    if (look == MediaTextLook.outline) {
      final strokeStyle = fillStyle.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.white,
        shadows: null,
      );
      textWidget = Stack(
        alignment: Alignment.center,
        children: [
          Text(overlay.text, textAlign: overlay.textAlign, style: strokeStyle),
          Text(overlay.text, textAlign: overlay.textAlign, style: fillStyle),
        ],
      );
    } else {
      textWidget = Text(
        overlay.text,
        textAlign: overlay.textAlign,
        style: fillStyle,
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: bg != null
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
          : EdgeInsets.zero,
      decoration: bg != null
          ? BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8))
          : null,
      child: textWidget,
    );
  }
}
