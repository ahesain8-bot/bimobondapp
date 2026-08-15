import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';

/// Bottom tabs: LIVE / الإبداع / منشور.
class BottomTabs extends StatelessWidget {
  const BottomTabs({super.key});

  static const List<({String label, int index})> _tabs = [
    (label: 'الإبداع', index: 1),
    (label: 'منشور', index: 0),
  ];
  static const double _tabWidth = 48;
  static const double _tabGap = AppSpacing.xxs;
  static const Duration _animationDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final liveBloc = context.read<LiveBloc>();

    return BlocBuilder<LiveBloc, LiveState>(
      buildWhen: (previous, current) => _indexOf(previous) != _indexOf(current),
      builder: (context, state) {
        final selectedIndex = _indexOf(state);
        final selectedPosition = _selectedPosition(selectedIndex);

        return Container(
          width: double.infinity,
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final centerLeft = (constraints.maxWidth - _tabWidth) / 2;
              final step = _tabWidth + _tabGap;

              return SizedBox(
                height: 28,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: _tabs.map((tab) {
                    final isActive = selectedIndex == tab.index;
                    final tabPosition = _tabs.indexWhere(
                      (item) => item.index == tab.index,
                    );
                    final position = tabPosition - selectedPosition;

                    return AnimatedPositioned(
                      key: ValueKey(tab.index),
                      duration: _animationDuration,
                      curve: Curves.easeInOutCubic,
                      left: centerLeft + (position * step),
                      top: 0,
                      width: _tabWidth,
                      height: 28,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => liveBloc.add(LiveTabChanged(tab.index)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tab.label,
                              style: isActive
                                  ? AppTextStyles.tabActive
                                  : AppTextStyles.tab.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                            const SizedBox(height: AppSpacing.tabIndicatorGap),
                            AnimatedOpacity(
                              duration: _animationDuration,
                              opacity: isActive ? 1 : 0,
                              child: Container(
                                width: AppSizes.tabIndicatorWidth,
                                height: AppSizes.tabIndicatorHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.tabIndicatorRadius,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  int _indexOf(LiveState state) {
    return state is LiveReady ? state.selectedIndex : 2;
  }

  int _selectedPosition(int selectedIndex) {
    final position = _tabs.indexWhere((tab) => tab.index == selectedIndex);
    return position == -1 ? 0 : position;
  }
}
