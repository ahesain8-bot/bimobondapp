import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class FeedOverlayControls extends StatelessWidget {
  const FeedOverlayControls({
    required this.onLiveTap,
    required this.onSearchTap,
    super.key,
  });

  final VoidCallback onLiveTap;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feedOverlay = FeedOverlayTheme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return SafeArea(
      child: Align(
        alignment: isRtl ? Alignment.topRight : Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(
            HomeLayoutConstants.feedOverlayHorizontalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OverlayIconButton(
                icon: LucideIcons.search,
                tooltip: l10n.postsSearchTitle,
                feedOverlay: feedOverlay,
                onPressed: onSearchTap,
              ),
              _OverlayIconButton(
                icon: Icons.live_tv_rounded,
                tooltip: l10n.feedLive,
                feedOverlay: feedOverlay,
                onPressed: onLiveTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.feedOverlay,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final FeedOverlayTheme feedOverlay;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        color: feedOverlay.overlayForeground,
        size: HomeLayoutConstants.liveIconSize,
        shadows: [Shadow(blurRadius: AppSizes.p4, color: feedOverlay.shadow)],
      ),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
