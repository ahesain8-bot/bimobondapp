import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_assets.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';
import 'tool_button.dart';

/// Tools row: expand/collapse toggle, primary tools and optional share row.
class ToolsRow extends StatelessWidget {
  const ToolsRow({
    super.key,
    this.onBeautifyTap,
    this.onEffectsTap,
    this.onSettingsTap,
    this.onServiceTap,
    this.onFansTap,
    this.onShareTap,
    this.onInteractionTap,
  });

  final VoidCallback? onBeautifyTap;
  final VoidCallback? onEffectsTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onServiceTap;
  final VoidCallback? onFansTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onInteractionTap;

  @override
  Widget build(BuildContext context) {
    final liveBloc = context.read<LiveBloc>();

    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.only(
          left: AppSpacing.xxxl,
          right: AppSpacing.xxxl,
          top: AppSpacing.toolsRowVertical,
          bottom: AppSpacing.toolsRowVertical,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Expand / collapse toggle.
            BlocBuilder<LiveBloc, LiveState>(
              buildWhen: (previous, current) =>
                  _expandedOf(previous) != _expandedOf(current),
              builder: (context, state) {
                final isExpanded = _expandedOf(state);
                return GestureDetector(
                  onTap: () =>
                      liveBloc.add(const LiveToolsToggleRequested()),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.toolsToggleGap),
                    child: Image.asset(
                      isExpanded
                          ? AppAssets.toolsExpanded
                          : AppAssets.toolsCollapsed,
                      width: AppSizes.toggleArrow,
                      height: AppSizes.toggleArrow,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            // Primary tools.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ToolButton(
                  asset: AppAssets.service,
                  label: 'Services+',
                  onTap: onServiceTap,
                ),
                ToolButton(
                  asset: AppAssets.settings,
                  label: 'الإعدادات',
                  onTap: onSettingsTap,
                ),
                ToolButton(
                  asset: AppAssets.guests,
                  label: 'المؤثرات',
                  onTap: onEffectsTap,
                ),
                ToolButton(
                  asset: AppAssets.edit,
                  label: 'تجميل',
                  onTap: onBeautifyTap,
                ),
                ToolButton(asset: AppAssets.heart,label: 'قلب',onTap: () => liveBloc.add(const LiveCameraSwitchRequested()),),
              ],
            ),
            // Secondary tools are visible only while the tools panel is expanded.
            BlocBuilder<LiveBloc, LiveState>(
              buildWhen: (previous, current) =>
                  _expandedOf(previous) != _expandedOf(current),
              builder: (_, state) {
                if (!_expandedOf(state)) return const SizedBox.shrink();

                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ToolButton(
                      asset: AppAssets.share,
                      label: 'مشاركة',
                      onTap: onShareTap,
                    ),
                    ToolButton(
                      asset: AppAssets.interaction,
                      label: 'تفاعل',
                      onTap: onInteractionTap,
                    ),
                    ToolButton(
                      asset: AppAssets.followHosts,
                      label: 'مجتمع المعجبين',
                      onTap: onFansTap,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _expandedOf(LiveState state) {
    return state is LiveReady ? state.isToolsExpanded : true;
  }
}
