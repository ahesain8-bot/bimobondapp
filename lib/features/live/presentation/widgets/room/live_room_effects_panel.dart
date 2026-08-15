import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../../domain/effects/live_effects_catalog.dart';
import '../../../domain/entities/live_effect.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_effect_thumbnail.dart';

/// Compact tray + expandable grid for live camera effects.
class LiveRoomEffectsPanel extends StatelessWidget {
  const LiveRoomEffectsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) {
        if (previous is! LiveRoomReady || current is! LiveRoomReady) {
          return true;
        }
        return previous.effectsPanelMode != current.effectsPanelMode ||
            previous.selectedEffectId != current.selectedEffectId ||
            previous.effectsCategoryId != current.effectsCategoryId;
      },
      builder: (context, state) {
        if (state is! LiveRoomReady) return const SizedBox.shrink();
        if (state.effectsPanelMode == LiveEffectsPanelMode.hidden) {
          return const SizedBox.shrink();
        }

        final selected = LiveEffectsCatalog.byId(state.selectedEffectId);

        // Bottom inset is already applied by [LiveRoomBottomBar] above.
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ColoredBox(
            color: AppColors.effectsPanel,
            child: state.effectsPanelMode == LiveEffectsPanelMode.expanded
                ? _ExpandedPanel(
                    selected: selected,
                    categoryId: state.effectsCategoryId,
                  )
                : _TrayPanel(selected: selected),
          ),
        );
      },
    );
  }
}

class _TrayPanel extends StatelessWidget {
  const _TrayPanel({required this.selected});

  final LiveEffect selected;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();
    final effects = LiveEffectsCatalog.trayEffects;

    return SizedBox(
      height: AppSizes.effectsTrayHeight,
      child: Row(
        children: [
          IconButton(
            onPressed: () => bloc.add(
              const LiveRoomEffectsPanelModeChanged(LiveEffectsPanelMode.hidden),
            ),
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.effectsTrayHorizontal,
                vertical: AppSpacing.effectsTrayVertical,
              ),
              itemCount: effects.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.effectsThumbGap),
              itemBuilder: (context, index) {
                final effect = effects[index];
                return LiveRoomEffectThumbnail(
                  effect: effect,
                  selected: effect.id == selected.id,
                  onTap: () =>
                      bloc.add(LiveRoomEffectSelected(effect.id)),
                );
              },
            ),
          ),
          IconButton(
            onPressed: () => bloc.add(
              const LiveRoomEffectsPanelModeChanged(
                LiveEffectsPanelMode.expanded,
              ),
            ),
            icon: const Icon(
              Icons.filter_center_focus,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedPanel extends StatelessWidget {
  const _ExpandedPanel({
    required this.selected,
    required this.categoryId,
  });

  final LiveEffect selected;
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<LiveRoomBloc>();
    final height =
        MediaQuery.sizeOf(context).height * AppSizes.effectsExpandedHeightFactor;
    final effects = LiveEffectsCatalog.byCategory(categoryId);

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          _EffectInfoBar(effect: selected),
          const SizedBox(height: AppSpacing.sm),
          _CategoryBar(
            categoryId: categoryId,
            onClose: () => bloc.add(
              const LiveRoomEffectsPanelModeChanged(LiveEffectsPanelMode.tray),
            ),
            onClear: () => bloc.add(
              const LiveRoomEffectSelected('none'),
            ),
            onCategory: (id) =>
                bloc.add(LiveRoomEffectsCategorySelected(id)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: AppSpacing.effectsThumbGap,
                crossAxisSpacing: AppSpacing.effectsThumbGap,
              ),
              itemCount: effects.length,
              itemBuilder: (context, index) {
                final effect = effects[index];
                return LiveRoomEffectThumbnail(
                  effect: effect,
                  selected: effect.id == selected.id,
                  size: AppSizes.effectsGridThumb,
                  onTap: () =>
                      bloc.add(LiveRoomEffectSelected(effect.id)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EffectInfoBar extends StatelessWidget {
  const _EffectInfoBar({required this.effect});

  final LiveEffect effect;

  @override
  Widget build(BuildContext context) {
    final label = effect.isClear
        ? 'اختر مؤثرًا لتطبيقه على البث'
        : 'المؤثر ${effect.nameAr} · BimoBond';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.bookmark_border, color: Colors.white, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.smd,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.effectsInfoPill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.effectsInfo,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categoryId,
    required this.onClose,
    required this.onClear,
    required this.onCategory,
  });

  final String categoryId;
  final VoidCallback onClose;
  final VoidCallback onClear;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          _IconAction(icon: Icons.do_not_disturb_alt, onTap: onClear),
          _IconAction(icon: Icons.search, onTap: () {}),
          _IconAction(icon: Icons.bookmark_border, onTap: () {}),
          _IconAction(icon: Icons.history, onTap: () {}),
          const SizedBox(width: AppSpacing.sm),
          for (final category in LiveEffectsCatalog.categories)
            _CategoryTab(
              label: category.labelAr,
              active: category.id == categoryId,
              onTap: () => onCategory(category.id),
            ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: active
                  ? AppTextStyles.effectsTabActive
                  : AppTextStyles.effectsTab,
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 3,
              width: active ? 22 : 0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
