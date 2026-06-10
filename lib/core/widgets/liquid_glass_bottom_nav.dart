import 'dart:ui';

import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// One tab in [LiquidGlassBottomNav].
class LiquidGlassBottomNavItem {
  const LiquidGlassBottomNavItem({
    required this.icon,
    required this.label,
    required this.index,
  });

  final IconData icon;
  final String label;
  final int index;
}

/// Standard tab sets for [MainScreen].
abstract final class LiquidGlassBottomNavItems {
  static List<LiquidGlassBottomNavItem> loggedIn({
    required String homeLabel,
    required String auctionsLabel,
    required String chatLabel,
    required String profileLabel,
  }) {
    return [
      LiquidGlassBottomNavItem(
        icon: LucideIcons.house,
        label: homeLabel,
        index: 0,
      ),
      LiquidGlassBottomNavItem(
        icon: LucideIcons.gavel,
        label: auctionsLabel,
        index: 1,
      ),
      LiquidGlassBottomNavItem(
        icon: LucideIcons.messageSquare,
        label: chatLabel,
        index: 3,
      ),
      LiquidGlassBottomNavItem(
        icon: LucideIcons.user,
        label: profileLabel,
        index: 4,
      ),
    ];
  }

  static List<LiquidGlassBottomNavItem> guest({
    required String homeLabel,
    required String profileLabel,
  }) {
    return [
      LiquidGlassBottomNavItem(
        icon: LucideIcons.house,
        label: homeLabel,
        index: 0,
      ),
      LiquidGlassBottomNavItem(
        icon: LucideIcons.user,
        label: profileLabel,
        index: 1,
      ),
    ];
  }

  /// Center add-post slot index in the logged-in nav row.
  static const int loggedInAddButtonIndex = 2;
}

/// App-wide bottom navigation with optional liquid-glass scrim on immersive tabs.
class LiquidGlassBottomNav extends StatelessWidget {
  const LiquidGlassBottomNav({
    required this.currentIndex,
    required this.onItemTap,
    required this.items,
    this.glassStyle = false,
    this.center,
    this.centerInsertAfter = 2,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onItemTap;
  final List<LiquidGlassBottomNavItem> items;
  final bool glassStyle;
  final Widget? center;
  final int centerInsertAfter;

  /// Gradient add button used in the logged-in nav center slot.
  static Widget addButton({
    required BuildContext context,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: HomeLayoutConstants.navItemBottomPadding,
        ),
        child: Container(
          width: HomeLayoutConstants.addButtonWidth,
          height: HomeLayoutConstants.addButtonHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(
              HomeLayoutConstants.addButtonRadius,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: HomeLayoutConstants.addButtonShadowBlur,
                offset: const Offset(
                  0,
                  HomeLayoutConstants.addButtonShadowOffsetY,
                ),
              ),
            ],
          ),
          child: Icon(
            LucideIcons.plus,
            color: theme.colorScheme.onPrimary,
            size: HomeLayoutConstants.addButtonIconSize,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedOverlay = FeedOverlayTheme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final unselectedColor = glassStyle
        ? feedOverlay.overlayForegroundMuted
        : theme.colorScheme.onSurface.withValues(alpha: 0.45);

    Widget navBar = Container(
      decoration: BoxDecoration(
        color: glassStyle
            ? feedOverlay.navBarScrim
            : theme.scaffoldBackgroundColor,
        border: glassStyle
            ? null
            : Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
      ),
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom +
            HomeLayoutConstants.bottomNavSafeExtra,
        top: HomeLayoutConstants.bottomNavTopPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _buildRowChildren(
          context,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
        ),
      ),
    );

    if (glassStyle) {
      navBar = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: HomeLayoutConstants.navBlurSigma,
            sigmaY: HomeLayoutConstants.navBlurSigma,
          ),
          child: navBar,
        ),
      );
    }

    return navBar;
  }

  List<Widget> _buildRowChildren(
    BuildContext context, {
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    final children = <Widget>[];
    final insertCenterAt = center == null ? -1 : centerInsertAfter;

    for (var i = 0; i < items.length; i++) {
      if (i == insertCenterAt) {
        children.add(center!);
      }

      final item = items[i];
      children.add(
        _LiquidGlassBottomNavTile(
          icon: item.icon,
          label: item.label,
          isSelected: currentIndex == item.index,
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
          onTap: () => onItemTap(item.index),
        ),
      );
    }

    if (insertCenterAt == items.length) {
      children.add(center!);
    }

    return children;
  }
}

class _LiquidGlassBottomNavTile extends StatelessWidget {
  const _LiquidGlassBottomNavTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected ? selectedColor : unselectedColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: HomeLayoutConstants.navIconSize),
          const SizedBox(height: AppSizes.p4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: HomeLayoutConstants.navLabelFontSize,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
