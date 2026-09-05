import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';

/// TikTok bottom tabs: POST · TEMPLATES · LIVE.
class BottomTabs extends StatelessWidget {
  const BottomTabs({super.key});

  static const List<({String label, int index})> _tabs = [
    (label: 'POST', index: 0),
    (label: 'TEMPLATES', index: 1),
    (label: 'LIVE', index: 2),
  ];

  @override
  Widget build(BuildContext context) {
    final liveBloc = context.read<LiveBloc>();

    return BlocBuilder<LiveBloc, LiveState>(
      buildWhen: (previous, current) => _indexOf(previous) != _indexOf(current),
      builder: (context, state) {
        final selectedIndex = _indexOf(state);

        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final tab in _tabs)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => liveBloc.add(LiveTabChanged(tab.index)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tab.label,
                            style: TextStyle(
                              color: selectedIndex == tab.index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                              fontSize: 13,
                              fontWeight: selectedIndex == tab.index
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 5),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: selectedIndex == tab.index ? 1 : 0,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.white,
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
        );
      },
    );
  }

  int _indexOf(LiveState state) {
    return state is LiveReady ? state.selectedIndex : 2;
  }
}
