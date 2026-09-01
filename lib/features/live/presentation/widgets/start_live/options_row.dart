import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';

/// TikTok mode selector: Device camera (green dot) / Mobile gaming.
class OptionsRow extends StatelessWidget {
  const OptionsRow({super.key});

  static const List<({String label, IconData icon, bool isDeviceCamera})>
  _options = [
    (
      label: 'Device camera',
      icon: Icons.videocam_outlined,
      isDeviceCamera: true,
    ),
    (
      label: 'Mobile gaming',
      icon: Icons.smartphone_outlined,
      isDeviceCamera: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final liveBloc = context.read<LiveBloc>();

    return BlocBuilder<LiveBloc, LiveState>(
      buildWhen: (previous, current) =>
          _deviceOf(previous) != _deviceOf(current),
      builder: (context, state) {
        final isDeviceCamera = _deviceOf(state);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final option in _options) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => liveBloc.add(
                      LiveSourceChanged(option.isDeviceCamera),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                option.icon,
                                size: 18,
                                color: option.isDeviceCamera == isDeviceCamera
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                option.label,
                                style: TextStyle(
                                  color: option.isDeviceCamera == isDeviceCamera
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                  fontWeight:
                                      option.isDeviceCamera == isDeviceCamera
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: option.isDeviceCamera == isDeviceCamera
                                ? 1
                                : 0,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF20D5EC),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  bool _deviceOf(LiveState state) {
    return state is LiveReady ? state.isDeviceCamera : true;
  }
}
