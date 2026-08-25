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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feedOverlay = FeedOverlayTheme.of(context);
    final widthScale = HomeLayoutConstants.widthScale(context, minScale: 0.85, maxScale: 1.15);
    final horizontalPadding = (12.0 * widthScale).clamp(8.0, 16.0);
    final iconGap = (6.0 * widthScale).clamp(4.0, 10.0);

    final showShop = onShopTap != null;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: SizedBox(
          height: HomeLayoutConstants.feedTopBarHeight,
          child: Row(
            children: [
              // Left Group: Live + optional Store icon with responsive spacing
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FeedTopImageButton(
                    assetPath: AppAssets.feedLiveIcon,
                    tooltip: l10n.feedLive,
                    feedOverlay: feedOverlay,
                    onPressed: onLiveTap,
                  ),
                  if (showShop) ...[
                    SizedBox(width: iconGap),
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

              // Center: Responsive Tab Bar (Following | For You)
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: FeedTopTabs(
                      selectedTab: selectedTab,
                      onTabChanged: onTabChanged,
                    ),
                  ),
                ),
              ),

              // Right Group: Search button + balancing spacer if shop is shown
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FeedTopImageButton(
                    assetPath: AppAssets.feedSearchIcon,
                    tooltip: l10n.postsSearchTitle,
                    feedOverlay: feedOverlay,
                    onPressed: onSearchTap,
                  ),
                  // If shop is visible on the left (2 icons), add a tiny balancing offset on the right
                  if (showShop) SizedBox(width: 38 + iconGap),
                ],
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
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: SvgPicture.asset(
          assetPath,
          width: 22,
          height: 22,
          colorFilter: ColorFilter.mode(
            feedOverlay.overlayForeground,
            BlendMode.srcIn,
          ),
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
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Badge(
          isLabelVisible: badgeCount > 0,
          label: Text(
            badgeCount > 99 ? '99+' : '$badgeCount',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
          child: Icon(icon, size: 22, color: feedOverlay.overlayForeground),
        ),
      ),
    );
  }
}
