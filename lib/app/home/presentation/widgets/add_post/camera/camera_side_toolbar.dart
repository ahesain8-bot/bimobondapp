import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CameraSideToolbarLabels {
  const CameraSideToolbarLabels({
    required this.flip,
    required this.flash,
    required this.speed,
    required this.beauty,
    required this.filters,
    required this.timer,
    required this.music,
  });

  final String flip;
  final String flash;
  final String speed;
  final String beauty;
  final String filters;
  final String timer;
  final String music;
}

class CameraSideToolbar extends StatelessWidget {
  const CameraSideToolbar({
    super.key,
    required this.onFlip,
    required this.onFlash,
    required this.onSpeed,
    required this.onBeauty,
    required this.onFilters,
    required this.onTimer,
    required this.onMusic,
    required this.beautyEnabled,
    required this.filtersEnabled,
    required this.timerEnabled,
    required this.speedLabel,
    required this.labels,
  });

  final VoidCallback onFlip;
  final VoidCallback onFlash;
  final VoidCallback onSpeed;
  final VoidCallback onBeauty;
  final VoidCallback onFilters;
  final VoidCallback onTimer;
  final VoidCallback onMusic;
  final bool beautyEnabled;
  final bool filtersEnabled;
  final bool timerEnabled;
  final String speedLabel;
  final CameraSideToolbarLabels labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CameraSideTool(
          icon: LucideIcons.switchCamera,
          label: labels.flip,
          onTap: onFlip,
        ),
        CameraSideTool(
          icon: LucideIcons.zap,
          label: labels.flash,
          onTap: onFlash,
        ),
        CameraSideTool(
          icon: LucideIcons.gauge,
          label: speedLabel,
          caption: labels.speed,
          onTap: onSpeed,
        ),
        CameraSideTool(
          icon: LucideIcons.sparkles,
          label: labels.beauty,
          onTap: onBeauty,
          active: beautyEnabled,
        ),
        CameraSideTool(
          icon: LucideIcons.palette,
          label: labels.filters,
          onTap: onFilters,
          active: filtersEnabled,
        ),
        CameraSideTool(
          icon: LucideIcons.timer,
          label: labels.timer,
          onTap: onTimer,
          active: timerEnabled,
        ),
        CameraSideTool(
          icon: LucideIcons.music,
          label: labels.music,
          onTap: onMusic,
        ),
      ],
    );
  }
}

class CameraSideTool extends StatelessWidget {
  const CameraSideTool({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              caption ?? label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
