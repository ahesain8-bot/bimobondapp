import 'package:bimobondapp/app/video_templates/presentation/models/template_editor_models.dart';
import 'package:bimobondapp/app/video_templates/presentation/widgets/editor/template_editor_theme.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Result of the sticker placer — layout for POST …/stickers.
class TemplateEditorStickerDraft {
  const TemplateEditorStickerDraft({
    required this.preset,
    this.positionX = 0,
    this.positionY = 0,
    this.scale = 1,
  });

  final TemplatePresetItem preset;
  final double positionX;
  final double positionY;
  final double scale;
}

/// Full-screen sticker placer: pick sticker, see it on media, drag / pinch / ± size.
class TemplateEditorStickerPlacerSheet extends StatefulWidget {
  const TemplateEditorStickerPlacerSheet({
    super.key,
    required this.presets,
    this.media,
    this.canvasWidth = 1080,
    this.canvasHeight = 1920,
    this.initial,
    this.title = 'Stickers',
  });

  final List<TemplatePresetItem> presets;
  final Widget? media;
  final int canvasWidth;
  final int canvasHeight;
  final TemplateEditorStickerDraft? initial;
  final String title;

  static Future<TemplateEditorStickerDraft?> show(
    BuildContext context, {
    required List<TemplatePresetItem> presets,
    Widget? media,
    int canvasWidth = 1080,
    int canvasHeight = 1920,
    TemplateEditorStickerDraft? initial,
    String title = 'Stickers',
  }) {
    return Navigator.of(context).push<TemplateEditorStickerDraft>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, _, _) => TemplateEditorStickerPlacerSheet(
          presets: presets,
          media: media,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
          initial: initial,
          title: title,
        ),
      ),
    );
  }

  @override
  State<TemplateEditorStickerPlacerSheet> createState() =>
      _TemplateEditorStickerPlacerSheetState();
}

class _TemplateEditorStickerPlacerSheetState
    extends State<TemplateEditorStickerPlacerSheet> {
  TemplatePresetItem? _selected;
  late double _positionX;
  late double _positionY;
  late double _scale;
  double _baseScale = 1;

  int get _cw => widget.canvasWidth > 0 ? widget.canvasWidth : 1080;
  int get _ch => widget.canvasHeight > 0 ? widget.canvasHeight : 1920;
  double get _halfW => _cw / 2.0;
  double get _halfH => _ch / 2.0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _selected = initial.preset;
      _positionX = initial.positionX;
      _positionY = initial.positionY;
      _scale = initial.scale;
      _baseScale = initial.scale;
    } else {
      _positionX = 0;
      _positionY = 0;
      _scale = 1;
      _baseScale = 1;
    }
  }

  void _pickPreset(TemplatePresetItem preset) {
    setState(() {
      _selected = preset;
      if (widget.initial == null) {
        _positionX = 0;
        _positionY = 0;
        _scale = 1;
        _baseScale = 1;
      }
    });
  }

  void _submit() {
    final preset = _selected;
    if (preset == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(
      context,
      TemplateEditorStickerDraft(
        preset: preset,
        positionX: _positionX.clamp(-_halfW + 40, _halfW - 40),
        positionY: _positionY.clamp(-_halfH + 40, _halfH - 40),
        scale: _scale.clamp(0.35, 3.5),
      ),
    );
  }

  void _bumpScale(double delta) {
    setState(() => _scale = (_scale + delta).clamp(0.35, 3.5));
  }

  void _onScaleStart(ScaleStartDetails _) {
    _baseScale = _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size previewSize) {
    if (_selected == null || previewSize.width <= 0) return;
    final scaleX = _cw / previewSize.width;
    final scaleY = _ch / previewSize.height;
    setState(() {
      if (details.pointerCount >= 2 || (details.scale - 1.0).abs() > 0.015) {
        _scale = (_baseScale * details.scale).clamp(0.35, 3.5);
      }
      _positionX = (_positionX + details.focalPointDelta.dx * scaleX)
          .clamp(-_halfW + 40, _halfW - 40);
      _positionY = (_positionY + details.focalPointDelta.dy * scaleY)
          .clamp(-_halfH + 40, _halfH - 40);
    });
  }

  Widget _stickerVisual(double previewWidth) {
    final preset = _selected;
    if (preset == null) {
      return Text(
        'Pick a sticker below',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final pxScale = previewWidth / _cw;
    final box = (96 * _scale * pxScale).clamp(32.0, previewWidth * 0.55);
    final url = preset.assetUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return SizedBox(
        width: box,
        height: box,
        child: SafeNetworkImage(imageUrl: url, fit: BoxFit.contain),
      );
    }
    return Text(
      preset.name,
      style: TextStyle(fontSize: box * 0.72),
    );
  }

  Widget _buildStage() {
    final aspect = _cw / _ch;
    return LayoutBuilder(
      builder: (context, constraints) {
        var w = constraints.maxWidth;
        var h = w / aspect;
        if (h > constraints.maxHeight) {
          h = constraints.maxHeight;
          w = h * aspect;
        }
        final previewSize = Size(w, h);
        final cx = w / 2 + _positionX * (w / _cw);
        final cy = h / 2 + _positionY * (h / _ch);

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF111111)),
                  if (widget.media != null)
                    Positioned.fill(child: widget.media!),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: (d) => _onScaleUpdate(d, previewSize),
                    ),
                  ),
                  if (_selected != null)
                    Positioned(
                      left: cx,
                      top: cy,
                      child: IgnorePointer(
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: _stickerVisual(w),
                        ),
                      ),
                    )
                  else
                    Center(child: IgnorePointer(child: _stickerVisual(w))),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: IgnorePointer(
                      child: Text(
                        _selected == null
                            ? 'Tap a sticker below'
                            : 'Drag to move · Pinch or ± to resize',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemplateEditorTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selected == null ? null : _submit,
                    child: Text(
                      'Apply',
                      style: TextStyle(
                        color: _selected == null
                            ? Colors.white38
                            : TemplateEditorTheme.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildStage()),
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ScaleChip(
                      icon: LucideIcons.minus,
                      onTap: () => _bumpScale(-0.12),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${(_scale * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _ScaleChip(
                      icon: LucideIcons.plus,
                      onTap: () => _bumpScale(0.12),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: widget.presets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final preset = widget.presets[i];
                  final selected = _selected?.id == preset.id;
                  return GestureDetector(
                    onTap: () => _pickPreset(preset),
                    child: Container(
                      width: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white12,
                          width: selected ? 2.5 : 1,
                        ),
                        color: TemplateEditorTheme.panelElevated,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: preset.assetUrl != null &&
                              preset.assetUrl!.trim().isNotEmpty
                          ? SafeNetworkImage(
                              imageUrl: preset.assetUrl,
                              fit: BoxFit.contain,
                            )
                          : Center(
                              child: Text(
                                preset.name,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScaleChip extends StatelessWidget {
  const _ScaleChip({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white12,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
