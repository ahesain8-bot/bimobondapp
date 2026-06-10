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
    final colorScheme = theme.colorScheme;

    return ColoredBox(
      color: backgroundColor,
      child: Column(
        children: [
          SizedBox(
            height: ProfileLayoutConstants.iconTabBarHeight,
            child: Row(
              children: [
                _ProfileIconTab(
                  isSelected: selectedIndex == 0,
                  icon: LucideIcons.layoutGrid,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => onSelected(0),
                ),
                _ProfileIconTab(
                  isSelected: selectedIndex == ProfileLayoutConstants.repostsTabIndex,
                  icon: LucideIcons.repeat2,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => onSelected(ProfileLayoutConstants.repostsTabIndex),
                ),
                _ProfileIconTab(
                  isSelected: selectedIndex == ProfileLayoutConstants.onlyMeTabIndex,
                  icon: LucideIcons.lock,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => onSelected(ProfileLayoutConstants.onlyMeTabIndex),
                ),
                _ProfileIconTab(
                  isSelected: selectedIndex == ProfileLayoutConstants.likedTabIndex,
                  icon: LucideIcons.heart,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => onSelected(ProfileLayoutConstants.likedTabIndex),
                ),
                _ProfileIconTab(
                  isSelected: selectedIndex == ProfileLayoutConstants.savedTabIndex,
                  icon: LucideIcons.bookmark,
                  colorScheme: colorScheme,
                  theme: theme,
                  onTap: () => onSelected(ProfileLayoutConstants.savedTabIndex),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.15),
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
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  final bool isSelected;
  final IconData icon;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: ProfileLayoutConstants.iconTabSize,
              color: isSelected
                  ? colorScheme.primary
                  : theme.iconTheme.color?.withValues(alpha: 0.45),
            ),
            const SizedBox(height: AppSizes.p6),
            AnimatedContainer(
              duration: ProfileLayoutConstants.tabAnimationDuration,
              height: ProfileLayoutConstants.iconTabIndicatorHeight,
              width: isSelected
                  ? ProfileLayoutConstants.iconTabIndicatorWidth
                  : 0,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
