import 'package:bimobondapp/app/home/presentation/pages/home_feed_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_bottom_nav.dart';
import 'package:flutter/material.dart';

/// Black bottom bar: [search → progress] then tab nav (home feed).
class HomeFeedBottomNavBar extends StatelessWidget {
  const HomeFeedBottomNavBar({
    required this.feedKey,
    required this.currentIndex,
    required this.onItemTap,
    required this.items,
    required this.glassStyle,
    this.center,
    super.key,
  });

  final GlobalKey<HomeFeedScreenState> feedKey;
  final int currentIndex;
  final ValueChanged<int> onItemTap;
  final List<LiquidGlassBottomNavItem> items;
  final bool glassStyle;
  final Widget? center;

  static const int homeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final nav = LiquidGlassBottomNav(
      currentIndex: currentIndex,
      glassStyle: glassStyle,
      onItemTap: onItemTap,
      items: items,
      center: center,
    );

    if (currentIndex != homeTabIndex) {
      return nav;
    }

    final listenable = feedKey.currentState?.bottomChromeListenable;
    if (listenable == null) {
      return ColoredBox(color: Colors.black, child: nav);
    }

    return ColoredBox(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: listenable,
            builder: (context, _) {
              final feed = feedKey.currentState;
              final chrome = feed?.buildBottomSearchProgressColumn();
              if (chrome == null) return const SizedBox.shrink();
              return FeedVideoProgressScope(
                notifier: feed!.feedVideoProgress,
                child: chrome,
              );
            },
          ),
          nav,
        ],
      ),
    );
  }
}
