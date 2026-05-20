import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class FeedOverlayControls extends StatelessWidget {
  const FeedOverlayControls({
    required this.onLiveTap,
    super.key,
  });

  final VoidCallback onLiveTap;

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
          child: IconButton(
            icon: Icon(
              Icons.live_tv_rounded,
              color: feedOverlay.overlayForeground,
              size: HomeLayoutConstants.liveIconSize,
              shadows: [
                Shadow(
                  blurRadius: AppSizes.p4,
                  color: feedOverlay.shadow,
                ),
              ],
            ),
            tooltip: l10n.feedLive,
            onPressed: onLiveTap,
          ),
        ),
      ),
    );
  }
}
