import 'dart:ui';

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:flutter/material.dart';

class CameraSpeedPickerPopup extends StatelessWidget {
  const CameraSpeedPickerPopup({
    super.key,
    required this.selectedSpeed,
    required this.onSelected,
    this.options = CameraStudioConstants.speedOptions,
  });

  final double selectedSpeed;
  final ValueChanged<double> onSelected;
  final List<double> options;

  @override
  Widget build(BuildContext context) {
    final ordered = [...options]..sort((a, b) => b.compareTo(a));

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF5A5A5A).withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final speed in ordered)
                  _SpeedOptionTile(
                    label: _labelFor(speed),
                    selected: (speed - selectedSpeed).abs() < 0.001,
                    onTap: () => onSelected(speed),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _labelFor(double speed) {
    if (speed == speed.roundToDouble()) {
      return '${speed.toInt()}x';
    }
    final text = speed.toStringAsFixed(1);
    return '${text.endsWith('.0') ? speed.toInt() : text}x';
  }
}

class _SpeedOptionTile extends StatelessWidget {
  const _SpeedOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: selected ? Colors.white : Colors.transparent,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
