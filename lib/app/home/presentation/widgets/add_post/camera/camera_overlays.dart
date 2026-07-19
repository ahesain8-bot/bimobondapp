import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_asset_loader.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_tool_icons.dart';
import 'package:flutter/material.dart';

class CameraEffectChip extends StatelessWidget {
  const CameraEffectChip({
    super.key,
    required this.effect,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final CameraEffectDefinition effect;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 66 : 60,
            height: selected ? 66 : 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.white24,
                width: selected ? 2.5 : 1,
              ),
              gradient: RadialGradient(
                colors: [
                  effect.previewColor.withValues(alpha: 0.85),
                  effect.previewColor.withValues(alpha: 0.35),
                ],
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: _EffectChipIcon(effect: effect),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: CameraToolIcons.labelStyle.copyWith(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EffectChipIcon extends StatelessWidget {
  const _EffectChipIcon({required this.effect});

  final CameraEffectDefinition effect;

  @override
  Widget build(BuildContext context) {
    if (effect.isNone) {
      return const Icon(Icons.block, color: Colors.white54, size: 22);
    }

    if (effect.hasAsset) {
      return CameraEffectAssetLoader.preview(
        raw: effect.assetUrl,
        emojiFallback: effect.emoji,
        size: 64,
      );
    }

    return _EmojiFallback(effect: effect);
  }
}

class _EmojiFallback extends StatelessWidget {
  const _EmojiFallback({required this.effect});

  final CameraEffectDefinition effect;

  @override
  Widget build(BuildContext context) {
    return Text(
      effect.emoji,
      style: const TextStyle(fontSize: 28),
    );
  }
}

class CameraEffectsPickerStrip extends StatelessWidget {
  const CameraEffectsPickerStrip({
    super.key,
    required this.effects,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<CameraEffectDefinition> effects;
  final String? selected;
  final String Function(CameraEffectDefinition effect) labelBuilder;
  final ValueChanged<CameraEffectDefinition> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: effects.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final effect = effects[index];
          return CameraEffectChip(
            effect: effect,
            label: labelBuilder(effect),
            selected: selected == effect.slug,
            onTap: () => onSelected(effect),
          );
        },
      ),
    );
  }
}

class CameraCountdownOverlay extends StatelessWidget {
  const CameraCountdownOverlay({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 96,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class CameraRecordingBadge extends StatelessWidget {
  const CameraRecordingBadge({
    super.key,
    required this.label,
    required this.topPadding,
    this.onTap,
  });

  final String label;
  final double topPadding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topPadding + 16,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFE2C55),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: CameraToolIcons.labelStyle.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FrontScreenFlashOverlay extends StatelessWidget {
  const FrontScreenFlashOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(
        painter: _FrontFlashVignettePainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _FrontFlashVignettePainter extends CustomPainter {
  const _FrontFlashVignettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.42;
    final rx = size.width * 0.62;
    final ry = size.height * 0.48;

    canvas.saveLayer(Offset.zero & size, Paint());

    final rim = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (cx / size.width) * 2 - 1,
          (cy / size.height) * 2 - 1,
        ),
        radius: 1.35,
        colors: const [
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
          Color(0x55FFFFFF),
          Color(0xCCFFFFFF),
          Color(0xFFFFFFFF),
        ],
        stops: const [0.0, 0.36, 0.58, 0.82, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, rim);

    final hole = Paint()
      ..blendMode = BlendMode.dstOut
      ..shader = RadialGradient(
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, cy),
        width: rx * 2,
        height: ry * 2,
      ));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      hole,
    );

    canvas.restore();

    final topH = size.height * 0.16;
    final bottomH = size.height * 0.2;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, topH),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xF2FFFFFF),
            Color(0x00FFFFFF),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, topH)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - bottomH, size.width, bottomH),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: const [
            Color(0xF2FFFFFF),
            Color(0x00FFFFFF),
          ],
        ).createShader(
          Rect.fromLTWH(0, size.height - bottomH, size.width, bottomH),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
