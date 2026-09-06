import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';

/// Go LIVE mode selector: Video vs Voice Chat, then device camera / gaming.
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
          _deviceOf(previous) != _deviceOf(current) ||
          _audioOf(previous) != _audioOf(current),
      builder: (context, state) {
        final isDeviceCamera = _deviceOf(state);
        final isAudio = _audioOf(state);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ModeChip(
                      label: 'Video',
                      icon: Icons.videocam_outlined,
                      selected: !isAudio,
                      onTap: () => liveBloc.add(
                        const LiveMediaModeChanged(false),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _ModeChip(
                      label: 'Voice Chat',
                      icon: Icons.graphic_eq,
                      selected: isAudio,
                      onTap: () => liveBloc.add(
                        const LiveMediaModeChanged(true),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAudio)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final option in _options)
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
                                      color: option.isDeviceCamera ==
                                              isDeviceCamera
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.45),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      option.label,
                                      style: TextStyle(
                                        color: option.isDeviceCamera ==
                                                isDeviceCamera
                                            ? Colors.white
                                            : Colors.white.withValues(
                                                alpha: 0.45,
                                              ),
                                        fontSize: 13,
                                        fontWeight: option.isDeviceCamera ==
                                                isDeviceCamera
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
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _deviceOf(LiveState state) {
    return state is LiveReady ? state.isDeviceCamera : true;
  }

  bool _audioOf(LiveState state) {
    return state is LiveReady ? state.isAudioMode : false;
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0,
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
    );
  }
}
