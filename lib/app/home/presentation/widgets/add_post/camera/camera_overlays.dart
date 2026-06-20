import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.redAccent : Colors.white24,
                width: selected ? 2.5 : 1,
              ),
              gradient: RadialGradient(
                colors: [
                  effect.previewColor.withValues(alpha: 0.85),
                  effect.previewColor.withValues(alpha: 0.35),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              effect.emoji,
              style: TextStyle(
                fontSize: effect.isNone ? 20 : 28,
                color: effect.isNone ? Colors.white54 : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
  final CameraEffectId? selected;
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
            selected: selected == effect.id,
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
  });

  final String label;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topPadding + 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
