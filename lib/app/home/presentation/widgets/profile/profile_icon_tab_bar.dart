import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfileIconTabBar extends StatelessWidget {
  const ProfileIconTabBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.backgroundColor,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // TikTok order: Posts · Private · Reposts · Saved · Liked
    final tabs = <(int index, IconData icon)>[
      (ProfileLayoutConstants.postsTabIndex, LucideIcons.layoutGrid),
      (ProfileLayoutConstants.onlyMeTabIndex, LucideIcons.lock),
      (ProfileLayoutConstants.repostsTabIndex, LucideIcons.repeat2),
      (ProfileLayoutConstants.savedTabIndex, LucideIcons.bookmark),
      (ProfileLayoutConstants.likedTabIndex, LucideIcons.heart),
    ];

    return ColoredBox(
      color: backgroundColor,
      child: Column(
        children: [
          SizedBox(
            height: ProfileLayoutConstants.iconTabBarHeight,
            child: Row(
              children: [
                for (final tab in tabs)
                  _ProfileIconTab(
                    isSelected: selectedIndex == tab.$1,
                    icon: tab.$2,
                    theme: theme,
                    onTap: () => onSelected(tab.$1),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

/// Posts-only tab strip for another user's profile (flush with grid below).
class ProfileUserPostsTabBar extends StatelessWidget {
  const ProfileUserPostsTabBar({
    required this.backgroundColor,
    super.key,
  });

  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: ProfileLayoutConstants.iconTabBarHeight,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.layoutGrid,
                    size: ProfileLayoutConstants.iconTabSize,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(height: AppSizes.p6),
                  Container(
                    height: ProfileLayoutConstants.iconTabIndicatorHeight,
                    width: ProfileLayoutConstants.iconTabIndicatorWidth,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

class _ProfileIconTab extends StatelessWidget {
  const _ProfileIconTab({
    required this.isSelected,
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  final bool isSelected;
  final IconData icon;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = theme.colorScheme.onSurface;
    final inactive = theme.colorScheme.onSurface.withValues(alpha: 0.35);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: ProfileLayoutConstants.iconTabSize,
              color: isSelected ? active : inactive,
            ),
            const SizedBox(height: AppSizes.p6),
            AnimatedContainer(
              duration: ProfileLayoutConstants.tabAnimationDuration,
              height: ProfileLayoutConstants.iconTabIndicatorHeight,
              width: isSelected
                  ? ProfileLayoutConstants.iconTabIndicatorWidth
                  : 0,
              decoration: BoxDecoration(
                color: active,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
