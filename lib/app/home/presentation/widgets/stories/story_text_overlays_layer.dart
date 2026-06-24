import 'package:bimobondapp/app/home/presentation/widgets/stories/story_text_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_text_style.dart';
import 'package:flutter/material.dart';

typedef StoryOverlayChanged = void Function(StoryTextOverlay overlay);

class StoryTextOverlaysLayer extends StatelessWidget {
  const StoryTextOverlaysLayer({
    required this.overlays,
    this.selectedId,
    this.editable = false,
    this.onSelect,
    this.onChanged,
    this.textControllers = const {},
    super.key,
  });

  final List<StoryTextOverlay> overlays;
  final String? selectedId;
  final bool editable;
  final ValueChanged<String>? onSelect;
  final StoryOverlayChanged? onChanged;
  final Map<String, TextEditingController> textControllers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            for (final overlay in overlays)
              _StoryTextSticker(
                key: ValueKey(overlay.id),
                overlay: overlay,
                isSelected: selectedId == overlay.id,
                editable: editable,
                onSelect: onSelect,
                onChanged: onChanged,
                controller: textControllers[overlay.id],
                stackSize: stackSize,
              ),
          ],
        );
      },
    );
  }
}

class _StoryTextSticker extends StatefulWidget {
  const _StoryTextSticker({
    required this.overlay,
    required this.isSelected,
    required this.editable,
    required this.stackSize,
    super.key,
    this.onSelect,
    this.onChanged,
    this.controller,
  });

  final StoryTextOverlay overlay;
  final bool isSelected;
  final bool editable;
  final Size stackSize;
  final ValueChanged<String>? onSelect;
  final StoryOverlayChanged? onChanged;
  final TextEditingController? controller;

  @override
  State<_StoryTextSticker> createState() => _StoryTextStickerState();
}

class _StoryTextStickerState extends State<_StoryTextSticker> {
  double _baseScale = 1;
  double _baseRotation = 0;

  StoryTextOverlay get overlay => widget.overlay;

  Alignment get _alignment => Alignment(
        overlay.x * 2 - 1,
        overlay.y * 2 - 1,
      );

  TextStyle _textStyle() {
    return StoryTextStyleKit.resolve(
      fontStyle: overlay.fontStyle,
      textColor: overlay.displayTextColor,
      scale: overlay.scale,
      withShadow: overlay.backgroundMode == StoryTextBackgroundMode.none,
    );
  }

  Widget _buildTextContent() {
    if (widget.editable && widget.isSelected && widget.controller != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.stackSize.width * 0.88),
        child: Material(
          type: MaterialType.transparency,
          child: TextField(
            controller: widget.controller,
            autofocus: true,
            style: _textStyle(),
            textAlign: overlay.alignment.textAlign,
            maxLines: null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) =>
                widget.onChanged?.call(overlay.copyWith(text: value)),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.stackSize.width * 0.88),
      child: Text(
        overlay.text,
        textAlign: overlay.alignment.textAlign,
        style: _textStyle(),
      ),
    );
  }

  Widget _wrapBackground(Widget child) {
    return switch (overlay.backgroundMode) {
      StoryTextBackgroundMode.none => child,
      StoryTextBackgroundMode.translucent => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: overlay.backgroundColor.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      StoryTextBackgroundMode.solid => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: overlay.backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
    };
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = overlay.scale;
    _baseRotation = overlay.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.editable) return;

    final dx = details.focalPointDelta.dx / widget.stackSize.width;
    final dy = details.focalPointDelta.dy / widget.stackSize.height;

    widget.onChanged?.call(
      overlay.copyWith(
        x: (overlay.x + dx).clamp(0.04, 0.96),
        y: (overlay.y + dy).clamp(0.06, 0.94),
        scale: (_baseScale * details.scale).clamp(0.45, 3.5),
        rotation: _baseRotation + details.rotation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sticker = _wrapBackground(_buildTextContent());

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.editable && !widget.isSelected
            ? () => widget.onSelect?.call(overlay.id)
            : null,
        child: Align(
          alignment: _alignment,
          child: GestureDetector(
            onTap: widget.editable
                ? () => widget.onSelect?.call(overlay.id)
                : null,
            onScaleStart: widget.editable ? _onScaleStart : null,
            onScaleUpdate: widget.editable ? _onScaleUpdate : null,
            child: Transform.rotate(
              angle: overlay.rotation,
              child: DecoratedBox(
                decoration: widget.editable && widget.isSelected
                    ? BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : const BoxDecoration(),
                child: Padding(
                  padding: widget.editable && widget.isSelected
                      ? const EdgeInsets.all(4)
                      : EdgeInsets.zero,
                  child: sticker,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
