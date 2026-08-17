import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';

/// Broadcast source selector: device camera / mobile games.
class OptionsRow extends StatelessWidget {
  const OptionsRow({super.key});

  static const List<({String label, IconData icon, bool isDeviceCamera})>
  _options = [
    (
      label: 'ألعاب الهاتف المحمول',
      icon: Icons.smartphone_outlined,
      isDeviceCamera: false,
    ),
    (
      label: 'الكاميرا الخاصة بالجهاز',
      icon: Icons.videocam_outlined,
      isDeviceCamera: true,
    ),
  ];
  static const double _optionWidth = 148;
  static const double _optionGap = AppSpacing.xxs;
  static const double _optionHeight = 28;
  static const Duration _animationDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final liveBloc = context.read<LiveBloc>();

    return BlocBuilder<LiveBloc, LiveState>(
      buildWhen: (previous, current) =>
          _deviceOf(previous) != _deviceOf(current),
      builder: (context, state) {
        final isDeviceCamera = _deviceOf(state);

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.optionsHorizontal,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final selectedPosition = _selectedPosition(isDeviceCamera);
              final centerLeft = (constraints.maxWidth - _optionWidth) / 2;
              final step = _optionWidth + _optionGap;

              return SizedBox(
                height: _optionHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: _options.asMap().entries.map((entry) {
                    final option = entry.value;
                    final isActive = option.isDeviceCamera == isDeviceCamera;
                    final position = entry.key - selectedPosition;

                    return AnimatedPositioned(
                      key: ValueKey(option.isDeviceCamera),
                      duration: _animationDuration,
                      curve: Curves.easeInOutCubic,
                      left: centerLeft + (position * step),
                      top: 0,
                      width: _optionWidth,
                      height: _optionHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => liveBloc.add(
                          LiveSourceChanged(option.isDeviceCamera),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  option.label,
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Icon(
                                  option.icon,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
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

  bool _deviceOf(LiveState state) {
    return state is LiveReady ? state.isDeviceCamera : true;
  }

  int _selectedPosition(bool isDeviceCamera) {
    final position = _options.indexWhere(
      (option) => option.isDeviceCamera == isDeviceCamera,
    );
    return position == -1 ? 0 : position;
  }
}
