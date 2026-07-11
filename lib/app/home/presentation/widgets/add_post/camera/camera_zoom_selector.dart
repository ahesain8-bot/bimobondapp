import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_studio_mode.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_tool_icons.dart';
import 'package:flutter/material.dart';

class CameraZoomSelector extends StatelessWidget {
  const CameraZoomSelector({
    super.key,
    required this.steps,
    required this.selected,
    required this.onSelected,
  });

  final List<CameraZoomStep> steps;
  final double selected;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: steps.map((step) {
          final isSelected = (selected - step.value).abs() < 0.12;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => onSelected(step.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  step.label,
                  style: CameraToolIcons.labelStyle.copyWith(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
