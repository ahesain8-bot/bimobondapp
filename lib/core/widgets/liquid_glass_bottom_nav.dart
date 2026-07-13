import 'dart:ui';

import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One tab in [LiquidGlassBottomNav].
class LiquidGlassBottomNavItem {
  const LiquidGlassBottomNavItem({
    this.icon,
    this.selectedIcon,
    this.assetPath,
    this.selectedAssetPath,
    required this.label,
    required this.index,
  }) : assert(icon != null || assetPath != null);

  final IconData? icon;
  final IconData? selectedIcon;
  final String? assetPath;
  final String? selectedAssetPath;
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
        assetPath: AppAssets.homeIcon,
        selectedAssetPath: AppAssets.homeIconFilled,
        label: homeLabel,
        index: 0,
      ),
      LiquidGlassBottomNavItem(
        assetPath: AppAssets.auctionNavIcon,
        selectedAssetPath: AppAssets.auctionNavIconFilled,
        label: auctionsLabel,
        index: 1,
      ),
      LiquidGlassBottomNavItem(
        assetPath: AppAssets.chatNavIcon,
        selectedAssetPath: AppAssets.chatNavIconFilled,
        label: chatLabel,
        index: 3,
      ),
      LiquidGlassBottomNavItem(
        assetPath: AppAssets.profileIcon,
        selectedAssetPath: AppAssets.profileIconFilled,
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
        assetPath: AppAssets.homeIcon,
        selectedAssetPath: AppAssets.homeIconFilled,
        label: homeLabel,
        index: 0,
      ),
      LiquidGlassBottomNavItem(
        assetPath: AppAssets.profileIcon,
        selectedAssetPath: AppAssets.profileIconFilled,
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
            Icons.add,
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
          selectedIcon: item.selectedIcon,
          assetPath: item.assetPath,
          selectedAssetPath: item.selectedAssetPath,
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
    this.icon,
    this.selectedIcon,
    this.assetPath,
    this.selectedAssetPath,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final IconData? icon;
  final IconData? selectedIcon;
  final String? assetPath;
  final String? selectedAssetPath;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected ? selectedColor : unselectedColor;

    final size = HomeLayoutConstants.navIconSize;
    final resolvedAsset = isSelected
        ? (selectedAssetPath ?? assetPath)
        : assetPath;
    final resolvedIcon = isSelected ? (selectedIcon ?? icon) : icon;

    final Widget iconWidget;
    if (resolvedAsset != null) {
      final isSvg = resolvedAsset.toLowerCase().endsWith('.svg');
      iconWidget = isSvg
          ? SvgPicture.asset(
              resolvedAsset,
              width: size,
              height: size,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            )
          : Image.asset(
              resolvedAsset,
              width: size,
              height: size,
              color: color,
              colorBlendMode: BlendMode.srcIn,
            );
    } else {
      iconWidget = Icon(resolvedIcon!, color: color, size: size);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
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
