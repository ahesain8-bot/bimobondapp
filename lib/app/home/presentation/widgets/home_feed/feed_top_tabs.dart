import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_tab.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class FeedTopTabs extends StatelessWidget {
  const FeedTopTabs({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  final HomeFeedTab selectedTab;
  final ValueChanged<HomeFeedTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feedOverlay = FeedOverlayTheme.of(context);
    final widthScale = HomeLayoutConstants.widthScale(context, minScale: 0.85, maxScale: 1.15);
    final dividerMargin = (8.0 * widthScale).clamp(4.0, 10.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FeedTopTabLabel(
          label: l10n.feedFollowingTab,
          isSelected: selectedTab == HomeFeedTab.following,
          feedOverlay: feedOverlay,
          onTap: () => onTabChanged(HomeFeedTab.following),
        ),
        Container(
          width: HomeLayoutConstants.tabPillDividerWidth,
          height: HomeLayoutConstants.tabPillDividerHeight,
          margin: EdgeInsets.symmetric(horizontal: dividerMargin),
          color: feedOverlay.overlayForeground.withValues(alpha: 0.35),
        ),
        _FeedTopTabLabel(
          label: l10n.feedForYou,
          isSelected: selectedTab == HomeFeedTab.forYou,
          feedOverlay: feedOverlay,
          onTap: () => onTabChanged(HomeFeedTab.forYou),
        ),
      ],
    );
  }
}

class _FeedTopTabLabel extends StatelessWidget {
  const _FeedTopTabLabel({
    required this.label,
    required this.isSelected,
    required this.feedOverlay,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final FeedOverlayTheme feedOverlay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final widthScale = HomeLayoutConstants.widthScale(context, minScale: 0.85, maxScale: 1.15);
    final selectedFontSize = (HomeLayoutConstants.tabSelectedFontSize * widthScale).clamp(14.0, 18.0);
    final unselectedFontSize = (HomeLayoutConstants.tabUnselectedFontSize * widthScale).clamp(13.0, 17.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? feedOverlay.overlayForeground
                : feedOverlay.overlayForeground.withValues(alpha: 0.55),
            fontSize: isSelected ? selectedFontSize : unselectedFontSize,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            height: 1.2,
            shadows: [
              Shadow(
                blurRadius: 6,
                color: feedOverlay.shadow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
