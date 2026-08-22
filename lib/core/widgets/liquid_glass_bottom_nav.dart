import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
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

  static Widget addButton({
    required BuildContext context,
    required VoidCallback onTap,
  }) {
    const double edge = 3.5;
    const radius = BorderRadius.all(
      Radius.circular(HomeLayoutConstants.addButtonRadius),
    );
    final cs = Theme.of(context).colorScheme;
    final primaryColor = cs.primary;
    final secondaryColor = cs.secondary;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: HomeLayoutConstants.navItemBottomPadding,
        ),
        child: SizedBox(
          width: HomeLayoutConstants.addButtonWidth,
          height: HomeLayoutConstants.addButtonHeight,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: HomeLayoutConstants.addButtonWidth - edge,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: radius,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: HomeLayoutConstants.addButtonWidth - edge,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    borderRadius: radius,
                  ),
                ),
              ),
              Positioned(
                left: edge,
                right: edge,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.35),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: HomeLayoutConstants.addButtonIconSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feedOverlay = FeedOverlayTheme.of(context);
    // TikTok marks the active tab by weight and full-strength foreground, not
    // by a brand colour, so the row reads as one family and the centre button
    // stays the only coloured thing down here.
    final selectedColor = glassStyle
        ? feedOverlay.overlayForeground
        : theme.colorScheme.onSurface;
    final unselectedColor = glassStyle
        ? feedOverlay.overlayForegroundMuted
        : theme.colorScheme.onSurface.withValues(alpha: 0.45);

    final heightScale = HomeLayoutConstants.heightScale(context, minScale: 0.85, maxScale: 1.15);
    final topPadding = (HomeLayoutConstants.bottomNavTopPadding * heightScale).clamp(4.0, 12.0);
    final safeExtra = (HomeLayoutConstants.bottomNavSafeExtra * heightScale).clamp(4.0, 12.0);

    Widget navBar = Container(
      decoration: BoxDecoration(
        color: glassStyle ? Colors.black : theme.scaffoldBackgroundColor,
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
            MediaQuery.viewPaddingOf(context).bottom +
            safeExtra,
        top: topPadding,
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

    final heightScale = HomeLayoutConstants.heightScale(context, minScale: 0.85, maxScale: 1.15);
    final size = (HomeLayoutConstants.navIconSize * heightScale).clamp(22.0, 32.0);
    final fontSize = (HomeLayoutConstants.navLabelFontSize * heightScale).clamp(8.0, 11.0);
    final iconLabelGap = (HomeLayoutConstants.navIconLabelGap * heightScale).clamp(1.0, 4.0);

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
          SizedBox(height: iconLabelGap),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
