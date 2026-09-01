import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';

/// TikTok Go LIVE tool row:
/// Flip · Enhance · Effects · Settings · More
class ToolsRow extends StatelessWidget {
  const ToolsRow({
    super.key,
    this.onBeautifyTap,
    this.onEffectsTap,
    this.onSettingsTap,
    this.onMoreTap,
  });

  final VoidCallback? onBeautifyTap;
  final VoidCallback? onEffectsTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    final liveBloc = context.read<LiveBloc>();

    final tools = <_ToolSpec>[
      _ToolSpec(
        icon: Icons.cameraswitch_outlined,
        label: 'Flip',
        onTap: () => liveBloc.add(const LiveCameraSwitchRequested()),
      ),
      _ToolSpec(
        icon: Icons.auto_awesome,
        label: 'Enhance',
        onTap: onBeautifyTap,
      ),
      _ToolSpec(
        icon: Icons.face_retouching_natural,
        label: 'Effects',
        onTap: onEffectsTap,
      ),
      _ToolSpec(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: onSettingsTap,
        showDot: true,
      ),
      _ToolSpec(
        icon: Icons.keyboard_arrow_down_rounded,
        label: 'More',
        onTap: onMoreTap,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (final tool in tools) Expanded(child: _ToolCell(tool: tool)),
        ],
      ),
    );
  }
}

class _ToolSpec {
  const _ToolSpec({
    required this.icon,
    required this.label,
    this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showDot;
}

class _ToolCell extends StatelessWidget {
  const _ToolCell({required this.tool});

  final _ToolSpec tool;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tool.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(tool.icon, color: Colors.white, size: 26),
                  ),
                  if (tool.showDot)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFE2C55),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tool.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
