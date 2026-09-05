import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';

/// TikTok Go LIVE tool chrome.
///
/// Collapsed: Flip · Enhance · Effects · Settings · More
/// Expanded (More): full 3×5 grid ending with Less.
class ToolsRow extends StatelessWidget {
  const ToolsRow({
    super.key,
    this.expanded = false,
    this.onExpandedChanged,
    this.onBeautifyTap,
    this.onEffectsTap,
    this.onSettingsTap,
    this.onShareTap,
    this.onLiveCenterTap,
    this.onCampaignsTap,
    this.onSubscriptionTap,
    this.onServicePlusTap,
    this.onShopTap,
    this.onInteractTap,
    this.onPromoteTap,
    this.onBoardsTap,
    this.onDualTap,
  });

  final bool expanded;
  final ValueChanged<bool>? onExpandedChanged;
  final VoidCallback? onBeautifyTap;
  final VoidCallback? onEffectsTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onLiveCenterTap;
  final VoidCallback? onCampaignsTap;
  final VoidCallback? onSubscriptionTap;
  final VoidCallback? onServicePlusTap;
  final VoidCallback? onShopTap;
  final VoidCallback? onInteractTap;
  final VoidCallback? onPromoteTap;
  final VoidCallback? onBoardsTap;
  final VoidCallback? onDualTap;

  @override
  Widget build(BuildContext context) {
    final liveBloc = context.read<LiveBloc>();

    void flip() => liveBloc.add(const LiveCameraSwitchRequested());

    if (!expanded) {
      return _ToolGrid(
        rows: [
          [
            _ToolSpec(
              icon: Icons.cameraswitch_outlined,
              label: 'Flip',
              onTap: flip,
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
              onTap: () => onExpandedChanged?.call(true),
            ),
          ],
        ],
      );
    }

    return _ToolGrid(
      rows: [
        [
          _ToolSpec(
            icon: Icons.cameraswitch_outlined,
            label: 'Flip',
            onTap: flip,
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
            icon: Icons.keyboard_arrow_up_rounded,
            label: 'Less',
            onTap: () => onExpandedChanged?.call(false),
          ),
        ],
        [
          _ToolSpec(
            icon: Icons.dashboard_outlined,
            label: 'Boards',
            onTap: onBoardsTap,
          ),
          _ToolSpec(
            icon: Icons.photo_camera_back_outlined,
            label: 'Dual',
            onTap: onDualTap,
          ),
          _ToolSpec(
            icon: Icons.ios_share_rounded,
            label: 'Share',
            onTap: onShareTap,
          ),
          _ToolSpec(
            icon: Icons.home_outlined,
            label: 'LIVE Center',
            onTap: onLiveCenterTap,
          ),
          _ToolSpec(
            icon: Icons.verified_outlined,
            label: 'Campaigns',
            onTap: onCampaignsTap,
            badge: '2',
          ),
        ],
        [
          _ToolSpec(
            icon: Icons.star_border_rounded,
            label: 'Subscription',
            onTap: onSubscriptionTap,
          ),
          _ToolSpec(
            icon: Icons.support_agent_outlined,
            label: 'Service+',
            onTap: onServicePlusTap,
          ),
          _ToolSpec(
            icon: Icons.shopping_bag_outlined,
            label: 'Shop',
            onTap: onShopTap,
          ),
          _ToolSpec(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Interact',
            onTap: onInteractTap,
          ),
          _ToolSpec(
            icon: Icons.local_fire_department_outlined,
            label: AppLocalizations.of(context)!.lpTitle,
            onTap: onPromoteTap,
          ),
        ],
      ],
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.rows});

  final List<List<_ToolSpec>> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                for (final tool in rows[i])
                  Expanded(child: _ToolCell(tool: tool)),
              ],
            ),
          ],
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
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showDot;
  final String? badge;
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
                  Center(child: Icon(tool.icon, color: Colors.white, size: 26)),
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
                  if (tool.badge != null)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFE2C55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tool.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
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
