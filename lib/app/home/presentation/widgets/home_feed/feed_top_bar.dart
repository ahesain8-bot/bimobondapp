import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_top_tabs.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_tab.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FeedTopBar extends StatelessWidget {
  const FeedTopBar({
    required this.selectedTab,
    required this.onTabChanged,
    required this.onLiveTap,
    required this.onSearchTap,
    super.key,
  });

  final HomeFeedTab selectedTab;
  final ValueChanged<HomeFeedTab> onTabChanged;
  final VoidCallback onLiveTap;
  final VoidCallback onSearchTap;

  static const double _sideSlotWidth = 44;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feedOverlay = FeedOverlayTheme.of(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HomeLayoutConstants.feedOverlayHorizontalPadding,
        ),
        child: SizedBox(
          height: HomeLayoutConstants.feedTopBarHeight,
          child: Row(
            children: [
              SizedBox(
                width: _sideSlotWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _FeedTopImageButton(
                    assetPath: AppAssets.feedLiveIcon,
                    tooltip: l10n.feedLive,
                    feedOverlay: feedOverlay,
                    onPressed: onLiveTap,
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
                width: _sideSlotWidth,
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
    final isSvg = assetPath.toLowerCase().endsWith('.svg');
    final color = feedOverlay.overlayForeground;
    final size = HomeLayoutConstants.liveIconSize;

    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 36,
        minHeight: 36,
      ),
      onPressed: onPressed,
      icon: isSvg
          ? SvgPicture.asset(
              assetPath,
              width: size,
              height: size,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            )
          : Image.asset(
              assetPath,
              width: size,
              height: size,
              color: color,
              colorBlendMode: BlendMode.srcIn,
            ),
    );
  }
}
