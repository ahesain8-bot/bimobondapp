import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_top_tabs.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_tab.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FeedTopBar extends StatelessWidget {
  const FeedTopBar({
    required this.selectedTab,
    required this.onTabChanged,
    required this.onLiveTap,
    required this.onSearchTap,
    this.onShopTap,
    this.shopCartBadge = 0,
    super.key,
  });

  final HomeFeedTab selectedTab;
  final ValueChanged<HomeFeedTab> onTabChanged;
  final VoidCallback onLiveTap;
  /// When null (guest), the shop bag is hidden. Shown after login.
  final VoidCallback? onShopTap;
  final VoidCallback onSearchTap;
  final int shopCartBadge;

  // Live + optional shop bag icons (≈40 + 4 + 40) need more than the old 88px slot.
  static const double _sideSlotWidth = 100;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feedOverlay = FeedOverlayTheme.of(context);
    final widthScale = HomeLayoutConstants.widthScale(context, minScale: 0.85, maxScale: 1.15);
    final sideSlotWidth = (_sideSlotWidth * widthScale).clamp(84.0, 110.0);
    final horizontalPadding = (HomeLayoutConstants.feedOverlayHorizontalPadding * widthScale).clamp(6.0, 16.0);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
        ),
        child: SizedBox(
          height: HomeLayoutConstants.feedTopBarHeight,
          child: Row(
            children: [
              SizedBox(
                width: sideSlotWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FeedTopImageButton(
                        assetPath: AppAssets.feedLiveIcon,
                        tooltip: l10n.feedLive,
                        feedOverlay: feedOverlay,
                        onPressed: onLiveTap,
                      ),
                      if (onShopTap != null) ...[
                        const SizedBox(width: 4),
                        _FeedTopIconButton(
                          icon: LucideIcons.shoppingBag,
                          tooltip: l10n.feedShop,
                          feedOverlay: feedOverlay,
                          onPressed: onShopTap!,
                          badgeCount: shopCartBadge,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: FeedTopTabs(
                    selectedTab: selectedTab,
                    onTabChanged: onTabChanged,
                  ),
                ),
              ),
              SizedBox(
                width: sideSlotWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _FeedTopImageButton(
                    assetPath: AppAssets.feedSearchIcon,
                    tooltip: l10n.postsSearchTitle,
                    feedOverlay: feedOverlay,
                    onPressed: onSearchTap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedTopImageButton extends StatelessWidget {
  const _FeedTopImageButton({
    required this.assetPath,
    required this.tooltip,
    required this.feedOverlay,
    required this.onPressed,
  });

  final String assetPath;
  final String tooltip;
  final FeedOverlayTheme feedOverlay;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: SvgPicture.asset(
        assetPath,
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(
          feedOverlay.overlayForeground,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _FeedTopIconButton extends StatelessWidget {
  const _FeedTopIconButton({
    required this.icon,
    required this.tooltip,
    required this.feedOverlay,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final FeedOverlayTheme feedOverlay;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Badge(
        isLabelVisible: badgeCount > 0,
        label: Text(
          badgeCount > 99 ? '99+' : '$badgeCount',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
        child: Icon(icon, size: 22, color: feedOverlay.overlayForeground),
      ),
    );
  }
}
